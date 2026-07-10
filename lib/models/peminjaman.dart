class Peminjaman {
  // Supabase row UUID. Null for an object that hasn't been saved yet
  // (e.g. freshly built in FormPage before calling PeminjamanService.tambah).
  final String? id;

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
  final String? diampuOleh; // AppUser.id (uuid)

  // ─── Perpanjangan waktu (state machine, lihat PeminjamanService) ───
  final String? extensionStatus;
  final DateTime? requestedTanggalKembali;
  final String? extensionReason;

  Peminjaman({
    this.id,
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

  // ─── SUPABASE MAPPING ───────────────────────────────────────────
  // Column names use snake_case (jenis_hak, no_hak, tanggal_pinjam, etc.)
  // to match the `peminjaman` table from supabase_schema.sql.

  factory Peminjaman.fromMap(Map<String, dynamic> map) {
    return Peminjaman(
      id: map['id'] as String?,
      nama: map['nama'] as String,
      seksi: map['seksi'] as String,
      kecamatan: map['kecamatan'] as String,
      kelurahan: map['kelurahan'] as String,
      jenisHak: map['jenis_hak'] as String,
      noHak: map['no_hak'] as String,
      keperluan: map['keperluan'] as String,
      tanggalPinjam: DateTime.parse(map['tanggal_pinjam'] as String),
      tanggalKembali: DateTime.parse(map['tanggal_kembali'] as String),
      status: map['status'] as String? ?? 'Dipinjam',
      diampuOleh: map['diampu_oleh'] as String?,
      extensionStatus: map['extension_status'] as String?,
      requestedTanggalKembali: map['requested_tanggal_kembali'] == null
          ? null
          : DateTime.parse(map['requested_tanggal_kembali'] as String),
      extensionReason: map['extension_reason'] as String?,
    );
  }

  // Deliberately omits id/created_at/updated_at — the database generates
  // those itself (default gen_random_uuid(), default now(), trigger).
  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'seksi': seksi,
      'kecamatan': kecamatan,
      'kelurahan': kelurahan,
      'jenis_hak': jenisHak,
      'no_hak': noHak,
      'keperluan': keperluan,
      'tanggal_pinjam': tanggalPinjam.toIso8601String(),
      'tanggal_kembali': tanggalKembali.toIso8601String(),
      'status': status,
      'diampu_oleh': diampuOleh,
      'extension_status': extensionStatus,
      'requested_tanggal_kembali': requestedTanggalKembali?.toIso8601String(),
      'extension_reason': extensionReason,
    };
  }

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

  Peminjaman copyWith({
    String? id,
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
      id: id ?? this.id,
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
