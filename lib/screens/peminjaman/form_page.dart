import 'package:flutter/material.dart';
import '../../models/peminjaman.dart';
import '../services/peminjaman_service.dart';
import '../../data/data.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_scan_fab.dart';

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _namaController = TextEditingController();
  final _noHakController = TextEditingController();
  final _keperluanController = TextEditingController();

  // ─── Jenis Dokumen (07.08.2026) ───
  // User picks this first — it decides which of the field groups below
  // actually show up. See _buildJenisDokumenSelector().
  String? _selectedJenisDokumen;
  static const _jenisDokumenOptions = ['Buku Tanah', 'Surat Ukur', 'Warkah'];

  // ─── Surat Ukur–specific (28.08.2026) ───────────────────────────────
  // Previously a free-text "Jenis Surat Ukur" field, which let anyone
  // type anything at all — but a Surat Ukur is only ever one of exactly
  // two real classifications, SU or GS. Free text here let dirty values
  // (typos, blanks-that-aren't-blank, inconsistent casing) into a field
  // that filtering/search logic downstream treats as one of only two
  // known values. Constrained to a dropdown instead.
  String? _selectedJenisSuratUkur; // 'SU' or 'GS'
  final _noTahunSuratUkurController = TextEditingController();

  // ─── Warkah–specific (28.08.2026) ───────────────────────────────────
  // Same reasoning as Surat Ukur above — Warkah is only ever one of
  // exactly three types (BN, Subsi III, PBT), not free text.
  String? _selectedJenisWarkah; // 'BN' | 'Subsi III' | 'PBT'
  final _no208Controller = TextEditingController();
  final _tahunWarkahController = TextEditingController();

  String? _selectedSeksi;
  String? _selectedKecamatan;
  String? _selectedKelurahan;
  String? _selectedJenisHak;

  late DateTime _tanggalPinjam;
  late DateTime _tanggalKembali;

  static const Color _primaryGreen = Color(0xFF1B4332);
  static const Color _accentGreen = Color(0xFF2D6A4F);
  static const Color _accentPurple = Color(0xFF5C5FCD);

  @override
  void initState() {
    super.initState();
    _tanggalPinjam = DateTime.now();
    _tanggalKembali = _tanggalPinjam.add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noHakController.dispose();
    _keperluanController.dispose();
    _noTahunSuratUkurController.dispose();
    _no208Controller.dispose();
    _tahunWarkahController.dispose();
    super.dispose();
  }

  // ─── ROBUST KELURAHAN LOOKUP ───
  List<String> _kelurahanFor(String? kecamatan) {
    if (kecamatan == null) return const [];
    final direct = Data.kelurahan[kecamatan];
    if (direct != null && direct.isNotEmpty) return direct;

    final normalized = kecamatan.trim().toLowerCase();
    for (final entry in Data.kelurahan.entries) {
      if (entry.key.trim().toLowerCase() == normalized) {
        return entry.value;
      }
    }
    return const [];
  }

  // ─── FORMAT DATE ───
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

  // ─── PICK DATE ───
  Future<void> _pickDate({required bool isPinjam}) async {
    final DateTime firstDate = isPinjam ? DateTime(2020) : _tanggalPinjam;
    final DateTime initial = isPinjam
        ? _tanggalPinjam
        : (_tanggalKembali.isBefore(_tanggalPinjam)
              ? _tanggalPinjam
              : _tanggalKembali);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _accentGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isPinjam) {
          _tanggalPinjam = picked;
          if (_tanggalKembali.isBefore(_tanggalPinjam)) {
            _tanggalKembali = _tanggalPinjam.add(const Duration(days: 7));
          }
        } else {
          _tanggalKembali = picked;
        }
      });
    }
  }

  // ─── RESET FORM (dipanggil setelah simpan berhasil, supaya kalau user
  // balik dari halaman Barcode via tombol back, form tidak menampilkan
  // data peminjaman yang baru saja disimpan seolah belum tersimpan) ───
  void _resetForm() {
    _namaController.clear();
    _noHakController.clear();
    _keperluanController.clear();
    _noTahunSuratUkurController.clear();
    _no208Controller.clear();
    _tahunWarkahController.clear();
    setState(() {
      _selectedJenisDokumen = null;
      _selectedSeksi = null;
      _selectedKecamatan = null;
      _selectedKelurahan = null;
      _selectedJenisHak = null;
      _selectedJenisSuratUkur = null;
      _selectedJenisWarkah = null;
      _tanggalPinjam = DateTime.now();
      _tanggalKembali = _tanggalPinjam.add(const Duration(days: 7));
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── SAVE ───
  void _simpanPeminjaman() async {
    const lengkapiPesan = 'Lengkapi semua kolom sebelum menyimpan.';

    if (_selectedJenisDokumen == null) {
      _showError('Pilih jenis dokumen terlebih dahulu.');
      return;
    }
    if (_namaController.text.trim().isEmpty ||
        _selectedSeksi == null ||
        _keperluanController.text.trim().isEmpty) {
      _showError(lengkapiPesan);
      return;
    }

    // Which value stands in for "no hak" when checking for an existing
    // active loan of the same object depends on the document type — a
    // Warkah has no no_hak concept at all, so its "No 208" number is
    // used as the equivalent unique key instead.
    final String dedupeKey;

    switch (_selectedJenisDokumen) {
      case 'Buku Tanah':
        if (_selectedKecamatan == null ||
            _selectedKelurahan == null ||
            _selectedJenisHak == null ||
            _noHakController.text.trim().isEmpty) {
          _showError(lengkapiPesan);
          return;
        }
        dedupeKey = _noHakController.text.trim();
        break;

      case 'Surat Ukur':
        if (_selectedJenisSuratUkur == null ||
            _noTahunSuratUkurController.text.trim().isEmpty ||
            _selectedJenisHak == null ||
            _noHakController.text.trim().isEmpty) {
          _showError(lengkapiPesan);
          return;
        }
        final noTahun = _noTahunSuratUkurController.text.trim();
        if (!noTahun.contains('/')) {
          _showError(
            'Format No. & Tahun harus memuat garis miring (cth: 64/2023).',
          );
          return;
        }
        // Year rule only applies to GS specifically — the notes don't
        // impose the same 2000-or-later constraint on SU.
        if (_selectedJenisSuratUkur == 'GS') {
          final tahun = int.tryParse(noTahun.split('/').last.trim());
          if (tahun == null || tahun < 2000) {
            _showError(
              'Tahun GS tidak valid — harus tahun 2000 atau lebih baru.',
            );
            return;
          }
        }
        dedupeKey = _noHakController.text.trim();
        break;

      case 'Warkah':
        if (_selectedJenisWarkah == null ||
            _no208Controller.text.trim().isEmpty ||
            _tahunWarkahController.text.trim().isEmpty) {
          _showError(lengkapiPesan);
          return;
        }
        // PBT is searched per kecamatan (unlike BN/Subsi III, which are
        // searched by No. 208 alone) — so it's the one Warkah type that
        // actually needs a kecamatan on record.
        if (_selectedJenisWarkah == 'PBT' && _selectedKecamatan == null) {
          _showError('Kecamatan wajib dipilih untuk jenis Warkah PBT.');
          return;
        }
        dedupeKey = _no208Controller.text.trim();
        break;

      default:
        return;
    }

    final sudahAda = await PeminjamanService.existsActiveNoHak(
      dedupeKey,
      jenisDokumen: _selectedJenisDokumen!,
    );
    if (!mounted) return;
    if (sudahAda) {
      _showError('$dedupeKey sudah dipinjam dan belum dikembalikan.');
      return;
    }

    final isBukuTanah = _selectedJenisDokumen == 'Buku Tanah';
    final isSuratUkur = _selectedJenisDokumen == 'Surat Ukur';
    final isWarkah = _selectedJenisDokumen == 'Warkah';

    final peminjaman = Peminjaman(
      nama: _namaController.text.trim(),
      seksi: _selectedSeksi!,
      // seksi/kecamatan/kelurahan/jenisHak/noHak stay non-nullable
      // Strings on the model (so History/Return/Barcode/Home keep
      // compiling unchanged) — '-' stands in wherever a field genuinely
      // doesn't apply to the chosen document type. Kecamatan is the one
      // exception that ISN'T Buku-Tanah-only anymore: Warkah/PBT also
      // needs it (see the 'PBT' validation above), since PBT is searched
      // per kecamatan rather than by No. 208 alone like BN/Subsi III.
      kecamatan: isBukuTanah || (isWarkah && _selectedJenisWarkah == 'PBT')
          ? _selectedKecamatan!
          : '-',
      kelurahan: isBukuTanah ? _selectedKelurahan! : '-',
      jenisHak: (isBukuTanah || isSuratUkur) ? _selectedJenisHak! : '-',
      noHak: isWarkah ? '-' : _noHakController.text.trim(),
      keperluan: _keperluanController.text.trim(),
      tanggalPinjam: _tanggalPinjam,
      tanggalKembali: _tanggalKembali,
      jenisDokumen: _selectedJenisDokumen!,
      jenisSuratUkur: isSuratUkur ? _selectedJenisSuratUkur : null,
      noTahunSuratUkur: isSuratUkur
          ? _noTahunSuratUkurController.text.trim()
          : null,
      // Single "No. & Tahun" input now stands for whichever of SU/GS was
      // actually picked — stored into the matching column, the other
      // stays null, instead of the old form requiring (and storing)
      // both regardless of which one the document actually was.
      su: (isSuratUkur && _selectedJenisSuratUkur == 'SU')
          ? _noTahunSuratUkurController.text.trim()
          : null,
      gs: (isSuratUkur && _selectedJenisSuratUkur == 'GS')
          ? _noTahunSuratUkurController.text.trim()
          : null,
      jenisWarkah: isWarkah ? _selectedJenisWarkah : null,
      no208: isWarkah ? _no208Controller.text.trim() : null,
      tahunWarkah: isWarkah ? _tahunWarkahController.text.trim() : null,
    );

    final Peminjaman inserted;
    try {
      inserted = await PeminjamanService.tambah(peminjaman);
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal menyimpan data: $e');
      return;
    }

    if (!mounted) return;

    // Pegawai submissions land as 'Diajukan' (pending Admin review) —
    // there's no confirmed loan yet, so no barcode to show. This used to
    // navigate straight to BarcodePage regardless of status, since the
    // previous version of this function discarded tambah()'s return
    // value entirely and never actually checked what status the row
    // came back with.
    if (inserted.isPendingApproval) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Pengajuan terkirim — menunggu persetujuan Admin. Barcode akan '
            'tersedia setelah disetujui.',
          ),
          backgroundColor: const Color(0xFFB07A00),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      _resetForm();
      Navigator.pop(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Data peminjaman berhasil disimpan.'),
        backgroundColor: _accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Simpan data buat argumen navigasi dulu sebelum form direset, karena
    // _resetForm() mengosongkan controller yang jadi sumber data ini.
    final args = {
      'id': inserted.id ?? '',
      'noHak': inserted.noHak,
      'nama': inserted.nama,
      // Was missing entirely before — Warkah has no kelurahan (always
      // '-'), so its barcode card showed just "Nama · -" with no way to
      // tell which department/unit borrowed it. Now always included.
      'seksi': inserted.seksi,
      'kelurahan': inserted.kelurahan,
      'jenisHak': inserted.jenisHak,
      'jenisDokumen': inserted.jenisDokumen,
      'tanggalPinjam': _formatDate(inserted.tanggalPinjam),
      'tanggalKembali': _formatDate(inserted.tanggalKembali),
    };

    _resetForm();

    Navigator.pushNamed(context, AppRoutes.barcode, arguments: args);
  }

  void _navigateAndRefresh(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) setState(() {});
  }

  void _onDrawerNavigate(String route) {
    if (route == AppRoutes.home) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      _navigateAndRefresh(route);
    }
  }

  // ─── HEADER (gradient, rounded-bottom, matches HomePage) ───
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryGreen, _accentGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar: menu, title, avatar
              Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        'https://pbs.twimg.com/profile_images/1525051472873783296/zBL0VecH_400x400.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Arsip Pertanahan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Glass info card (mirrors homepage greeting card)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Catat peminjaman dokumen,',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Form Peminjaman',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Lengkapi data di bawah untuk mencatat\npeminjaman arsip pertanahan.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.edit_document,
                        size: 20,
                        color: _primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SECTION CARD ───
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: _accentGreen),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  // ─── FIELD LABEL ───
  Widget _label(String text, {bool isDisabled = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDisabled ? Colors.black38 : Colors.black54,
        ),
      ),
    );
  }

  // ─── JENIS DOKUMEN SELECTOR (07.08.2026) ───
  // Shown first, above every other section — the rest of the form only
  // appears once a type is picked here, since which fields are even
  // relevant depends entirely on this choice.
  static const _jenisDokumenIcons = {
    'Buku Tanah': Icons.menu_book_outlined,
    'Surat Ukur': Icons.straighten_outlined,
    'Warkah': Icons.folder_copy_outlined,
  };

  Widget _buildJenisDokumenChips() {
    return Row(
      children: _jenisDokumenOptions.map((jenis) {
        final isSelected = _selectedJenisDokumen == jenis;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: jenis == _jenisDokumenOptions.last ? 0 : 10,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _selectedJenisDokumen = jenis),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _accentGreen.withOpacity(0.10)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? _accentGreen : Colors.transparent,
                    width: 1.4,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _jenisDokumenIcons[jenis],
                      size: 22,
                      color: isSelected ? _accentGreen : Colors.black45,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      jenis == 'Warkah' ? 'Warkah\n(Persyaratan)' : jenis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected ? _accentGreen : Colors.black54,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── DETAIL OBJEK ARSIP FIELDS — beda per jenis dokumen ───
  List<Widget> _buildDetailObjekArsipFields({
    required List<String> kelurahanOptions,
    required bool kelurahanDisabled,
  }) {
    switch (_selectedJenisDokumen) {
      case 'Surat Ukur':
        return [
          _label('Jenis Surat Ukur'),
          _dropdownField(
            placeholder: 'Pilih SU atau GS',
            icon: Icons.straighten_outlined,
            items: const ['SU', 'GS'],
            value: _selectedJenisSuratUkur,
            onChanged: (v) => setState(() => _selectedJenisSuratUkur = v),
          ),
          const SizedBox(height: 16),
          // No. & Tahun's label follows whichever of SU/GS was picked —
          // and the field itself only appears once one has been, since
          // "No. & Tahun" alone (before a type is chosen) is ambiguous
          // about which of the two it's actually for.
          if (_selectedJenisSuratUkur != null) ...[
            _label('No. & Tahun $_selectedJenisSuratUkur'),
            _textField(
              controller: _noTahunSuratUkurController,
              placeholder: 'cth: 64/2023',
              icon: Icons.numbers_outlined,
            ),
            if (_selectedJenisSuratUkur == 'GS')
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'Tahun harus 2000 atau lebih baru.',
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Jenis Hak'),
                    _dropdownField(
                      placeholder: 'Pilih Hak',
                      icon: Icons.shield_outlined,
                      items: Data.jenisHak,
                      value: _selectedJenisHak,
                      onChanged: (v) => setState(() => _selectedJenisHak = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Nomor Hak'),
                    _textField(
                      controller: _noHakController,
                      placeholder: 'cth: 12345',
                      icon: Icons.tag,
                      keyboardType: TextInputType.number,
                      compact: true,
                      hintFontSize: 11.5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ];

      case 'Warkah':
        return [
          _label('Jenis Warkah'),
          _dropdownField(
            placeholder: 'Pilih Jenis Warkah',
            icon: Icons.folder_copy_outlined,
            items: const ['BN', 'Subsi III', 'PBT'],
            value: _selectedJenisWarkah,
            onChanged: (v) => setState(() {
              _selectedJenisWarkah = v;
              // BN/Subsi III are searched by No. 208 alone — only PBT
              // needs a kecamatan on record, so clear any stale
              // selection left over from switching away from PBT.
              if (v != 'PBT') _selectedKecamatan = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_selectedJenisWarkah == 'PBT') ...[
            _label('Kecamatan'),
            _dropdownField(
              placeholder: 'Pilih Kecamatan',
              icon: Icons.location_city_outlined,
              items: Data.kecamatan,
              value: _selectedKecamatan,
              onChanged: (v) => setState(() => _selectedKecamatan = v),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('No. 208'),
                    _textField(
                      controller: _no208Controller,
                      placeholder: 'cth: 12345',
                      icon: Icons.tag,
                      compact: true,
                      hintFontSize: 11.5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Tahun'),
                    _textField(
                      controller: _tahunWarkahController,
                      placeholder: 'cth: 2020',
                      icon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                      compact: true,
                      hintFontSize: 11.5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ];

      case 'Buku Tanah':
      default:
        return [
          _label('Kecamatan'),
          _dropdownField(
            placeholder: 'Pilih Kecamatan',
            icon: Icons.location_city_outlined,
            items: Data.kecamatan,
            value: _selectedKecamatan,
            onChanged: (v) => setState(() {
              _selectedKecamatan = v;
              _selectedKelurahan = null;
            }),
          ),
          const SizedBox(height: 16),
          _label(
            kelurahanDisabled ? 'Kelurahan (Non-aktif)' : 'Kelurahan',
            isDisabled: kelurahanDisabled,
          ),
          _dropdownField(
            placeholder: _selectedKecamatan == null
                ? 'Pilih Kecamatan dahulu'
                : 'Pilih Kelurahan',
            icon: Icons.map_outlined,
            items: kelurahanOptions,
            value: _selectedKelurahan,
            onChanged: (v) => setState(() => _selectedKelurahan = v),
            isDisabled: kelurahanDisabled,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Jenis Hak'),
                    _dropdownField(
                      placeholder: 'Pilih Hak',
                      icon: Icons.shield_outlined,
                      items: Data.jenisHak,
                      value: _selectedJenisHak,
                      onChanged: (v) => setState(() => _selectedJenisHak = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Nomor Hak'),
                    _textField(
                      controller: _noHakController,
                      placeholder: 'cth: 12345',
                      icon: Icons.tag,
                      keyboardType: TextInputType.number,
                      compact: true,
                      hintFontSize: 11.5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ];
    }
  }

  // ─── TEXT FIELD ───
  // [compact] tightens the prefix-icon area and content padding, and
  // [hintFontSize] shrinks the hint text — both meant for fields that
  // sit inside a half-width Expanded/Row pair (SU, GS, Nomor Hak, No.
  // 208, Tahun), where the default 14px hint plus icon didn't leave
  // enough room for placeholders like "cth: 45/2020" to fit without
  // Flutter silently clipping them to "cth: 45/20…". Full-width
  // fields (Jenis Surat Ukur, No. & Tahun Surat Ukur, etc.) have plenty
  // of room already, so they keep the original size by not passing these.
  Widget _textField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool compact = false,
    double? hintFontSize,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(
            color: Colors.black38,
            fontSize: hintFontSize ?? 14,
          ),
          prefixIcon: Icon(
            icon,
            size: compact ? 16 : 18,
            color: Colors.black38,
          ),
          prefixIconConstraints: compact
              ? const BoxConstraints(minWidth: 34, minHeight: 0)
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 16,
            vertical: maxLines > 1 ? 16 : 14,
          ),
        ),
      ),
    );
  }

  // ─── DROPDOWN FIELD ───
  Widget _dropdownField({
    required String placeholder,
    required IconData icon,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
    bool isDisabled = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDisabled ? const Color(0xFFEEEEEE) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          hint: Row(
            children: [
              const SizedBox(width: 8),
              Icon(
                icon,
                size: 18,
                color: isDisabled ? Colors.black26 : Colors.black38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDisabled ? Colors.black26 : Colors.black38,
                  ),
                ),
              ),
            ],
          ),
          selectedItemBuilder: (ctx) => items
              .map(
                (item) => Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(icon, size: 18, color: _accentGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
          items: isDisabled
              ? null
              : items
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(
                          item,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
          onChanged: isDisabled ? null : onChanged,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDisabled ? Colors.black26 : Colors.black45,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }

  // ─── DATE FIELD ───
  Widget _dateField({required DateTime date, required bool isPinjam}) {
    return GestureDetector(
      onTap: () => _pickDate(isPinjam: isPinjam),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: Colors.black45,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _formatDate(date),
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
            const Icon(
              Icons.edit_calendar_outlined,
              size: 16,
              color: Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  // ─── BOTTOM NAV ───
  // ─── Dipakai oleh AppBottomNav. Form bukan salah satu tab (Beranda/
  // Arsip/Kembali/Profil), jadi setiap tap selalu berpindah halaman —
  // tidak ada case yang di-setState di sini. "Arsip" tetap tampil aktif
  // (index 1) selama berada di halaman Form, sama seperti sebelumnya.
  static const int _selectedNavIndex = 1;

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case 1:
        _navigateAndRefresh(AppRoutes.history);
        break;
      case 2:
        _navigateAndRefresh(AppRoutes.returnPage);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.profile);
        break;
    }
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    final kelurahanOptions = _kelurahanFor(_selectedKecamatan);
    final kelurahanDisabled =
        _selectedKecamatan == null || kelurahanOptions.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      drawer: AppDrawer(
        active: DrawerSection.peminjaman,
        onNavigate: _onDrawerNavigate,
      ),
      bottomNavigationBar: AppBottomNav(
        activeIndex: _selectedNavIndex,
        onItemSelected: _onNavTap,
      ),
      floatingActionButton: AppScanFab(
        onTap: () => _navigateAndRefresh(AppRoutes.scan),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient header, matches HomePage
            _buildHeader(),
            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Jenis Dokumen: pilihan pertama, menentukan field
                  // apa saja yang relevan di section-section berikutnya.
                  _sectionCard(
                    icon: Icons.category_outlined,
                    title: 'Jenis Dokumen',
                    children: [_buildJenisDokumenChips()],
                  ),

                  // ── Seksi 1: Identitas Peminjam
                  _sectionCard(
                    icon: Icons.person_search_outlined,
                    title: 'Identitas Peminjam',
                    children: [
                      _label('Nama Lengkap'),
                      _textField(
                        controller: _namaController,
                        placeholder: 'Masukkan nama peminjam',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 16),
                      _label('Seksi / Unit Kerja'),
                      _dropdownField(
                        placeholder: 'Pilih Seksi / Unit Kerja',
                        icon: Icons.apartment_outlined,
                        items: Data.seksi,
                        value: _selectedSeksi,
                        onChanged: (v) => setState(() => _selectedSeksi = v),
                      ),
                    ],
                  ),

                  // Section 2 (detail objek), Section 3 (keperluan &
                  // waktu), and the submit button only appear once a
                  // jenis dokumen has actually been picked — before that,
                  // showing them would mean asking for fields (Kecamatan/
                  // Kelurahan/dll) that might not even apply once the
                  // user does pick a type.
                  if (_selectedJenisDokumen != null) ...[
                    // ── Seksi 2: Detail Objek Arsip
                    _sectionCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Detail Objek Arsip',
                      children: _buildDetailObjekArsipFields(
                        kelurahanOptions: kelurahanOptions,
                        kelurahanDisabled: kelurahanDisabled,
                      ),
                    ),

                    // ── Seksi 3: Keperluan & Waktu
                    _sectionCard(
                      icon: Icons.access_time_outlined,
                      title: 'Keperluan & Waktu',
                      children: [
                        _label('Keperluan Peminjaman'),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _keperluanController,
                            maxLines: 4,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Jelaskan alasan peminjaman dokumen...',
                              hintStyle: TextStyle(
                                color: Colors.black38,
                                fontSize: 14,
                              ),
                              prefixIcon: Padding(
                                padding: EdgeInsets.only(top: 14, left: 4),
                                child: Icon(
                                  Icons.description_outlined,
                                  size: 18,
                                  color: Colors.black38,
                                ),
                              ),
                              prefixIconConstraints: BoxConstraints(
                                minWidth: 44,
                                minHeight: 0,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _label('Tanggal Mulai'),
                        _dateField(date: _tanggalPinjam, isPinjam: true),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            'Ketuk untuk memilih tanggal mulai peminjaman.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black38,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _label('Tanggal Pengembalian'),
                        _dateField(date: _tanggalKembali, isPinjam: false),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            'Tidak bisa lebih awal dari Tanggal Mulai.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black38,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ── Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _simpanPeminjaman,
                        icon: const Icon(
                          Icons.save_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Simpan Data',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentPurple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ], // end if (_selectedJenisDokumen != null)
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Batalkan',
                        style: TextStyle(fontSize: 14, color: Colors.black45),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
