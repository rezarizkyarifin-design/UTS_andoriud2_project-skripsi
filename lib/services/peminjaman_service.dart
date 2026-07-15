import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/peminjaman.dart';
import 'auth_service.dart';

/// Turns a raw Supabase/Postgrest error into something a SnackBar can show
/// a Pegawai without them needing to read Postgres error codes.
String _friendlyError(Object e) {
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

  static List<Peminjaman> getAll() => List.unmodifiable(_cache);

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
    } catch (e) {
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
  static Future<bool> existsActiveNoHak(String noHak) async {
    try {
      final rows = await _client
          .from('peminjaman')
          .select('id')
          .eq('no_hak', noHak)
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
          .update({'status': 'Kembali'})
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
          .update({'status': 'Kembali'})
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
