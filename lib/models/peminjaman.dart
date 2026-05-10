class Peminjaman {
  String nama;
  String seksi;
  String kecamatan;
  String kelurahan;
  String jenisHak;
  String noHak;
  String keperluan;
  DateTime tanggalPinjam;
  DateTime tanggalKembali;
  String status;

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
    this.status = "Dipinjam",
  });

  String get tanggalPinjamFormatted => _formatDate(tanggalPinjam);
  String get tanggalKembaliFormatted => _formatDate(tanggalKembali);

  String _formatDate(DateTime date) {
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
}
