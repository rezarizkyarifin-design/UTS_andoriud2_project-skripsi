import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/peminjaman.dart';
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

  static Future<void> refresh() async {
    try {
      // Execute Relational Query: Fetch transaction AND its physical document details
      final rows = await _client
          .from('peminjaman')
          .select('*, master_arsip(*)')
          .order('created_at', ascending: false);

      _cache
        ..clear()
        ..addAll(rows.map((row) => Peminjaman.fromMap(row)));
      isStaleCache = false;
      await _persistCacheToDisk();
    } catch (e) {
      if (_cache.isEmpty) {
        isStaleCache = await _loadCacheFromDisk();
      }
      throw Exception(_friendlyError(e));
    }
  }

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

  // ══════════════════════════════════════════════════════════════════
  // FIX (regression from the master_arsip migration): the rewritten
  // existsActiveNoHak only ever checked master_arsip.no_hak — but every
  // Warkah document stores '-' in no_hak (its real identity field is
  // no_208 instead; see form_page.dart). That means the duplicate check
  // silently never caught a real duplicate Warkah request, exactly the
  // same bug fixed earlier in the flat-schema version and lost when this
  // function got rewritten for the relational schema.
  //
  // Also dropped 'Perpanjangan' from the status filter — that's not a
  // real value of the `status` column (extensions are tracked via the
  // separate `extension_status` field, not `status` itself), so it was
  // dead weight that never matched anything.
  //
  // Replace the existing existsActiveNoHak in peminjaman_service.dart
  // with this version. Remember to also update the call site in
  // form_page.dart to pass jenisDokumen, e.g.:
  //   PeminjamanService.existsActiveNoHak(dedupeKey, jenisDokumen: _selectedJenisDokumen!)
  // ══════════════════════════════════════════════════════════════════

  /// True if a document already has an active loan blocking a new
  /// request — either already approved ('Dipinjam') or still awaiting
  /// admin decision ('Diajukan'). [jenisDokumen] picks which column on
  /// master_arsip actually identifies the document: no_hak for Buku
  /// Tanah/Surat Ukur, but no_208 for Warkah.
  static Future<bool> existsActiveNoHak(
    String identifier, {
    String jenisDokumen = 'Buku Tanah',
  }) async {
    final column = jenisDokumen == 'Warkah' ? 'no_208' : 'no_hak';
    try {
      final response = await _client
          .from('peminjaman')
          .select('id, master_arsip!inner($column)')
          .eq('master_arsip.$column', identifier)
          .inFilter('status', ['Dipinjam', 'Diajukan'])
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  static Future<Peminjaman> tambah(Peminjaman peminjaman) async {
    final withOfficer = peminjaman.diampuOleh == null
        ? peminjaman.copyWith(diampuOleh: AuthService.currentUser?.id)
        : peminjaman;
    final withStatus = withOfficer.copyWith(
      status: AuthService.isAdmin ? 'Dipinjam' : 'Diajukan',
    );

    try {
      // 1. Determine the Natural Key for the physical document
      final String dedupeColumn = withStatus.jenisDokumen == 'Warkah'
          ? 'no_208'
          : 'no_hak';
      final String dedupeValue = withStatus.jenisDokumen == 'Warkah'
          ? withStatus.no208!
          : withStatus.noHak;

      // 2. Search Master Arsip to see if the physical document already exists
      var existingArsip = await _client
          .from('master_arsip')
          .select('id')
          .eq(dedupeColumn, dedupeValue)
          .maybeSingle();

      String dokumenId;

      if (existingArsip == null) {
        // 3a. Not found: Register the physical document into inventory first
        final insertedArsip = await _client
            .from('master_arsip')
            .insert({
              'jenis_dokumen': withStatus.jenisDokumen,
              'kecamatan': withStatus.kecamatan == '-'
                  ? null
                  : withStatus.kecamatan,
              'kelurahan': withStatus.kelurahan == '-'
                  ? null
                  : withStatus.kelurahan,
              'jenis_hak': withStatus.jenisHak == '-'
                  ? null
                  : withStatus.jenisHak,
              'no_hak': withStatus.noHak == '-' ? null : withStatus.noHak,
              'jenis_surat_ukur': withStatus.jenisSuratUkur,
              'no_tahun_surat_ukur': withStatus.noTahunSuratUkur,
              'su': withStatus.su,
              'gs': withStatus.gs,
              'jenis_warkah': withStatus.jenisWarkah,
              'no_208': withStatus.no208,
              'tahun_warkah': withStatus.tahunWarkah,
            })
            .select('id')
            .single();

        dokumenId = insertedArsip['id'];
      } else {
        // 3b. Found: Grab the existing UUID
        dokumenId = existingArsip['id'];
      }

      // 4. Insert the Transaction mapping to the UUID
      final inserted = await _client
          .from('peminjaman')
          .insert({
            'dokumen_id': dokumenId,
            'nama': withStatus.nama,
            'seksi': withStatus.seksi,
            'keperluan': withStatus.keperluan,
            'tanggal_pinjam': withStatus.tanggalPinjam.toIso8601String(),
            'tanggal_kembali': withStatus.tanggalKembali.toIso8601String(),
            'status': withStatus.status,
            'diampu_oleh': withStatus.diampuOleh,
          })
          .select(
            '*, master_arsip(*)',
          ) // Fetch the joined result back for the UI
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
  ///
  /// BUG FIX (14.08.2026): this used to clear extension_status/
  /// requested_tanggal_kembali/extension_reason without ever recording
  /// WHO approved the extension — there was no column for it at all, so
  /// there was genuinely nothing to display, on any screen, no matter
  /// how the UI was written. perpanjangan_disetujui_oleh(_nama) is a
  /// single slot (like disetujui_oleh above), not a full history — if
  /// this loan gets extended again later, it's overwritten with the
  /// newer approval.
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
            'perpanjangan_disetujui_oleh': AuthService.currentUser?.id,
            'perpanjangan_disetujui_oleh_nama': AuthService.currentUser?.nama,
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
      // 1. First fetch the transaction to get its associated dokumen_id
      final currentTx = await _client
          .from('peminjaman')
          .select('dokumen_id')
          .eq('id', updated.id!)
          .maybeSingle();

      if (currentTx == null) return false;
      final String dokumenId = currentTx['dokumen_id'];

      // 2. Update the master inventory document fields
      await _client
          .from('master_arsip')
          .update({
            'jenis_dokumen': updated.jenisDokumen,
            'kecamatan': updated.kecamatan == '-' ? null : updated.kecamatan,
            'kelurahan': updated.kelurahan == '-' ? null : updated.kelurahan,
            'jenis_hak': updated.jenisHak == '-' ? null : updated.jenisHak,
            'no_hak': updated.noHak == '-' ? null : updated.noHak,
            'jenis_surat_ukur': updated.jenisSuratUkur,
            'no_tahun_surat_ukur': updated.noTahunSuratUkur,
            'su': updated.su,
            'gs': updated.gs,
            'jenis_warkah': updated.jenisWarkah,
            'no_208': updated.no208,
            'tahun_warkah': updated.tahunWarkah,
          })
          .eq('id', dokumenId);

      // 3. Update the transaction-specific fields
      final row = await _client
          .from('peminjaman')
          .update({
            'nama': updated.nama,
            'seksi': updated.seksi,
            'keperluan': updated.keperluan,
            'tanggal_pinjam': updated.tanggalPinjam.toIso8601String(),
            'tanggal_kembali': updated.tanggalKembali.toIso8601String(),
          })
          .eq('id', updated.id!)
          .select('*, master_arsip(*)')
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
