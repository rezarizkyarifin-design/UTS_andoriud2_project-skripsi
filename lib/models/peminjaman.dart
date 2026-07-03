class Peminjaman {
  final String nama;
  final String seksi;
  final String kecamatan;
  final String kelurahan;
  final String jenisHak;
  final String noHak;
  final String keperluan;
  final DateTime tanggalPinjam;
  final DateTime tanggalKembali;
  final String status; // 'Dipinjam' | 'Kembali'

  // ─── Item 1 (Auth) link: siapa (Pegawai) yang memproses peminjaman ini.
  // Nullable & additive — record lama tanpa field ini tetap valid.
  final String? diampuOleh; // AppUser.id

  // ─── Perpanjangan waktu (state machine, lihat PeminjamanService) ───
  // extensionStatus null artinya tidak ada pengajuan aktif/berjalan.
  // 'Diajukan'  -> menunggu keputusan Admin, timer dianggap freeze di UI.
  // 'Disetujui' -> sudah diproses & tanggalKembali sudah diupdate.
  // 'Ditolak'   -> sudah diproses, tanggalKembali TIDAK berubah.
  final String? extensionStatus;
  final DateTime? requestedTanggalKembali;
  final String? extensionReason;

  Peminjaman({
    required this.nama,
    required this.seksi,
    required this.kecamatan,
    required this.kelurahan,
    required this.jenisHak,
    required this.noHak,
    required this.keperluan,
    required this.tanggalPinjam,
    required this.tanggalKembali,
    this.status = 'Dipinjam',
    this.diampuOleh,
    this.extensionStatus,
    this.requestedTanggalKembali,
    this.extensionReason,
  });

  // ─── OVERDUE HELPER ───
  bool get isOverdue =>
      status == 'Dipinjam' && DateTime.now().isAfter(tanggalKembali);

  int get hariTerlambat {
    if (!isOverdue) return 0;
    return DateTime.now().difference(tanggalKembali).inDays;
  }

  // ─── EXTENSION HELPERS ───
  bool get isExtensionPending => extensionStatus == 'Diajukan';

  static String _formatDate(DateTime date) {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${bulan[date.month - 1]} ${date.year}';
  }

  String get tanggalPinjamFormatted => _formatDate(tanggalPinjam);
  String get tanggalKembaliFormatted => _formatDate(tanggalKembali);
  String? get requestedTanggalKembaliFormatted =>
      requestedTanggalKembali == null
      ? null
      : _formatDate(requestedTanggalKembali!);

  // ─── COPY WITH (dipakai untuk update status/tanggal tanpa bikin object baru manual) ───
  // clearExtension: dipakai PeminjamanService untuk secara eksplisit
  // mengosongkan field pengajuan (copyWith biasa tidak bisa set null
  // lewat parameter opsional, karena `field ?? this.field` akan
  // mempertahankan nilai lama kalau argumennya null).
  Peminjaman copyWith({
    String? nama,
    String? seksi,
    String? kecamatan,
    String? kelurahan,
    String? jenisHak,
    String? noHak,
    String? keperluan,
    DateTime? tanggalPinjam,
    DateTime? tanggalKembali,
    String? status,
    String? diampuOleh,
    String? extensionStatus,
    DateTime? requestedTanggalKembali,
    String? extensionReason,
    bool clearExtension = false,
  }) {
    return Peminjaman(
      nama: nama ?? this.nama,
      seksi: seksi ?? this.seksi,
      kecamatan: kecamatan ?? this.kecamatan,
      kelurahan: kelurahan ?? this.kelurahan,
      jenisHak: jenisHak ?? this.jenisHak,
      noHak: noHak ?? this.noHak,
      keperluan: keperluan ?? this.keperluan,
      tanggalPinjam: tanggalPinjam ?? this.tanggalPinjam,
      tanggalKembali: tanggalKembali ?? this.tanggalKembali,
      status: status ?? this.status,
      diampuOleh: diampuOleh ?? this.diampuOleh,
      extensionStatus: clearExtension
          ? null
          : (extensionStatus ?? this.extensionStatus),
      requestedTanggalKembali: clearExtension
          ? null
          : (requestedTanggalKembali ?? this.requestedTanggalKembali),
      extensionReason: clearExtension
          ? null
          : (extensionReason ?? this.extensionReason),
    );
  }
}
