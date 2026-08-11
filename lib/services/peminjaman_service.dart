import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/peminjaman.dart';
import 'auth_service.dart';

bool _isNetworkError(Object e) {
  if (e is SocketException) return true;
  final text = e.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection failed');
}

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

  static Peminjaman? _findActiveByNoHak(String noHak) {
    for (final p in _cache) {
      if (p.noHak == noHak && p.status == 'Dipinjam') return p;
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

  /// True if a no_hak already has an active (status == 'Dipinjam') loan.
  /// Checked directly against Supabase rather than the local cache, so
  /// it still catches a duplicate even if the cache is stale or another
  /// device/session created the active loan.
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
          .eq('status', 'Dipinjam')
          .limit(1);
      return rows.isNotEmpty;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<void> tambah(Peminjaman peminjaman) async {
    final withOfficer = peminjaman.diampuOleh == null
        ? peminjaman.copyWith(diampuOleh: AuthService.currentUser?.id)
        : peminjaman;

    try {
      final inserted = await _client
          .from('peminjaman')
          .insert(withOfficer.toMap())
          .select()
          .single();

      _cache.insert(0, Peminjaman.fromMap(inserted));
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  /// Returns true if at least one row was updated. Returns false if no
  /// matching row was found — including when RLS silently hides the row
  /// from an UPDATE (Postgres doesn't error in that case, it just
  /// matches 0 rows), so callers can now tell the difference between
  /// "worked" and "silently did nothing".
  ///
  /// Uses .select() (a list) rather than .maybeSingle() because no_hak
  /// isn't guaranteed unique in the table — if duplicate active rows
  /// exist for the same no_hak (bad data from earlier testing, a double
  /// submit, etc.) this marks all of them Kembali instead of throwing
  /// PGRST116 ("result contains 2 rows"). Clean up real duplicates at
  /// the data level when you find them; this is just a safety net.
  static Future<bool> kembalikan(String noHak) async {
    try {
      final rows = await _client
          .from('peminjaman')
          .update({
            'status': 'Kembali',
            'kembali_oleh': AuthService.currentUser?.id,
            'kembali_oleh_nama': AuthService.currentUser?.nama,
          })
          .eq('no_hak', noHak)
          .eq('status', 'Dipinjam')
          .select();
      if (rows.isEmpty) return false;
      for (final row in rows) {
        _replaceInCache(Peminjaman.fromMap(row));
      }
      return true;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  /// Bulk version of [kembalikan] for the multi-select "Tandai Kembali"
  /// flow — returns the list of no_hak that actually got updated so the
  /// UI can report "X dari Y berhasil" instead of an all-or-nothing result.
  static Future<List<String>> kembalikanBanyak(List<String> noHakList) async {
    if (noHakList.isEmpty) return [];
    try {
      final rows = await _client
          .from('peminjaman')
          .update({
            'status': 'Kembali',
            'kembali_oleh': AuthService.currentUser?.id,
            'kembali_oleh_nama': AuthService.currentUser?.nama,
          })
          .inFilter('no_hak', noHakList)
          .eq('status', 'Dipinjam')
          .select();
      final berhasil = <String>[];
      for (final row in rows) {
        final p = Peminjaman.fromMap(row);
        _replaceInCache(p);
        berhasil.add(p.noHak);
      }
      return berhasil;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ─── PERPANJANG WAKTU PEMINJAMAN (langsung, tanpa approval) ───
  // Same duplicate-safety note as kembalikan() above.
  static Future<void> perpanjang(
    String noHak,
    DateTime tanggalKembaliBaru,
  ) async {
    try {
      final rows = await _client
          .from('peminjaman')
          .update({'tanggal_kembali': tanggalKembaliBaru.toIso8601String()})
          .eq('no_hak', noHak)
          .eq('status', 'Dipinjam')
          .select();
      for (final row in rows) {
        _replaceInCache(Peminjaman.fromMap(row));
      }
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
  // (see widgets/jenis_dokumen_breakdown.dart). Counts every record
  // regardless of status — this is a composition-of-the-archive figure,
  // not an "active loans" figure like getSedangDipinjam() above.
  static int getCountBukuTanah() =>
      _cache.where((p) => p.jenisDokumen == 'Buku Tanah').length;

  static int getCountSuratUkur() =>
      _cache.where((p) => p.jenisDokumen == 'Surat Ukur').length;

  static int getCountWarkah() =>
      _cache.where((p) => p.jenisDokumen == 'Warkah').length;

  // ══════════════════════════════════════════════════════════════════
  // EXTENSION STATE MACHINE — same states/transitions as before, now
  // persisted to Supabase instead of just an in-memory object.
  // ══════════════════════════════════════════════════════════════════

  static Future<bool> ajukanPerpanjangan(
    String noHak,
    DateTime tanggalKembaliBaru,
    String alasan,
  ) async {
    final current = _findActiveByNoHak(noHak);
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
  static Future<bool> setujuiPerpanjangan(String noHak) async {
    if (!AuthService.isAdmin) return false;
    final current = _findActiveByNoHak(noHak);
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

  static Future<bool> tolakPerpanjangan(String noHak) async {
    if (!AuthService.isAdmin) return false;
    final current = _findActiveByNoHak(noHak);
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
