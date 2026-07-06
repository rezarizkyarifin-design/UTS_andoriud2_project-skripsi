import 'package:flutter/material.dart';
import '../../models/peminjaman.dart';
import '../../services/peminjaman_service.dart';
import '../../data.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late List<Peminjaman> _history;

  final _searchController = TextEditingController();
  String _searchQuery = '';

  String? _filterKecamatan;
  String? _filterKelurahan;
  String? _filterJenisHak;
  String _filterStatus = 'Semua'; // Semua | Sedang Dipinjam | Telah Kembali

  int _selectedNavIndex = 1; // Arsip aktif di halaman ini

  static const Color _primaryGreen = Color(0xFF1B4332);
  static const Color _accentGreen = Color(0xFF2D6A4F);
  static const Color _overdueRed = Color(0xFFC0392B);

  @override
  void initState() {
    super.initState();
    _history = PeminjamanService.getAll();
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
    setState(() {
      _history = PeminjamanService.getAll();
    });
  }

  void _navigateAndRefresh(String route) async {
    await Navigator.pushNamed(context, route);
    _refresh();
  }

  // ─── Item 1: sama seperti HomePage — badge bell mengikuti role.
  int _notifCount() {
    if (AuthService.isAdmin) {
      return PeminjamanService.getPengajuanPerpanjangan().length;
    }
    return PeminjamanService.getBelumKembaliBrp();
  }

  bool get _isFiltering =>
      _filterKecamatan != null ||
      _filterKelurahan != null ||
      _filterJenisHak != null ||
      _filterStatus != 'Semua';

  // ─── ROBUST KELURAHAN LOOKUP (matches FormPage) ───
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

  // ─── FILTERED LIST ───
  List<Peminjaman> get _filteredHistory {
    return _history.where((p) {
      if (_searchQuery.isNotEmpty) {
        final haystack = '${p.nama} ${p.kecamatan} ${p.kelurahan} ${p.noHak}'
            .toLowerCase();
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
      if (_filterStatus == 'Sedang Dipinjam' && p.status != 'Dipinjam') {
        return false;
      }
      if (_filterStatus == 'Telah Kembali' && p.status == 'Dipinjam') {
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
      _filterStatus = 'Semua';
    });
  }

  // ─── HELPERS ───
  String _initials(String nama) {
    final parts = nama.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return 'Dipinjam ${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return 'Dipinjam ${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Dipinjam kemarin';
    if (diff.inDays < 7) return 'Dipinjam ${diff.inDays} hari lalu';
    return 'Dipinjam ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _statusColor(Peminjaman p) {
    if (p.status == 'Dipinjam' && p.isOverdue) return _overdueRed;
    return p.status == 'Dipinjam' ? const Color(0xFFB07A00) : _accentGreen;
  }

  Color _statusBg(Peminjaman p) {
    if (p.status == 'Dipinjam' && p.isOverdue) return const Color(0xFFFDE2E1);
    return p.status == 'Dipinjam'
        ? const Color(0xFFFFF3D9)
        : const Color(0xFFD8F3DC);
  }

  String _statusLabel(Peminjaman p) {
    if (p.status == 'Dipinjam' && p.isOverdue) return 'Terlambat';
    return p.status == 'Dipinjam' ? 'Dipinjam' : 'Kembali';
  }

  // ─── NOTIFICATIONS (bottom sheet, mirrors HomePage) ───
  void _showNotifications() {
    final aktif = PeminjamanService.getSedangDipinjam();
    final kembali = PeminjamanService.getTelahKembali();
    final terlambat = _history.where((p) => p.isOverdue).length;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
              const Text(
                'Notifikasi',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (AuthService.isAdmin &&
                  PeminjamanService.getPengajuanPerpanjangan().isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.pending_actions,
                    color: Color(0xFFB07A00),
                  ),
                  title: Text(
                    '${PeminjamanService.getPengajuanPerpanjangan().length} pengajuan perpanjangan menunggu persetujuan',
                  ),
                  subtitle: const Text(
                    'Buka Dashboard untuk meninjau dan memutuskan.',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, AppRoutes.home);
                  },
                ),
              if (terlambat > 0)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: _overdueRed,
                  ),
                  title: Text('$terlambat dokumen sudah lewat batas waktu'),
                  subtitle: const Text(
                    'Segera proses pengembalian atau perpanjangan.',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateAndRefresh(AppRoutes.returnPage);
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.sync_alt_rounded,
                  color: Colors.orange,
                ),
                title: Text('$aktif dokumen sedang dipinjam'),
                subtitle: const Text(
                  'Pantau tanggal pengembalian agar tepat waktu.',
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.inventory_2_outlined,
                  color: _accentGreen,
                ),
                title: Text('$kembali dokumen telah dikembalikan'),
                subtitle: const Text('Lihat riwayat peminjaman terbaru.'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── PROFILE MENU ───
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
    final aktif = PeminjamanService.getSedangDipinjam();
    final kembali = PeminjamanService.getTelahKembali();
    final terlambat = _history.where((p) => p.isOverdue).length;

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
                      'Daftar Peminjaman',
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
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _refresh,
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                        ),
                        if (_notifCount() > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 15,
                                minHeight: 15,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _notifCount() > 9 ? '9+' : '${_notifCount()}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: _showNotifications,
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
                    Icons.folder_copy_outlined,
                    '${_history.length}',
                    'Total\nBerkas',
                  ),
                  const SizedBox(width: 10),
                  stat(Icons.sync_alt_rounded, '$aktif', 'Sedang\nDipinjam'),
                  const SizedBox(width: 10),
                  stat(
                    Icons.inventory_2_outlined,
                    '$kembali',
                    'Telah\nKembali',
                  ),
                  const SizedBox(width: 10),
                  stat(
                    Icons.warning_amber_rounded,
                    '$terlambat',
                    'Terlambat\nKembali',
                    valueColor: terlambat > 0 ? const Color(0xFFFFB4AC) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FLOATING SEARCH + FILTER BAR (overlaps header bottom edge) ───
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
                hintText: 'Cari nama, kelurahan, atau nomor hak...',
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

  // ─── FILTER BOTTOM SHEET ───
  void _openFilterSheet() {
    String? tempKecamatan = _filterKecamatan;
    String? tempKelurahan = _filterKelurahan;
    String? tempJenisHak = _filterJenisHak;
    String tempStatus = _filterStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final kelurahanOptions = _kelurahanFor(tempKecamatan);

            Widget chip(String label, bool selected, VoidCallback onTap) {
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? _accentGreen : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              );
            }

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
                        'Filter Peminjaman',
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
                            tempStatus = 'Semua';
                          });
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Status',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      chip(
                        'Semua',
                        tempStatus == 'Semua',
                        () => setSheetState(() => tempStatus = 'Semua'),
                      ),
                      chip(
                        'Sedang Dipinjam',
                        tempStatus == 'Sedang Dipinjam',
                        () =>
                            setSheetState(() => tempStatus = 'Sedang Dipinjam'),
                      ),
                      chip(
                        'Telah Kembali',
                        tempStatus == 'Telah Kembali',
                        () => setSheetState(() => tempStatus = 'Telah Kembali'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                          _filterStatus = tempStatus;
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

  // ─── DETAIL BOTTOM SHEET ───
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
                        color: _statusBg(p),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(p),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(p),
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
                  'Tanggal Kembali',
                  p.tanggalKembaliFormatted,
                ),
                if (p.status == 'Dipinjam') ...[
                  const SizedBox(height: 4),
                  // ── Item 2: akses ulang QR/barcode selama dokumen masih
                  // dipinjam (mis. label fisik hilang/rusak, perlu cetak lagi).
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          AppRoutes.barcode,
                          arguments: {
                            'noHak': p.noHak,
                            'nama': p.nama,
                            'kelurahan': p.kelurahan,
                            'tanggalPinjam': p.tanggalPinjamFormatted,
                            'tanggalKembali': p.tanggalKembaliFormatted,
                          },
                        );
                      },
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text(
                        'Lihat Barcode',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _accentGreen,
                        side: const BorderSide(color: _accentGreen),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        PeminjamanService.kembalikan(p.noHak);
                        Navigator.pop(context);
                        _refresh();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Dokumen berhasil ditandai kembali.',
                            ),
                            backgroundColor: _accentGreen,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.assignment_turned_in_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Tandai Telah Kembali',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── CARD ITEM ───
  Widget _item(Peminjaman peminjaman) {
    final statusColor = _statusColor(peminjaman);
    final statusBg = _statusBg(peminjaman);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetail(peminjaman),
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
                    color: statusColor,
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    peminjaman.nama,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    peminjaman.keperluan,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _statusLabel(peminjaman),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
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
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 20,
                                color: _accentGreen,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Nomor Hak',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.black38,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${peminjaman.noHak}/${peminjaman.kelurahan}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFD8F3DC),
                              child: Text(
                                _initials(peminjaman.nama),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryGreen,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _relativeTime(peminjaman.tanggalPinjam),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ),
                        // ── Item 3: mulai & batas peminjaman langsung di
                        // card, tanpa perlu buka detail.
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Mulai: ${peminjaman.tanggalPinjamFormatted}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Batas: ${peminjaman.tanggalKembaliFormatted}',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      peminjaman.status == 'Dipinjam' &&
                                          peminjaman.isOverdue
                                      ? _overdueRed
                                      : Colors.black45,
                                ),
                              ),
                            ),
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

  // ─── BOTTOM NAV ───
  // ─── Dipakai oleh AppBottomNav ───
  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case 1:
        setState(() => _selectedNavIndex = 1);
        break;
      case 2:
        _navigateAndRefresh(AppRoutes.returnPage);
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
    final filtered = _filteredHistory;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      drawer: AppDrawer(
        active: DrawerSection.daftarPeminjaman,
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
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 56,
                          color: Colors.blueGrey.shade200,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _history.isEmpty
                              ? 'Belum ada data peminjaman.'
                              : 'Tidak ada hasil yang cocok.',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _item(filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
