import 'package:flutter/material.dart';
import '../../models/peminjaman.dart';
import '../../services/peminjaman_service.dart';
import '../../data.dart';

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
    final picked = await showDatePicker(
      context: context,
      initialDate: isPinjam ? _tanggalPinjam : _tanggalKembali,
      firstDate: DateTime(2020),
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
          if (_tanggalKembali.isBefore(picked)) {
            _tanggalKembali = picked.add(const Duration(days: 7));
          }
        } else {
          _tanggalKembali = picked;
        }
      });
    }
  }

  // ─── SAVE ───
  void _simpanPeminjaman() {
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

    final peminjaman = Peminjaman(
      nama: _namaController.text.trim(),
      seksi: _selectedSeksi!,
      kecamatan: _selectedKecamatan!,
      kelurahan: _selectedKelurahan!,
      jenisHak: _selectedJenisHak!,
      noHak: _noHakController.text.trim(),
      keperluan: _keperluanController.text.trim(),
      tanggalPinjam: _tanggalPinjam,
      tanggalKembali: _tanggalKembali,
    );

    PeminjamanService.tambah(peminjaman);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Data peminjaman berhasil disimpan.'),
        backgroundColor: _accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Navigator.pushNamed(
      context,
      '/barcode',
      arguments: {'noHak': peminjaman.noHak},
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
              Text(
                placeholder,
                style: TextStyle(
                  fontSize: 14,
                  color: isDisabled ? Colors.black26 : Colors.black38,
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
                    Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
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
                        child: Text(item, style: const TextStyle(fontSize: 14)),
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
  Widget _dateField({
    required DateTime date,
    required bool isPinjam,
    required bool isDisabled,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : () => _pickDate(isPinjam: isPinjam),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDisabled ? const Color(0xFFEEEEEE) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: isDisabled ? Colors.black26 : Colors.black45,
            ),
            const SizedBox(width: 10),
            Text(
              isDisabled ? 'mm/dd/yyyy' : _formatDate(date),
              style: TextStyle(
                fontSize: 14,
                color: isDisabled ? Colors.black26 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BOTTOM NAV ───
  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Beranda'},
      {'icon': Icons.folder_outlined, 'label': 'Arsip'},
      {'icon': Icons.history, 'label': 'Aktivitas'},
      {'icon': Icons.person_outline, 'label': 'Profil'},
    ];
    const selectedIndex = 1; // Arsip aktif di halaman ini

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = selectedIndex == index;
              return GestureDetector(
                onTap: index == 0
                    ? () => Navigator.pushReplacementNamed(context, '/home')
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[index]['icon'] as IconData,
                      color: isSelected ? _primaryGreen : Colors.black38,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[index]['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? _primaryGreen : Colors.black38,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 6 : 0,
                      height: isSelected ? 6 : 0,
                      decoration: BoxDecoration(
                        color: _primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    final kelurahanOptions = _selectedKecamatan != null
        ? DummyData.kelurahan[_selectedKecamatan] ?? const <String>[]
        : const <String>[];
    final kelurahanDisabled =
        _selectedKecamatan == null || kelurahanOptions.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {},
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _primaryGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.archive, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Arsip Pertanahan',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.black54,
            ),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFD8F3DC),
              child: const Icon(
                Icons.person,
                color: Color(0xFF1B4332),
                size: 18,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header
            const Text(
              'Form Peminjaman',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lengkapi data untuk mencatat peminjaman dokumen arsip pertanahan.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

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
                  placeholder: 'Contoh: Infrastruktur',
                  icon: Icons.apartment_outlined,
                  items: DummyData.seksi,
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
                  items: DummyData.kecamatan,
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
                  placeholder: 'Pilih Kecamatan dahulu',
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
                            items: DummyData.jenisHak,
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
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    decoration: const InputDecoration(
                      hintText: 'Jelaskan alasan peminjaman dokumen...',
                      hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
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
                _dateField(
                  date: _tanggalPinjam,
                  isPinjam: true,
                  isDisabled: false,
                ),
                const SizedBox(height: 16),
                _label('Tanggal Pengembalian'),
                _dateField(
                  date: _tanggalKembali,
                  isPinjam: false,
                  isDisabled: false,
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
    );
  }
}
