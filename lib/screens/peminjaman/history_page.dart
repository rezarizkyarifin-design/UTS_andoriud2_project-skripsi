import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../models/peminjaman.dart';
import '../../services/peminjaman_service.dart';
import '../../data/data.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_scan_fab.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/back_to_home.dart';

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

  bool _isLoading = true;

  // Item #6: drives the collapsing header/search-bar behavior on scroll.
  bool _showHeader = true;
  String? _loadError;

  static const Color _primaryGreen = Color(0xFF1B4332);
  static const Color _accentGreen = Color(0xFF2D6A4F);
  static const Color _overdueRed = Color(0xFFC0392B);

  @override
  void initState() {
    super.initState();
    // Show whatever's cached immediately so the page isn't blank while
    // the network refresh below is in flight.
    _history = PeminjamanService.getAll();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
    _loadFromSupabase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    // Guard: a caller like _navigateAndRefresh awaits a pushed page that
    // could end in a logout (stack wiped via pushNamedAndRemoveUntil to
    // Login), which disposes this page before the await resolves.
    if (!mounted) return;
    setState(() {
      _history = PeminjamanService.getAll();
    });
  }

  // Pulls fresh data from Supabase (not just the local cache) and tracks
  // loading/error state — used on first open. Newly-added or externally
  // updated loans used to not show up here until a full logout/login
  // because this page only ever re-read the cache.
  Future<void> _loadFromSupabase() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await PeminjamanService.refresh();
      if (!mounted) return;
      setState(() {
        _history = PeminjamanService.getAll();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _history = PeminjamanService.getAll();
        _isLoading = false;
        _loadError = 'Gagal memuat data terbaru: $e';
      });
    }
  }

  // ─── PULL-TO-REFRESH: same as _loadFromSupabase but without touching
  // the full-page loading spinner (RefreshIndicator shows its own).
  Future<void> _onPullRefresh() async {
    try {
      await PeminjamanService.refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data terbaru: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _loadError = null);
    _refresh();
  }

  void _navigateAndRefresh(String route) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.pushNamed(context, route);
    _refresh();
  }

  // ─── Item 1: notif badge count/dropdown now lives entirely in
  // NotificationBell (lib/widgets/notification_bell.dart) — it reads
  // PeminjamanService/AuthService directly, so this page doesn't need
  // its own copy of this logic anymore.

  bool get _isFiltering =>
      _filterKecamatan != null ||
      _filterKelurahan != null ||
      _filterJenisHak != null ||
      _filterStatus != 'Semua';

  // ─── ROBUST KELURAHAN LOOKUP (matches FormPage) ───
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
      FocusManager.instance.primaryFocus?.unfocus();
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
                  const NotificationBell(),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDisabled ? Colors.black26 : Colors.black38,
                      ),
                    ),
                    selectedItemBuilder: (ctx) => items
                        .map(
                          (item) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
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
                    items: Data.kecamatan,
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
                    items: Data.jenisHak,
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
                if (p.returnedByMessage != null)
                  row(
                    Icons.verified_user_outlined,
                    'Diproses Oleh',
                    p.kembaliOlehNama!,
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
                            'jenisHak': p.jenisHak,
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
                  // ── Item #1: pegawai adalah read-only, jadi tombol proses
                  // kembali hanya untuk admin.
                  if (AuthService.isAdmin) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          bool ok = false;
                          String? errorMsg;
                          try {
                            ok = await PeminjamanService.kembalikan(p.noHak);
                          } catch (e) {
                            errorMsg = e.toString();
                          }
                          if (!mounted) return;
                          Navigator.pop(context);
                          if (ok) _refresh();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Dokumen berhasil ditandai kembali.'
                                    : 'Gagal menandai kembali'
                                          '${errorMsg != null ? ': $errorMsg' : ' (data tidak ditemukan / akses ditolak).'}',
                              ),
                              backgroundColor: ok
                                  ? _accentGreen
                                  : Colors.red.shade400,
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
                // ── Item #1: Edit / Hapus — admin only, any status. This is
                // the Update/Delete half of admin-only CRUD (Create lives in
                // FormPage, the "Tandai Telah Kembali" above is the other
                // Update path).
                if (AuthService.isAdmin) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _editPeminjaman(p);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primaryGreen,
                            side: const BorderSide(color: _primaryGreen),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _hapusPeminjaman(p);
                          },
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red.shade400,
                          ),
                          label: Text(
                            'Hapus',
                            style: TextStyle(color: Colors.red.shade400),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade200),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── EDIT (admin only) ───
  // Covers every field PeminjamanService.editPeminjaman() actually writes
  // to Supabase (nama, seksi, kecamatan, kelurahan, jenisHak, noHak,
  // keperluan, tanggalPinjam, tanggalKembali) — previously this dialog
  // only exposed 3 of them, so most corrections needed a delete+recreate.
  void _editPeminjaman(Peminjaman p) {
    final namaController = TextEditingController(text: p.nama);
    final noHakController = TextEditingController(text: p.noHak);
    final keperluanController = TextEditingController(text: p.keperluan);

    String? seksi = p.seksi;
    String? kecamatan = p.kecamatan;
    String? kelurahan = p.kelurahan;
    String? jenisHak = p.jenisHak;
    DateTime tanggalPinjam = p.tanggalPinjam;
    DateTime tanggalKembali = p.tanggalKembali;

    List<String> kelurahanFor(String? kec) {
      if (kec == null) return const [];
      final direct = Data.kelurahan[kec];
      if (direct != null && direct.isNotEmpty) return direct;
      final normalized = kec.trim().toLowerCase();
      for (final entry in Data.kelurahan.entries) {
        if (entry.key.trim().toLowerCase() == normalized) return entry.value;
      }
      return const [];
    }

    String fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final kelurahanOptions = kelurahanFor(kecamatan);
          final kelurahanValue = kelurahanOptions.contains(kelurahan)
              ? kelurahan
              : null;

          Future<void> pickDate({required bool isPinjam}) async {
            final picked = await showDatePicker(
              context: sheetContext,
              initialDate: isPinjam
                  ? tanggalPinjam
                  : (tanggalKembali.isBefore(tanggalPinjam)
                        ? tanggalPinjam
                        : tanggalKembali),
              firstDate: isPinjam ? DateTime(2020) : tanggalPinjam,
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
            if (picked == null) return;
            setSheetState(() {
              if (isPinjam) {
                tanggalPinjam = picked;
                if (tanggalKembali.isBefore(tanggalPinjam)) {
                  tanggalKembali = tanggalPinjam.add(const Duration(days: 7));
                }
              } else {
                tanggalKembali = picked;
              }
            });
          }

          Widget label(String text, {bool isDisabled = false}) {
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

          Widget textField({
            required TextEditingController controller,
            required String placeholder,
            required IconData icon,
            int maxLines = 1,
            TextInputType keyboardType = TextInputType.text,
          }) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(maxLines > 1 ? 20 : 30),
              ),
              child: TextField(
                controller: controller,
                maxLines: maxLines,
                keyboardType: keyboardType,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: const TextStyle(
                    color: Colors.black38,
                    fontSize: 14,
                  ),
                  prefixIcon: maxLines > 1
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14, left: 4),
                          child: Icon(icon, size: 18, color: Colors.black38),
                        )
                      : Icon(icon, size: 18, color: Colors.black38),
                  prefixIconConstraints: maxLines > 1
                      ? const BoxConstraints(minWidth: 44, minHeight: 0)
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: maxLines > 1 ? 16 : 14,
                  ),
                ),
              ),
            );
          }

          Widget dropdownField({
            required String placeholder,
            required IconData icon,
            required List<String> items,
            required String? value,
            required ValueChanged<String?> onChanged,
            bool isDisabled = false,
          }) {
            return Container(
              decoration: BoxDecoration(
                color: isDisabled
                    ? const Color(0xFFEEEEEE)
                    : const Color(0xFFF5F5F5),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
            );
          }

          Widget dateField({
            required DateTime date,
            required VoidCallback onTap,
          }) {
            return GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fmtDate(date),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
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

          Widget sectionCard({
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

          Future<void> save() async {
            if (namaController.text.trim().isEmpty ||
                noHakController.text.trim().isEmpty ||
                seksi == null ||
                kecamatan == null ||
                kelurahan == null ||
                jenisHak == null) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(
                  content: Text('Lengkapi semua kolom sebelum menyimpan.'),
                ),
              );
              return;
            }

            final updated = p.copyWith(
              nama: namaController.text.trim(),
              noHak: noHakController.text.trim(),
              seksi: seksi,
              kecamatan: kecamatan,
              kelurahan: kelurahan,
              jenisHak: jenisHak,
              keperluan: keperluanController.text.trim(),
              tanggalPinjam: tanggalPinjam,
              tanggalKembali: tanggalKembali,
            );
            bool ok = false;
            String? errorMsg;
            try {
              ok = await PeminjamanService.editPeminjaman(updated);
            } catch (e) {
              errorMsg = e.toString();
            }
            if (!mounted) return;
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.pop(sheetContext);
            if (ok) _refresh();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? 'Data peminjaman berhasil diperbarui.'
                      : errorMsg ?? 'Gagal memperbarui data.',
                ),
                backgroundColor: ok ? _accentGreen : Colors.red.shade400,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F8F7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    // ── Header — gradient, matches FormPage's header style
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryGreen, _accentGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.edit_document,
                                  size: 20,
                                  color: _primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Edit Peminjaman',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'No. Hak: ${p.noHak}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  Navigator.pop(sheetContext);
                                },
                                child: const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white24,
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Body — same 3-section layout as FormPage
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionCard(
                              icon: Icons.person_search_outlined,
                              title: 'Identitas Peminjam',
                              children: [
                                label('Nama Lengkap'),
                                textField(
                                  controller: namaController,
                                  placeholder: 'Masukkan nama peminjam',
                                  icon: Icons.badge_outlined,
                                ),
                                const SizedBox(height: 16),
                                label('Seksi / Unit Kerja'),
                                dropdownField(
                                  placeholder: 'Pilih Seksi / Unit Kerja',
                                  icon: Icons.apartment_outlined,
                                  items: Data.seksi,
                                  value: seksi,
                                  onChanged: (v) =>
                                      setSheetState(() => seksi = v),
                                ),
                              ],
                            ),
                            sectionCard(
                              icon: Icons.inventory_2_outlined,
                              title: 'Detail Objek Arsip',
                              children: [
                                label('Kecamatan'),
                                dropdownField(
                                  placeholder: 'Pilih Kecamatan',
                                  icon: Icons.location_city_outlined,
                                  items: Data.kecamatan,
                                  value: kecamatan,
                                  onChanged: (v) => setSheetState(() {
                                    kecamatan = v;
                                    kelurahan = null;
                                  }),
                                ),
                                const SizedBox(height: 16),
                                label(
                                  kelurahanOptions.isEmpty
                                      ? 'Kelurahan (Non-aktif)'
                                      : 'Kelurahan',
                                  isDisabled: kelurahanOptions.isEmpty,
                                ),
                                dropdownField(
                                  placeholder: kecamatan == null
                                      ? 'Pilih Kecamatan dahulu'
                                      : 'Pilih Kelurahan',
                                  icon: Icons.map_outlined,
                                  items: kelurahanOptions,
                                  value: kelurahanValue,
                                  isDisabled: kelurahanOptions.isEmpty,
                                  onChanged: (v) =>
                                      setSheetState(() => kelurahan = v),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          label('Jenis Hak'),
                                          dropdownField(
                                            placeholder: 'Pilih Hak',
                                            icon: Icons.shield_outlined,
                                            items: Data.jenisHak,
                                            value: jenisHak,
                                            onChanged: (v) => setSheetState(
                                              () => jenisHak = v,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          label('Nomor Hak'),
                                          textField(
                                            controller: noHakController,
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
                            sectionCard(
                              icon: Icons.access_time_outlined,
                              title: 'Keperluan & Waktu',
                              children: [
                                label('Keperluan Peminjaman'),
                                textField(
                                  controller: keperluanController,
                                  placeholder:
                                      'Jelaskan alasan peminjaman dokumen...',
                                  icon: Icons.description_outlined,
                                  maxLines: 4,
                                ),
                                const SizedBox(height: 16),
                                label('Tanggal Mulai'),
                                dateField(
                                  date: tanggalPinjam,
                                  onTap: () => pickDate(isPinjam: true),
                                ),
                                const SizedBox(height: 4),
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Text(
                                    'Ketuk untuk mengubah tanggal mulai peminjaman.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.black38,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                label('Tanggal Pengembalian'),
                                dateField(
                                  date: tanggalKembali,
                                  onTap: () => pickDate(isPinjam: false),
                                ),
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
                          ],
                        ),
                      ),
                    ),

                    // ── Bottom action bar — pinned, respects the keyboard
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        14,
                        16,
                        MediaQuery.of(sheetContext).viewInsets.bottom > 0
                            ? 14
                            : 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.pop(sheetContext);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                side: const BorderSide(color: Colors.black26),
                              ),
                              child: const Text(
                                'Batal',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: save,
                              icon: const Icon(
                                Icons.save_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Simpan Perubahan',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentGreen,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ).then((_) {
      // Dipanggil di setiap jalur keluar (Batal, Simpan, tombol close, atau
      // swipe-down) supaya controller tidak bocor.
      namaController.dispose();
      noHakController.dispose();
      keperluanController.dispose();
    });
  }

  // ─── HAPUS (admin only) ───
  void _hapusPeminjaman(Peminjaman p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Hapus Data Peminjaman'),
        content: Text(
          'Hapus permanen data peminjaman No. Hak ${p.noHak} atas nama '
          '${p.nama}? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (p.id == null) {
                Navigator.pop(context);
                return;
              }
              bool ok = false;
              String? errorMsg;
              try {
                ok = await PeminjamanService.hapus(p.id!);
              } catch (e) {
                errorMsg = e.toString();
              }
              if (!mounted) return;
              Navigator.pop(context);
              if (ok) _refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Data peminjaman berhasil dihapus.'
                        : errorMsg ?? 'Gagal menghapus data.',
                  ),
                  backgroundColor: ok ? _accentGreen : Colors.red.shade400,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFD8F3DC),
                              child: Text(
                                _initials(peminjaman.nama),
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
                                    peminjaman.nama,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                    Text(
                                      peminjaman.jenisHak,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black38,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${peminjaman.noHak}/${peminjaman.kelurahan}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _relativeTime(peminjaman.tanggalPinjam),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black38,
                            ),
                          ),
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
                        // ── Atribusi "Proses Kembali" — hanya tampil untuk
                        // dokumen yang sudah kembali dan punya pencatatan
                        // siapa yang memprosesnya (baris lama sebelum kolom
                        // ini ada tidak akan menampilkan apa-apa di sini).
                        if (peminjaman.returnedByMessage != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_user_outlined,
                                size: 13,
                                color: Colors.black38,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  peminjaman.returnedByMessage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.black38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
    FocusManager.instance.primaryFocus?.unfocus();
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
        Navigator.pushNamed(context, AppRoutes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredHistory;

    return BackToHome(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F5),
        drawer: AppDrawer(
          active: DrawerSection.daftarPeminjaman,
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
        body: Column(
          children: [
            // Item #6: collapses (slides up) on scroll-down, reappears on
            // scroll-up — see the NotificationListener around the list
            // below that drives _showHeader.
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                heightFactor: _showHeader ? 1.0 : 0.0,
                child: Stack(
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
              ),
            ),
            const SizedBox(height: 36),
            if (_isFiltering)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_alt,
                      size: 14,
                      color: Colors.black45,
                    ),
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
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE2E1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: _overdueRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loadError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _overdueRed,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _loadFromSupabase,
                        child: const Text(
                          'Coba lagi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _overdueRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: NotificationListener<UserScrollNotification>(
                onNotification: (notification) {
                  if (notification.direction == ScrollDirection.reverse &&
                      _showHeader) {
                    setState(() => _showHeader = false);
                  } else if (notification.direction ==
                          ScrollDirection.forward &&
                      !_showHeader) {
                    setState(() => _showHeader = true);
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: _onPullRefresh,
                  color: _accentGreen,
                  child: _isLoading && _history.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.55,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ],
                        )
                      : filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.55,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 36,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 92,
                                        height: 92,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFD8F3DC),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.history,
                                          size: 40,
                                          color: _accentGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        _history.isEmpty
                                            ? 'Belum Ada Riwayat Peminjaman'
                                            : 'Tidak Ada Hasil',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _history.isEmpty
                                            ? 'Setiap peminjaman dan pengembalian '
                                                  'dokumen yang tercatat akan '
                                                  'muncul di sini.'
                                            : 'Coba ubah kata kunci pencarian '
                                                  'atau filter yang sedang aktif.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black45,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      if (_history.isEmpty)
                                        OutlinedButton.icon(
                                          onPressed: () => _navigateAndRefresh(
                                            AppRoutes.form,
                                          ),
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Catat Peminjaman'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _accentGreen,
                                            side: const BorderSide(
                                              color: _accentGreen,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 22,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                          ),
                                        )
                                      else
                                        TextButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            _resetFilters();
                                          },
                                          child: Text(
                                            'Hapus Pencarian & Filter',
                                            style: TextStyle(
                                              color: _accentGreen,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _item(filtered[index]),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
