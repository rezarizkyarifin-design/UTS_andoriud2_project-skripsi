import 'package:flutter/material.dart';
import '../../models/peminjaman.dart';
import '../../services/peminjaman_service.dart';
import '../../data.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class ReturnPage extends StatefulWidget {
  const ReturnPage({super.key});

  @override
  State<ReturnPage> createState() => _ReturnPageState();
}

class _ReturnPageState extends State<ReturnPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  String? _filterKecamatan;
  String? _filterKelurahan;
  String? _filterJenisHak;

  late List<Peminjaman> _all;
  int _selectedNavIndex = 2;

  static const Color _primaryGreen = Color(0xFF1B4332);
  static const Color _accentGreen = Color(0xFF2D6A4F);
  static const Color _overdueRed = Color(0xFFC0392B);

  @override
  void initState() {
    super.initState();
    _all = PeminjamanService.getAll();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() => _all = PeminjamanService.getAll());
  }

  void _navigateAndRefresh(String route) async {
    await Navigator.pushNamed(context, route);
    _refresh();
  }

  bool get _isFiltering =>
      _filterKecamatan != null ||
      _filterKelurahan != null ||
      _filterJenisHak != null;

  List<String> _kelurahanFor(String? kecamatan) {
    if (kecamatan == null) return const [];
    final direct = DummyData.kelurahan[kecamatan];
    if (direct != null && direct.isNotEmpty) return direct;
    final normalized = kecamatan.trim().toLowerCase();
    for (final entry in DummyData.kelurahan.entries) {
      if (entry.key.trim().toLowerCase() == normalized) {
        return entry.value;
      }
    }
    return const [];
  }

  List<Peminjaman> get _pinjamanAktifRaw =>
      _all.where((p) => p.status == 'Dipinjam').toList();

  List<Peminjaman> get _pinjamanAktif {
    return _pinjamanAktifRaw.where((p) {
      if (_searchQuery.isNotEmpty) {
        final haystack = '${p.nama} ${p.noHak} ${p.kelurahan}'.toLowerCase();
        if (!haystack.contains(_searchQuery)) return false;
      }
      if (_filterKecamatan != null && p.kecamatan != _filterKecamatan) {
        return false;
      }
      if (_filterKelurahan != null && p.kelurahan != _filterKelurahan) {
        return false;
      }
      if (_filterJenisHak != null && p.jenisHak != _filterJenisHak) {
        return false;
      }
      return true;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _filterKecamatan = null;
      _filterKelurahan = null;
      _filterJenisHak = null;
    });
  }

  String _initials(String nama) {
    final parts = nama.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  // ─── PROSES KEMBALI ───
  void _konfirmasiKembalikan(Peminjaman p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Konfirmasi Pengembalian'),
        content: Text(
          'Tandai dokumen ${p.noHak} atas nama ${p.nama} sebagai telah dikembalikan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              PeminjamanService.kembalikan(p.noHak);
              Navigator.pop(context);
              _refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Dokumen berhasil dikembalikan.'),
                  backgroundColor: _accentGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Ya, Kembalikan'),
          ),
        ],
      ),
    );
  }

  // ─── AJUKAN PERPANJANGAN WAKTU (dengan konfirmasi + alasan) ───
  // Item 4: Pegawai tidak lagi memperpanjang langsung — pengajuan masuk
  // antrean (PeminjamanService.ajukanPerpanjangan) dan menunggu keputusan
  // Admin lewat banner/notifikasi perpanjangan di HomePage.
  Future<void> _perpanjangWaktu(Peminjaman p) async {
    if (p.isExtensionPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sudah ada pengajuan perpanjangan yang menunggu persetujuan Admin.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(2030),
      helpText: 'Pilih tanggal pengembalian baru',
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
    if (picked == null || !mounted) return;

    final alasanController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Ajukan Perpanjangan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajukan perpanjangan batas waktu peminjaman ${p.noHak} atas nama '
              '${p.nama} menjadi ${picked.day.toString().padLeft(2, '0')}/'
              '${picked.month.toString().padLeft(2, '0')}/${picked.year}?',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: alasanController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Alasan perpanjangan',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pengajuan ini akan masuk antrean dan menunggu persetujuan Admin.',
              style: TextStyle(fontSize: 11.5, color: Colors.black45),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Ajukan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = PeminjamanService.ajukanPerpanjangan(
      p.noHak,
      picked,
      alasanController.text.trim(),
    );
    _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Pengajuan perpanjangan terkirim, menunggu persetujuan Admin.'
              : 'Gagal mengajukan perpanjangan. Coba lagi.',
        ),
        backgroundColor: ok ? _accentGreen : Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showDetail(Peminjaman p) {
    Widget row(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: _accentGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFD8F3DC),
                      child: Text(
                        _initials(p.nama),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nama,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            p.seksi,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: p.isOverdue
                            ? const Color(0xFFFDE2E1)
                            : const Color(0xFFFFF3D9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        p.isOverdue
                            ? 'Terlambat ${p.hariTerlambat} hari'
                            : 'Sedang Dipinjam',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.isOverdue
                              ? _overdueRed
                              : const Color(0xFFB07A00),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 18),
                row(Icons.location_city_outlined, 'Kecamatan', p.kecamatan),
                row(Icons.map_outlined, 'Kelurahan', p.kelurahan),
                row(
                  Icons.shield_outlined,
                  'Jenis Hak / Nomor Hak',
                  '${p.jenisHak} - ${p.noHak}',
                ),
                row(Icons.description_outlined, 'Keperluan', p.keperluan),
                row(
                  Icons.calendar_month_outlined,
                  'Tanggal Pinjam',
                  p.tanggalPinjamFormatted,
                ),
                row(
                  Icons.event_available_outlined,
                  'Batas Pengembalian',
                  p.tanggalKembaliFormatted,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _konfirmasiKembalikan(p);
                        },
                        icon: const Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Proses Kembali',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentGreen,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    if (p.isOverdue) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: p.isExtensionPending
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _perpanjangWaktu(p);
                                },
                          icon: Icon(
                            p.isExtensionPending
                                ? Icons.hourglass_top_rounded
                                : Icons.more_time,
                            size: 18,
                          ),
                          label: Text(
                            p.isExtensionPending
                                ? 'Menunggu Persetujuan'
                                : 'Perpanjang',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.isExtensionPending
                                ? Colors.black45
                                : _overdueRed,
                            side: BorderSide(
                              color: p.isExtensionPending
                                  ? Colors.black26
                                  : _overdueRed,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProfileMenu(TapDownDetails details) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: const [
        PopupMenuItem(value: 'profile', child: Text('Profil Saya')),
        PopupMenuItem(value: 'logout', child: Text('Logout')),
      ],
    );
    if (!mounted) return;
    if (selected == 'logout') {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } else if (selected == 'profile') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Petugas Arsip - Kantor Pertanahan Cilegon'),
        ),
      );
    }
  }

  // ─── Dipakai oleh AppDrawer: Dashboard pakai pushReplacement, sisanya
  // push + refresh saat kembali (sama seperti HomePage).
  void _onDrawerNavigate(String route) {
    if (route == AppRoutes.home) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      _navigateAndRefresh(route);
    }
  }

  // ─── HEADER (gradient, rounded-bottom, matches HomePage) ───
  Widget _buildHeader() {
    final aktif = _pinjamanAktifRaw;
    final overdueCount = aktif.where((p) => p.isOverdue).length;
    final tepatWaktu = aktif.length - overdueCount;

    Widget stat(
      IconData icon,
      String value,
      String label, {
      Color? valueColor,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: Colors.white70),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      'Pengembalian',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            overdueCount > 0
                                ? '$overdueCount dokumen sudah lewat batas waktu!'
                                : '${aktif.length} dokumen sedang dipinjam.',
                          ),
                        ),
                      );
                    },
                    tooltip: 'Notifikasi',
                  ),
                  GestureDetector(
                    onTapDown: _showProfileMenu,
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  stat(
                    Icons.sync_alt_rounded,
                    '${aktif.length}',
                    'Pinjaman\nAktif',
                  ),
                  const SizedBox(width: 10),
                  stat(
                    Icons.check_circle_outline,
                    '$tepatWaktu',
                    'Tepat\nWaktu',
                  ),
                  const SizedBox(width: 10),
                  stat(
                    Icons.warning_amber_rounded,
                    '$overdueCount',
                    'Sudah\nTerlambat',
                    valueColor: overdueCount > 0
                        ? const Color(0xFFFFB4AC)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FLOATING SEARCH + FILTER BAR ───
  Widget _buildFloatingSearchBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Masukkan Nomor Hak...',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 13.5),
                prefixIcon: Icon(Icons.search, color: Colors.black38, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          GestureDetector(
            onTap: _openFilterSheet,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _isFiltering ? _accentGreen : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      Icons.tune_rounded,
                      size: 19,
                      color: _isFiltering ? Colors.white : _accentGreen,
                    ),
                  ),
                  if (_isFiltering)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFilterSheet() {
    String? tempKecamatan = _filterKecamatan;
    String? tempKelurahan = _filterKelurahan;
    String? tempJenisHak = _filterJenisHak;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final kelurahanOptions = _kelurahanFor(tempKecamatan);

            Widget dropdown({
              required String placeholder,
              required List<String> items,
              required String? value,
              required ValueChanged<String?> onChanged,
              bool isDisabled = false,
            }) {
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? const Color(0xFFEEEEEE)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: items.contains(value) ? value : null,
                    isExpanded: true,
                    hint: Text(
                      placeholder,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDisabled ? Colors.black26 : Colors.black38,
                      ),
                    ),
                    items: isDisabled
                        ? null
                        : items
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(
                                    item,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              )
                              .toList(),
                    onChanged: isDisabled ? null : onChanged,
                  ),
                ),
              );
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Pengembalian',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempKecamatan = null;
                            tempKelurahan = null;
                            tempJenisHak = null;
                          });
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kecamatan',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  dropdown(
                    placeholder: 'Semua Kecamatan',
                    items: DummyData.kecamatan,
                    value: tempKecamatan,
                    onChanged: (v) => setSheetState(() {
                      tempKecamatan = v;
                      tempKelurahan = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Kelurahan',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  dropdown(
                    placeholder: tempKecamatan == null
                        ? 'Pilih Kecamatan dahulu'
                        : 'Semua Kelurahan',
                    items: kelurahanOptions,
                    value: tempKelurahan,
                    isDisabled: tempKecamatan == null,
                    onChanged: (v) => setSheetState(() => tempKelurahan = v),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Jenis Hak',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  dropdown(
                    placeholder: 'Semua Jenis Hak',
                    items: DummyData.jenisHak,
                    value: tempJenisHak,
                    onChanged: (v) => setSheetState(() => tempJenisHak = v),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterKecamatan = tempKecamatan;
                          _filterKelurahan = tempKelurahan;
                          _filterJenisHak = tempJenisHak;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGreen,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Terapkan Filter',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── CARD ITEM ───
  Widget _item(Peminjaman p) {
    final accent = p.isOverdue ? _overdueRed : const Color(0xFFB07A00);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetail(p),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.06),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(18),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFD8F3DC),
                              child: Text(
                                _initials(p.nama),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.nama,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    p.seksi,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: p.isOverdue
                                    ? const Color(0xFFFDE2E1)
                                    : const Color(0xFFFFF3D9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                p.isOverdue
                                    ? 'Terlambat ${p.hariTerlambat} hari'
                                    : 'Sedang Dipinjam',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'NOMOR HAK',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black38,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${p.noHak}/${p.kelurahan}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _accentGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.isOverdue ? 'BATAS WAKTU' : 'TGL PINJAM',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black38,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    p.isOverdue
                                        ? p.tanggalKembaliFormatted
                                        : p.tanggalPinjamFormatted,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: p.isOverdue
                                          ? _overdueRed
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Tombol Proses Kembali / Perpanjang
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _konfirmasiKembalikan(p),
                                icon: const Icon(
                                  Icons.assignment_turned_in_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Proses Kembali',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accentGreen,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            if (p.isOverdue) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: p.isExtensionPending
                                      ? null
                                      : () => _perpanjangWaktu(p),
                                  icon: Icon(
                                    p.isExtensionPending
                                        ? Icons.hourglass_top_rounded
                                        : Icons.more_time,
                                    size: 18,
                                  ),
                                  label: Text(
                                    p.isExtensionPending
                                        ? 'Menunggu Persetujuan'
                                        : 'Perpanjang',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: p.isExtensionPending
                                        ? Colors.black45
                                        : _overdueRed,
                                    side: BorderSide(
                                      color: p.isExtensionPending
                                          ? Colors.black26
                                          : _overdueRed,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Dipakai oleh AppBottomNav ───
  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case 1:
        _navigateAndRefresh(AppRoutes.history);
        break;
      case 2:
        setState(() => _selectedNavIndex = 2);
        break;
      case 3:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Halaman Profil belum tersedia.')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final aktif = _pinjamanAktif;
    final overdueCount = aktif.where((p) => p.isOverdue).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      drawer: AppDrawer(
        active: DrawerSection.pengembalian,
        onNavigate: _onDrawerNavigate,
      ),
      bottomNavigationBar: AppBottomNav(
        activeIndex: _selectedNavIndex,
        onItemSelected: _onNavTap,
      ),
      body: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildHeader(),
              Positioned(
                left: 20,
                right: 20,
                bottom: -24,
                child: _buildFloatingSearchBar(),
              ),
            ],
          ),
          const SizedBox(height: 36),
          if (_isFiltering)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 14, color: Colors.black45),
                  const SizedBox(width: 6),
                  const Text(
                    'Filter aktif',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _resetFilters,
                    child: Text(
                      'Hapus Filter',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _accentGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pinjaman Aktif',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8F3DC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${aktif.length} Berkas',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: aktif.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 56,
                          color: Colors.blueGrey.shade200,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _pinjamanAktifRaw.isEmpty
                              ? 'Tidak ada dokumen yang sedang dipinjam.'
                              : 'Tidak ada hasil yang cocok.',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: aktif.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _item(aktif[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
