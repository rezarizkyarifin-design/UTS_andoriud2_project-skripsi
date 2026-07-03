import '../models/peminjaman.dart';
import 'auth_service.dart';

class PeminjamanService {
  static final List<Peminjaman> _data = [];

  static List<Peminjaman> getAll() => List.unmodifiable(_data);

  static void tambah(Peminjaman peminjaman) {
    // Item 1/Phase 1 link: catat siapa (Pegawai) yang memproses peminjaman
    // ini, kalau si pemanggil belum set `diampuOleh` sendiri.
    final withOfficer = peminjaman.diampuOleh == null
        ? peminjaman.copyWith(diampuOleh: AuthService.currentUser?.id)
        : peminjaman;
    _data.add(withOfficer);
  }

  static void kembalikan(String noHak) {
    final index = _data.indexWhere((p) => p.noHak == noHak);
    if (index == -1) return;
    _data[index] = _data[index].copyWith(status: 'Kembali');
  }

  // ─── PERPANJANG WAKTU PEMINJAMAN (langsung, tanpa approval) ───
  // Dipertahankan apa adanya untuk kompatibilitas mundur (mis. dipakai
  // admin sendiri untuk koreksi manual). Untuk alur Pegawai -> Admin yang
  // butuh persetujuan, pakai [ajukanPerpanjangan] / [setujuiPerpanjangan] /
  // [tolakPerpanjangan] di bawah.
  static void perpanjang(String noHak, DateTime tanggalKembaliBaru) {
    final index = _data.indexWhere((p) => p.noHak == noHak);
    if (index == -1) return;
    _data[index] = _data[index].copyWith(tanggalKembali: tanggalKembaliBaru);
  }

  static int getSedangDipinjam() =>
      _data.where((p) => p.status == 'Dipinjam').length;

  static int getTelahKembali() =>
      _data.where((p) => p.status == 'Kembali').length;

  static int getTerlambat() => _data.where((p) => p.isOverdue).length;

  // ══════════════════════════════════════════════════════════════════
  // EXTENSION STATE MACHINE
  //
  //   ACTIVE ──(overdue)──► OVERDUE
  //      │                     │
  //      └────(Pegawai ajukan perpanjangan)────► EXTENSION_REQUESTED
  //                                                  │           │
  //                                     Admin setujui│           │Admin tolak
  //                                                  ▼           ▼
  //                                     tanggalKembali diupdate   tanggalKembali
  //                                     & kembali ACTIVE          TETAP (harus
  //                                                               segera dikembalikan)
  //
  // Pegawai TIDAK BISA memperpanjang sendiri — hanya bisa mengajukan.
  // ══════════════════════════════════════════════════════════════════

  /// Dipanggil oleh Pegawai. Membekukan due-date lama secara visual (UI
  /// cek `isExtensionPending`) sambil menunggu keputusan Admin.
  /// Return false kalau data tidak ditemukan atau sudah ada pengajuan
  /// aktif yang belum diputuskan (mencegah spam pengajuan berulang).
  static bool ajukanPerpanjangan(
    String noHak,
    DateTime tanggalKembaliBaru,
    String alasan,
  ) {
    final index = _data.indexWhere((p) => p.noHak == noHak);
    if (index == -1) return false;
    if (_data[index].isExtensionPending) return false;

    _data[index] = _data[index].copyWith(
      extensionStatus: 'Diajukan',
      requestedTanggalKembali: tanggalKembaliBaru,
      extensionReason: alasan,
    );
    return true;
  }

  /// Dipanggil oleh Admin. Menerapkan tanggal kembali baru & membersihkan
  /// state pengajuan. Ditolak (return false) kalau pemanggil bukan Admin —
  /// ini satu-satunya penjaga di layer service terhadap self-approval,
  /// jadi jangan lewati service ini dari UI Pegawai.
  static bool setujuiPerpanjangan(String noHak) {
    if (!AuthService.isAdmin) return false;
    final index = _data.indexWhere((p) => p.noHak == noHak);
    if (index == -1 || !_data[index].isExtensionPending) return false;

    final requested = _data[index].requestedTanggalKembali!;
    _data[index] = _data[index].copyWith(
      tanggalKembali: requested,
      clearExtension: true,
    );
    return true;
  }

  /// Dipanggil oleh Admin. Menolak pengajuan — tanggalKembali TIDAK
  /// berubah (dokumen tetap harus segera dikembalikan/overdue apa
  /// adanya), hanya state pengajuannya yang dibersihkan.
  static bool tolakPerpanjangan(String noHak) {
    if (!AuthService.isAdmin) return false;
    final index = _data.indexWhere((p) => p.noHak == noHak);
    if (index == -1 || !_data[index].isExtensionPending) return false;

    _data[index] = _data[index].copyWith(clearExtension: true);
    return true;
  }

  /// Untuk dashboard Admin: daftar semua pengajuan yang masih menunggu
  /// keputusan.
  static List<Peminjaman> getPengajuanPerpanjangan() =>
      _data.where((p) => p.isExtensionPending).toList();

  // ─── Item 2 (Dashboard counters), di-scope ke Pegawai yang login ───
  // Kalau tidak ada user login (mis. dipanggil dari konteks Admin/global),
  // fallback ke semua data seperti method getSedangDipinjam()/getTerlambat()
  // di atas.
  static List<Peminjaman> getAktifUntukPegawaiSaatIni() {
    final officerId = AuthService.currentUser?.id;
    if (officerId == null) {
      return _data.where((p) => p.status == 'Dipinjam').toList();
    }
    return _data
        .where((p) => p.status == 'Dipinjam' && p.diampuOleh == officerId)
        .toList();
  }

  static int getMinjamBrp() => getAktifUntukPegawaiSaatIni().length;

  static int getBelumKembaliBrp() =>
      getAktifUntukPegawaiSaatIni().where((p) => p.isOverdue).length;
}
