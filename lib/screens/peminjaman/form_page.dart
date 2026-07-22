import 'package:flutter/material.dart';
import '../../models/peminjaman.dart';
import '../../services/peminjaman_service.dart';
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
    setState(() {
      _selectedSeksi = null;
      _selectedKecamatan = null;
      _selectedKelurahan = null;
      _selectedJenisHak = null;
      _tanggalPinjam = DateTime.now();
      _tanggalKembali = _tanggalPinjam.add(const Duration(days: 7));
    });
  }

  // ─── SAVE ───
  void _simpanPeminjaman() async {
    if (_namaController.text.isEmpty ||
        _selectedSeksi == null ||
        _selectedKecamatan == null ||
        _selectedKelurahan == null ||
        _selectedJenisHak == null ||
        _noHakController.text.isEmpty ||
        _keperluanController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lengkapi semua kolom sebelum menyimpan.'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final noHak = _noHakController.text.trim();

    final sudahAda = await PeminjamanService.existsActiveNoHak(noHak);
    if (!mounted) return;
    if (sudahAda) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No. Hak $noHak sudah dipinjam dan belum dikembalikan.',
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final peminjaman = Peminjaman(
      nama: _namaController.text.trim(),
      seksi: _selectedSeksi!,
      kecamatan: _selectedKecamatan!,
      kelurahan: _selectedKelurahan!,
      jenisHak: _selectedJenisHak!,
      noHak: noHak,
      keperluan: _keperluanController.text.trim(),
      tanggalPinjam: _tanggalPinjam,
      tanggalKembali: _tanggalKembali,
    );

    try {
      await PeminjamanService.tambah(peminjaman);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan data: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

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
      'noHak': peminjaman.noHak,
      'nama': peminjaman.nama,
      'kelurahan': peminjaman.kelurahan,
      'jenisHak': peminjaman.jenisHak,
      'tanggalPinjam': _formatDate(peminjaman.tanggalPinjam),
      'tanggalKembali': _formatDate(peminjaman.tanggalKembali),
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

  // ─── TEXT FIELD ───
  Widget _textField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
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
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
          prefixIcon: Icon(icon, size: 18, color: Colors.black38),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
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

                  // ── Seksi 2: Detail Objek Arsip
                  _sectionCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'Detail Objek Arsip',
                    children: [
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
                        kelurahanDisabled
                            ? 'Kelurahan (Non-aktif)'
                            : 'Kelurahan',
                        isDisabled: kelurahanDisabled,
                      ),
                      _dropdownField(
                        placeholder: _selectedKecamatan == null
                            ? 'Pilih Kecamatan dahulu'
                            : 'Pilih Kelurahan',
                        icon: Icons.map_outlined,
                        items: kelurahanOptions,
                        value: _selectedKelurahan,
                        onChanged: (v) =>
                            setState(() => _selectedKelurahan = v),
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
                                  onChanged: (v) =>
                                      setState(() => _selectedJenisHak = v),
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
                                  placeholder: 'Contoh: 12345',
                                  icon: Icons.tag,
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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
                          style: TextStyle(fontSize: 11, color: Colors.black38),
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
                          style: TextStyle(fontSize: 11, color: Colors.black38),
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
