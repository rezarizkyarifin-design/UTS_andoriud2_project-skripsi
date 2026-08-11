class Peminjaman {
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

  // ─── Atribusi "Proses Kembali" — siapa admin yang menandai dokumen ini
  final String? kembaliOleh; // AppUser.id (uuid)
  final String? kembaliOlehNama;

  // ─── Perpanjangan waktu (state machine, lihat PeminjamanService) ───
  final String? extensionStatus;
  final DateTime? requestedTanggalKembali;
  final String? extensionReason;

  // ─── Jenis Dokumen (07.08.2026) — 'Buku Tanah' | 'Surat Ukur' | 'Warkah'.
  // Existing rows created before this feature have no value for this
  // column at all (it didn't exist yet) — fromMap defaults those to
  // 'Buku Tanah', since every record before this point genuinely was
  // that type. Kept non-nullable here so every OTHER file (History,
  // Return, Barcode, Home...) that already assumes every Peminjaman has
  // a jenisDokumen keeps compiling unchanged.
  final String jenisDokumen;

  // ─── Surat Ukur–specific (null for Buku Tanah / Warkah) ───
  final String? jenisSuratUkur;
  final String? noTahunSuratUkur;
  final String? su;
  final String? gs; // Gambar Situasi

  // ─── Warkah–specific (null for Buku Tanah / Surat Ukur) ───
  final String? jenisWarkah;
  final String? no208;
  final String? tahunWarkah;

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
    this.kembaliOleh,
    this.kembaliOlehNama,
    this.extensionStatus,
    this.requestedTanggalKembali,
    this.extensionReason,
    this.jenisDokumen = 'Buku Tanah',
    this.jenisSuratUkur,
    this.noTahunSuratUkur,
    this.su,
    this.gs,
    this.jenisWarkah,
    this.no208,
    this.tahunWarkah,
  });

  // ─── SUPABASE MAPPING ───────────────────────────────────────────
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
      kembaliOleh: map['kembali_oleh'] as String?,
      kembaliOlehNama: map['kembali_oleh_nama'] as String?,
      extensionStatus: map['extension_status'] as String?,
      requestedTanggalKembali: map['requested_tanggal_kembali'] == null
          ? null
          : DateTime.parse(map['requested_tanggal_kembali'] as String),
      extensionReason: map['extension_reason'] as String?,
      jenisDokumen: map['jenis_dokumen'] as String? ?? 'Buku Tanah',
      jenisSuratUkur: map['jenis_surat_ukur'] as String?,
      noTahunSuratUkur: map['no_tahun_surat_ukur'] as String?,
      su: map['su'] as String?,
      gs: map['gs'] as String?,
      jenisWarkah: map['jenis_warkah'] as String?,
      no208: map['no_208'] as String?,
      tahunWarkah: map['tahun_warkah'] as String?,
    );
  }

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
      'kembali_oleh': kembaliOleh,
      'kembali_oleh_nama': kembaliOlehNama,
      'extension_status': extensionStatus,
      'requested_tanggal_kembali': requestedTanggalKembali?.toIso8601String(),
      'extension_reason': extensionReason,
      'jenis_dokumen': jenisDokumen,
      'jenis_surat_ukur': jenisSuratUkur,
      'no_tahun_surat_ukur': noTahunSuratUkur,
      'su': su,
      'gs': gs,
      'jenis_warkah': jenisWarkah,
      'no_208': no208,
      'tahun_warkah': tahunWarkah,
    };
  }

  // ─── OVERDUE HELPER ───
  bool get isOverdue =>
      status == 'Dipinjam' && DateTime.now().isAfter(tanggalKembali);

  int get hariTerlambat {
    if (!isOverdue) return 0;
    return DateTime.now().difference(tanggalKembali).inDays;
  }

  // ─── ATRIBUSI PROSES KEMBALI ───
  String? get returnedByMessage => kembaliOlehNama == null
      ? null
      : '$kembaliOlehNama menandai dokumen telah kembali';

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
    String? kembaliOleh,
    String? kembaliOlehNama,
    String? extensionStatus,
    DateTime? requestedTanggalKembali,
    String? extensionReason,
    bool clearExtension = false,
    String? jenisDokumen,
    String? jenisSuratUkur,
    String? noTahunSuratUkur,
    String? su,
    String? gs,
    String? jenisWarkah,
    String? no208,
    String? tahunWarkah,
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
      kembaliOleh: kembaliOleh ?? this.kembaliOleh,
      kembaliOlehNama: kembaliOlehNama ?? this.kembaliOlehNama,
      extensionStatus: clearExtension
          ? null
          : (extensionStatus ?? this.extensionStatus),
      requestedTanggalKembali: clearExtension
          ? null
          : (requestedTanggalKembali ?? this.requestedTanggalKembali),
      extensionReason: clearExtension
          ? null
          : (extensionReason ?? this.extensionReason),
      jenisDokumen: jenisDokumen ?? this.jenisDokumen,
      jenisSuratUkur: jenisSuratUkur ?? this.jenisSuratUkur,
      noTahunSuratUkur: noTahunSuratUkur ?? this.noTahunSuratUkur,
      su: su ?? this.su,
      gs: gs ?? this.gs,
      jenisWarkah: jenisWarkah ?? this.jenisWarkah,
      no208: no208 ?? this.no208,
      tahunWarkah: tahunWarkah ?? this.tahunWarkah,
    );
  }
}
