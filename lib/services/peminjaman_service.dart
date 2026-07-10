import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/peminjaman.dart';
import 'auth_service.dart';

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
  /// and whenever you want to force a full re-sync (e.g. HistoryPage's
  /// refresh button) to pull the latest data from Supabase into the cache.
  static Future<void> refresh() async {
    final rows = await _client
        .from('peminjaman')
        .select()
        .order('created_at', ascending: false);
    _cache
      ..clear()
      ..addAll(rows.map((row) => Peminjaman.fromMap(row)));
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
    final rows = await _client
        .from('peminjaman')
        .select('id')
        .eq('no_hak', noHak)
        .eq('status', 'Dipinjam')
        .limit(1);
    return rows.isNotEmpty;
  }

  static Future<void> tambah(Peminjaman peminjaman) async {
    final withOfficer = peminjaman.diampuOleh == null
        ? peminjaman.copyWith(diampuOleh: AuthService.currentUser?.id)
        : peminjaman;

    final inserted = await _client
        .from('peminjaman')
        .insert(withOfficer.toMap())
        .select()
        .single();

    _cache.insert(0, Peminjaman.fromMap(inserted));
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
  }

  // ─── PERPANJANG WAKTU PEMINJAMAN (langsung, tanpa approval) ───
  // Same duplicate-safety note as kembalikan() above.
  static Future<void> perpanjang(
    String noHak,
    DateTime tanggalKembaliBaru,
  ) async {
    final rows = await _client
        .from('peminjaman')
        .update({'tanggal_kembali': tanggalKembaliBaru.toIso8601String()})
        .eq('no_hak', noHak)
        .eq('status', 'Dipinjam')
        .select();
    for (final row in rows) {
      _replaceInCache(Peminjaman.fromMap(row));
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
  }

  static Future<bool> setujuiPerpanjangan(String noHak) async {
    if (!AuthService.isAdmin) return false;
    final current = _findActiveByNoHak(noHak);
    if (current == null || !current.isExtensionPending) return false;

    final requested = current.requestedTanggalKembali!;
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
  }

  static Future<bool> tolakPerpanjangan(String noHak) async {
    if (!AuthService.isAdmin) return false;
    final current = _findActiveByNoHak(noHak);
    if (current == null || !current.isExtensionPending) return false;

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
}
