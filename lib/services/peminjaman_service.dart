import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/peminjaman.dart';
import 'auth_service.dart';

/// Same detection approach as auth_service.dart's _isNetworkError — see
/// that file's comment for why this checks by type + message text rather
/// than importing package:http directly.
bool _isNetworkError(Object e) {
  if (e is SocketException) return true;
  final text = e.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection failed');
}

/// Turns a raw Supabase/Postgrest error into something a SnackBar can show
/// a Pegawai without them needing to read Postgres error codes.
String _friendlyError(Object e) {
  if (_isNetworkError(e)) {
    return 'Tidak ada koneksi internet. Data terakhir yang tersimpan '
        'masih bisa dilihat, tapi aksi ini butuh koneksi.';
  }
  if (e is PostgrestException) {
    if (e.code == '42501') {
      // Raised by our RLS/trigger checks (see supabase_rls_admin_controls.sql)
      return e.message;
    }
    if (e.code == 'PGRST301' || e.code == '401') {
      return 'Sesi berakhir, silakan login kembali.';
    }
    return e.message;
  }
  return e.toString();
}

/// ─── ARCHITECTURE NOTE ──────────────────────────────────────────────
/// Your existing screens call PeminjamanService.getAll(),
/// getSedangDipinjam(), etc. synchronously, directly inside build().
/// Rewriting every screen to use FutureBuilder/StreamBuilder would be a
/// large, risky change this late in the project.
///
/// Instead, this service keeps an in-memory `_cache` (same as before)
/// that mirrors Supabase. Read methods (getAll, getSedangDipinjam, ...)
/// stay 100% synchronous and unchanged from the caller's point of view.
/// Write methods (tambah, kembalikan, ajukanPerpanjangan, ...) are now
/// `Future`-returning: they write to Supabase first, then update the
/// cache once Supabase confirms the write. Calling code just needs to
/// add `await` in front of these calls (see checklist in chat).
class PeminjamanService {
  PeminjamanService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static final List<Peminjaman> _cache = [];

  /// True if the current [_cache] contents came from local disk (last
  /// known state) rather than a confirmed-fresh fetch from Supabase.
  /// Screens can check this to show a small "data terakhir tersimpan"
  /// hint alongside the existing error banner if useful.
  static bool isStaleCache = false;

  static const _diskCacheKey = 'peminjaman_cache';

  static List<Peminjaman> getAll() => List.unmodifiable(_cache);

  static Future<void> _persistCacheToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(
      _cache.map((p) => {...p.toMap(), 'id': p.id}).toList(),
    );
    await prefs.setString(_diskCacheKey, raw);
  }

  static Future<bool> _loadCacheFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_diskCacheKey);
    if (raw == null) return false;
    try {
      final list = jsonDecode(raw) as List;
      _cache
        ..clear()
        ..addAll(
          list.map((m) => Peminjaman.fromMap(m as Map<String, dynamic>)),
        );
      return _cache.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Call once after login (see main.dart / AuthService.tryRestoreSession)
  /// and whenever you want to force a full re-sync (e.g. pull-to-refresh)
  /// to pull the latest data from Supabase into the cache.
  static Future<void> refresh() async {
    try {
      final rows = await _client
          .from('peminjaman')
          .select()
          .order('created_at', ascending: false);
      _cache
        ..clear()
        ..addAll(rows.map((row) => Peminjaman.fromMap(row)));
      isStaleCache = false;
      await _persistCacheToDisk();
    } catch (e) {
      // Offline with nothing in memory yet (e.g. app just launched) —
      // fall back to whatever was last saved to disk so the UI has
      // something to show under the error banner instead of a blank list.
      if (_cache.isEmpty) {
        isStaleCache = await _loadCacheFromDisk();
      }
      throw Exception(_friendlyError(e));
    }
  }

  // ─── ID-KEYED LOOKUP (11.08.2026 — re-applied on merge) ─────────────
  // This used to be _findActiveByNoHak(String noHak), matching on
  // p.noHak == noHak. That breaks for every Warkah loan: FormPage stores
  // noHak: '-' for all of them (Warkah's real identity field is no208,
  // tracked separately), so with two+ active Warkah loans a noHak-keyed
  // lookup can't tell them apart — e.g. kembalikan('-') would match every
  // active Warkah row at once instead of just the one actually being
  // returned. `id` is the table's real primary key and is unique
  // regardless of document type, so every write method below is keyed
  // by it instead.
  static Peminjaman? _findActiveById(String id) {
    for (final p in _cache) {
      if (p.id == id && p.status == 'Dipinjam') return p;
    }
    return null;
  }

  static void _replaceInCache(Peminjaman updated) {
    final index = _cache.indexWhere((p) => p.id == updated.id);
    if (index == -1) {
      _cache.insert(0, updated);
    } else {
      _cache[index] = updated;
    }
  }

  /// True if a document already has an active loan blocking a new
  /// request — either already approved ('Dipinjam') or still awaiting
  /// admin decision ('Diajukan'). A pending request has to block a
  /// duplicate submission too, or two people could submit overlapping
  /// requests for the same document before either gets decided.
  /// [jenisDokumen] picks which column actually identifies the
  /// document: no_hak for Buku Tanah/Surat Ukur, but no_208 for Warkah
  /// — Warkah loans always store '-' in no_hak (see form_page.dart),
  /// since a Warkah genuinely doesn't have that field. Checking no_hak
  /// for a Warkah's dedupe key would always compare against '-' and
  /// never actually catch a real duplicate.
  static Future<bool> existsActiveNoHak(
    String identifier, {
    String jenisDokumen = 'Buku Tanah',
  }) async {
    final column = jenisDokumen == 'Warkah' ? 'no_208' : 'no_hak';
    try {
      final rows = await _client
          .from('peminjaman')
          .select('id')
          .eq(column, identifier)
          .inFilter('status', ['Dipinjam', 'Diajukan'])
          .limit(1);
      return rows.isNotEmpty;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  /// Pegawai submissions go in as 'Diajukan' (pending admin review) —
  /// Admin submissions are auto-approved straight to 'Dipinjam', since an
  /// admin approving their own request would be pointless ceremony. This
  /// is fast-fail UX only: the actual boundary is
  /// trg_enforce_pending_status_for_pegawai in loan_approval_workflow.sql,
  /// which forces 'Diajukan' server-side for any non-admin insert
  /// regardless of what status the client sends — a modified client can't
  /// skip approval by just setting status: 'Dipinjam' directly.
  ///
  /// Returns the inserted row (with its real `id` from Supabase) instead
  /// of void — callers need it right away: FormPage checks the returned
  /// `status` to decide whether to jump straight to the barcode screen
  /// (admin, auto-approved) or show "menunggu persetujuan" (pegawai,
  /// pending) — and either way the barcode/detail screens need the real
  /// id, not a pre-insert placeholder.
  static Future<Peminjaman> tambah(Peminjaman peminjaman) async {
    final withOfficer = peminjaman.diampuOleh == null
        ? peminjaman.copyWith(diampuOleh: AuthService.currentUser?.id)
        : peminjaman;
    final withStatus = withOfficer.copyWith(
      status: AuthService.isAdmin ? 'Dipinjam' : 'Diajukan',
    );

    try {
      final inserted = await _client
          .from('peminjaman')
          .insert(withStatus.toMap())
          .select()
          .single();

      final result = Peminjaman.fromMap(inserted);
      _cache.insert(0, result);
      return result;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // APPROVAL PENGAJUAN PEMINJAMAN (11.08.2026) — admin decides a
  // pending ('Diajukan') request. Keyed by `id` (see _findActiveById's
  // comment above for why `no_hak`/`no_208` can't be used as a key).
  // Client-side isAdmin check is fast-fail UX only — the real gate is
  // trg_enforce_loan_approval_admin_only in loan_approval_workflow.sql.
  // ══════════════════════════════════════════════════════════════════

  static Peminjaman? _findPendingById(String id) {
    for (final p in _cache) {
      if (p.id == id && p.isPendingApproval) return p;
    }
    return null;
  }

  /// Approves a pending request, turning it into an active loan (status
  /// -> 'Dipinjam'). Gated behind the 3-item physical-document checklist
  /// — all three must be true, re-checked here rather than trusting
  /// whatever HomePage's UI already enforced, since a modified client
  /// could otherwise call this directly and skip the check entirely.
  /// Barcode generation happens client-side right after this returns
  /// true, not before — a 'Diajukan' row was never a confirmed loan, so
  /// it never had one yet.
  static Future<bool> setujuiPeminjaman(
    String id, {
    required bool checklistDokumenDitemukan,
    required bool checklistKondisiBaik,
    required bool checklistSesuaiData,
  }) async {
    if (!AuthService.isAdmin) return false;
    if (!checklistDokumenDitemukan ||
        !checklistKondisiBaik ||
        !checklistSesuaiData) {
      return false;
    }
    final current = _findPendingById(id);
    if (current == null) return false;

    try {
      final updated = await _client
          .from('peminjaman')
          .update({
            'status': 'Dipinjam',
            'disetujui_oleh': AuthService.currentUser?.id,
            'disetujui_oleh_nama': AuthService.currentUser?.nama,
            'checklist_dokumen_ditemukan': true,
            'checklist_kondisi_baik': true,
            'checklist_sesuai_data': true,
          })
          .eq('id', current.id!)
          .eq('status', 'Diajukan')
          .select()
          .maybeSingle();
      if (updated == null) return false;
      _replaceInCache(Peminjaman.fromMap(updated));
      return true;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  /// Rejects a pending request (status -> 'Ditolak'). `alasan` is
  /// required — whoever submitted the request needs to know why, not
  /// just that it was declined.
  ///
  /// Fixed on merge: the previous version of this method wrote the
  /// rejecting admin into `disetujui_oleh`/`disetujui_oleh_nama` (the
  /// *approval* attribution columns) and had no way to record a reason
  /// at all. Now uses the dedicated ditolak_oleh/ditolak_oleh_nama/
  /// alasan_penolakan columns instead, matching the Peminjaman model.
  static Future<bool> tolakPeminjaman(String id, String alasan) async {
    if (!AuthService.isAdmin) return false;
    final current = _findPendingById(id);
    if (current == null) return false;

    try {
      final updated = await _client
          .from('peminjaman')
          .update({
            'status': 'Ditolak',
            'ditolak_oleh': AuthService.currentUser?.id,
            'ditolak_oleh_nama': AuthService.currentUser?.nama,
            'alasan_penolakan': alasan,
          })
          .eq('id', current.id!)
          .eq('status', 'Diajukan')
          .select()
          .maybeSingle();
      if (updated == null) return false;
      _replaceInCache(Peminjaman.fromMap(updated));
      return true;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  /// Returns true if the loan was updated. Returns false if no matching
  /// row was found — including when RLS silently hides the row from an
  /// UPDATE (Postgres doesn't error in that case, it just matches 0
  /// rows), so callers can tell "worked" apart from "silently did
  /// nothing". Keyed by `id` (see _findActiveById's comment for why —
  /// this used to be noHak-keyed with a multi-row `.select()` as a
  /// duplicate-safety hedge; `id` is the actual unique primary key, so
  /// there's no longer a duplicate-match scenario to hedge against).
  static Future<bool> kembalikan(String id) async {
    try {
      final updated = await _client
          .from('peminjaman')
          .update({
            'status': 'Kembali',
            'kembali_oleh': AuthService.currentUser?.id,
            'kembali_oleh_nama': AuthService.currentUser?.nama,
          })
          .eq('id', id)
          .eq('status', 'Dipinjam')
          .select()
          .maybeSingle();
      if (updated == null) return false;
      _replaceInCache(Peminjaman.fromMap(updated));
      return true;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  /// Bulk version of [kembalikan] for the multi-select "Tandai Kembali"
  /// flow — returns the list of ids that actually got updated so the UI
  /// can report "X dari Y berhasil" instead of an all-or-nothing result.
  static Future<List<String>> kembalikanBanyak(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final rows = await _client
          .from('peminjaman')
          .update({
            'status': 'Kembali',
            'kembali_oleh': AuthService.currentUser?.id,
            'kembali_oleh_nama': AuthService.currentUser?.nama,
          })
          .inFilter('id', ids)
          .eq('status', 'Dipinjam')
          .select();
      final berhasil = <String>[];
      for (final row in rows) {
        final p = Peminjaman.fromMap(row);
        _replaceInCache(p);
        berhasil.add(p.id!);
      }
      return berhasil;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ─── PERPANJANG WAKTU PEMINJAMAN (langsung, tanpa approval) ───
  static Future<void> perpanjang(String id, DateTime tanggalKembaliBaru) async {
    try {
      final row = await _client
          .from('peminjaman')
          .update({'tanggal_kembali': tanggalKembaliBaru.toIso8601String()})
          .eq('id', id)
          .eq('status', 'Dipinjam')
          .select()
          .maybeSingle();
      if (row != null) _replaceInCache(Peminjaman.fromMap(row));
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static int getSedangDipinjam() =>
      _cache.where((p) => p.status == 'Dipinjam').length;

  static int getTelahKembali() =>
      _cache.where((p) => p.status == 'Kembali').length;

  static int getTerlambat() => _cache.where((p) => p.isOverdue).length;

  // ─── JENIS DOKUMEN BREAKDOWN (08.08.2026) ───
  // Backs the "Jenis Dokumen" breakdown container on Home/History/Return
  // (see widgets/jenis_dokumen_breakdown.dart — currently unused, see
  // that widget's callers for the "removed for now" note). Excludes
  // 'Ditolak' rows — a rejected request never actually became part of
  // the archive, so it shouldn't count toward "what's in the archive"
  // composition figures. 'Diajukan' (pending) rows ARE included, since
  // they represent real physical documents the moment they're approved;
  // excluding them would make the breakdown undercount right up until an
  // admin acts.
  static int getCountBukuTanah() => _cache
      .where((p) => p.jenisDokumen == 'Buku Tanah' && !p.isRejected)
      .length;

  static int getCountSuratUkur() => _cache
      .where((p) => p.jenisDokumen == 'Surat Ukur' && !p.isRejected)
      .length;

  static int getCountWarkah() =>
      _cache.where((p) => p.jenisDokumen == 'Warkah' && !p.isRejected).length;

  // ─── APPROVAL PENGAJUAN PEMINJAMAN (11.08.2026) ───
  static List<Peminjaman> getPengajuanPeminjaman() =>
      _cache.where((p) => p.isPendingApproval).toList();

  static int getMenungguPersetujuan() => getPengajuanPeminjaman().length;

  // ══════════════════════════════════════════════════════════════════
  // EXTENSION STATE MACHINE — same states/transitions as before, now
  // keyed by `id` instead of `no_hak` (see _findActiveById's comment).
  // ══════════════════════════════════════════════════════════════════

  static Future<bool> ajukanPerpanjangan(
    String id,
    DateTime tanggalKembaliBaru,
    String alasan,
  ) async {
    final current = _findActiveById(id);
    if (current == null || current.isExtensionPending) return false;

    // Ownership gate: only the pegawai who originally borrowed this
    // document (diampuOleh) may request an extension for it. Without
    // this check, any logged-in pegawai could open any other pegawai's
    // active loan from ReturnPage and submit an extension request on
    // their behalf — return_page.dart now also hides/disables the
    // button client-side, but that's UX only; this is the real gate.
    // NOTE: this is still just an application-level check. The
    // authoritative enforcement belongs in a Supabase RLS policy /
    // trigger on `peminjaman` UPDATE (mirroring the admin-only checks
    // in supabase_rls_admin_controls.sql), so a modified or bypassed
    // client can't work around it. Legacy rows with a null diampuOleh
    // (no owner recorded) are left open rather than permanently locked.
    final requesterId = AuthService.currentUser?.id;
    if (current.diampuOleh != null && current.diampuOleh != requesterId) {
      return false;
    }

    try {
      final updated = await _client
          .from('peminjaman')
          .update({
            'extension_status': 'Diajukan',
            'requested_tanggal_kembali': tanggalKembaliBaru.toIso8601String(),
            'extension_reason': alasan,
          })
          .eq('id', current.id!)
          .select()
          .maybeSingle();
      if (updated == null) return false;
      _replaceInCache(Peminjaman.fromMap(updated));
      return true;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  /// Client-side `isAdmin` check stays as a fast fail / better UX (no round
  /// trip for a pegawai who obviously can't do this). The real enforcement
  /// lives in the database — see supabase_rls_admin_controls.sql — so even
  /// a modified/compromised client can't approve its own request.
  static Future<bool> setujuiPerpanjangan(String id) async {
    if (!AuthService.isAdmin) return false;
    final current = _findActiveById(id);
    if (current == null || !current.isExtensionPending) return false;

    final requested = current.requestedTanggalKembali!;
    try {
      final updated = await _client
          .from('peminjaman')
          .update({
            'tanggal_kembali': requested.toIso8601String(),
            'extension_status': null,
            'requested_tanggal_kembali': null,
            'extension_reason': null,
          })
          .eq('id', current.id!)
          .select()
          .maybeSingle();
      if (updated == null) return false;
      _replaceInCache(Peminjaman.fromMap(updated));
      return true;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<bool> tolakPerpanjangan(String id) async {
    if (!AuthService.isAdmin) return false;
    final current = _findActiveById(id);
    if (current == null || !current.isExtensionPending) return false;

    try {
      final updated = await _client
          .from('peminjaman')
          .update({
            'extension_status': null,
            'requested_tanggal_kembali': null,
            'extension_reason': null,
          })
          .eq('id', current.id!)
          .select()
          .maybeSingle();
      if (updated == null) return false;
      _replaceInCache(Peminjaman.fromMap(updated));
      return true;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static List<Peminjaman> getPengajuanPerpanjangan() =>
      _cache.where((p) => p.isExtensionPending).toList();

  // ─── Item 8 (Notifikasi dropdown) ───────────────────────────────
  // Overdue documents relevant to the notification bell. Admin sees
  // every overdue document across all officers (mirrors admin's broad
  // oversight elsewhere in the app); Pegawai sees only documents they
  // personally processed — same scope as getAktifUntukPegawaiSaatIni(),
  // just filtered down to the overdue ones.
  static List<Peminjaman> getOverdueForNotifikasi() {
    if (AuthService.isAdmin) {
      return _cache.where((p) => p.isOverdue).toList();
    }
    return getAktifUntukPegawaiSaatIni().where((p) => p.isOverdue).toList();
  }

  // ─── Item 2 (Dashboard counters), di-scope ke Pegawai yang login ───
  static List<Peminjaman> getAktifUntukPegawaiSaatIni() {
    final officerId = AuthService.currentUser?.id;
    if (officerId == null) {
      return _cache.where((p) => p.status == 'Dipinjam').toList();
    }
    return _cache
        .where((p) => p.status == 'Dipinjam' && p.diampuOleh == officerId)
        .toList();
  }

  static int getMinjamBrp() => getAktifUntukPegawaiSaatIni().length;

  static int getBelumKembaliBrp() =>
      getAktifUntukPegawaiSaatIni().where((p) => p.isOverdue).length;

  // ══════════════════════════════════════════════════════════════════
  // ADMIN-ONLY RECORD CRUD (note item #1) — editing a loan's own fields
  // or deleting it outright. Distinct from kembalikan/perpanjang/
  // ajukanPerpanjangan above, which stay open to any authenticated user
  // since returning/renewing documents is normal Pegawai work.
  // Client-side isAdmin check is fast-fail UX only — the real gate is
  // the DB trigger in supabase_rls_admin_controls.sql.
  // ══════════════════════════════════════════════════════════════════

  /// Named to match what history_page.dart's edit dialog calls.
  ///
  /// Fixed on merge: this update map previously only wrote the 9
  /// Buku-Tanah-shaped fields (nama/seksi/kecamatan/.../tanggal_kembali)
  /// — editing a Surat Ukur or Warkah record's type-specific fields
  /// (jenis_surat_ukur, no_208, etc.) via History Page's edit sheet
  /// would appear to succeed but silently drop those columns, since
  /// Supabase never received them. Now writes every column
  /// Peminjaman.toMap() has an editable counterpart for.
  static Future<bool> editPeminjaman(Peminjaman updated) async {
    if (!AuthService.isAdmin) return false;
    if (updated.id == null) return false;
    try {
      final row = await _client
          .from('peminjaman')
          .update({
            'nama': updated.nama,
            'seksi': updated.seksi,
            'kecamatan': updated.kecamatan,
            'kelurahan': updated.kelurahan,
            'jenis_hak': updated.jenisHak,
            'no_hak': updated.noHak,
            'keperluan': updated.keperluan,
            'tanggal_pinjam': updated.tanggalPinjam.toIso8601String(),
            'tanggal_kembali': updated.tanggalKembali.toIso8601String(),
            'jenis_surat_ukur': updated.jenisSuratUkur,
            'no_tahun_surat_ukur': updated.noTahunSuratUkur,
            'su': updated.su,
            'gs': updated.gs,
            'jenis_warkah': updated.jenisWarkah,
            'no_208': updated.no208,
            'tahun_warkah': updated.tahunWarkah,
          })
          .eq('id', updated.id!)
          .select()
          .maybeSingle();
      if (row == null) return false;
      _replaceInCache(Peminjaman.fromMap(row));
      return true;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  /// Named to match what history_page.dart's delete dialog calls.
  static Future<bool> hapus(String id) async {
    if (!AuthService.isAdmin) return false;
    try {
      await _client.from('peminjaman').delete().eq('id', id);
      _cache.removeWhere((p) => p.id == id);
      return true;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }
}
