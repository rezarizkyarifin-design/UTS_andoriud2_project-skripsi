import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/peminjaman_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedNavIndex = 0;

  static const Color _primaryGreen = Color(0xFF1B4332);
  static const Color _accentGreen = Color(0xFF2D6A4F);

  void _navigateAndRefresh(String route) async {
    await Navigator.pushNamed(context, route);
    setState(() {});
  }

  // ─── BOTTOM NAV TAP HANDLER ───
  void _onNavTap(int index) {
    switch (index) {
      case 0:
        setState(() => _selectedNavIndex = 0);
        break;
      case 1:
        _navigateAndRefresh(AppRoutes.history);
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

  // ─── NOTIFICATIONS SHEET ───
  void _showNotifications() {
    final aktif = PeminjamanService.getSedangDipinjam();
    final kembali = PeminjamanService.getTelahKembali();

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
                onTap: () {
                  Navigator.pop(context);
                  _navigateAndRefresh(AppRoutes.returnPage);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.inventory_2_outlined,
                  color: _accentGreen,
                ),
                title: Text('$kembali dokumen telah dikembalikan'),
                subtitle: const Text('Lihat riwayat peminjaman terbaru.'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateAndRefresh(AppRoutes.history);
                },
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

  // ─── DRAWER ───
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            color: _primaryGreen,
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Petugas Arsip',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kantor Pertanahan Cilegon',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _drawerItem(
            Icons.dashboard,
            'Dashboard',
            isActive: true,
            onTap: () => Navigator.pop(context),
          ),
          _drawerItem(
            Icons.edit_document,
            'Peminjaman',
            onTap: () {
              Navigator.pop(context);
              _navigateAndRefresh(AppRoutes.form);
            },
          ),
          _drawerItem(
            Icons.list_alt,
            'Daftar Peminjaman',
            onTap: () {
              Navigator.pop(context);
              _navigateAndRefresh(AppRoutes.history);
            },
          ),
          _drawerItem(
            Icons.assignment_return,
            'Pengembalian',
            onTap: () {
              Navigator.pop(context);
              _navigateAndRefresh(AppRoutes.returnPage);
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String label, {
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive ? _primaryGreen : Colors.transparent,
        leading: Icon(icon, color: isActive ? Colors.white : Colors.black54),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  // ─── HERO BANNER ───
  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _accentGreen,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selamat datang kembali,',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          SizedBox(height: 4),
          Text(
            'Halo, Admin!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Pantau dan kelola seluruh dokumentasi pertanahan dengan sistem manajemen arsip digital yang presisi.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── STAT CARD ───
  Widget _buildStatCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
              Text(subtitle, style: TextStyle(fontSize: 12, color: valueColor)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── SECTION HEADER ───
  Widget _buildSectionHeader(String title, String actionLabel, String route) {
    return GestureDetector(
      onTap: () => _navigateAndRefresh(route),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            actionLabel,
            style: TextStyle(
              fontSize: 12,
              color: _accentGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── MENU ITEM ───
  // Delegates to a small stateful card so each item can animate its own
  // pressed/hover shadow independently.
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return _MenuItemCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      accentColor: _accentGreen,
      onTap: () => _navigateAndRefresh(route),
    );
  }

  // ─── BOTTOM NAV ───
  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Beranda'},
      {'icon': Icons.folder_outlined, 'label': 'Arsip'},
      {'icon': Icons.assignment_return, 'label': 'Kembali'},
      {'icon': Icons.person_outline, 'label': 'Profil'},
    ];

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
              final isSelected = _selectedNavIndex == index;
              return GestureDetector(
                onTap: () => _onNavTap(index),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
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
            onPressed: _showNotifications,
            tooltip: 'Notifikasi',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTapDown: _showProfileMenu,
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFD8F3DC),
                child: Icon(Icons.person, color: Color(0xFF1B4332), size: 18),
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
            _buildHeroBanner(),
            const SizedBox(height: 16),
            _buildStatCard(
              icon: Icons.sync_alt_rounded,
              iconBgColor: const Color(0xFFFFF3E0),
              iconColor: Colors.orange,
              label: 'Peminjaman Aktif',
              value: PeminjamanService.getSedangDipinjam().toString(),
              subtitle: 'Sedang Dipinjam',
              valueColor: Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.inventory_2_outlined,
              iconBgColor: const Color(0xFFE8F5E9),
              iconColor: Colors.green,
              label: 'Arsip Diproses',
              value: PeminjamanService.getTelahKembali().toString(),
              subtitle: 'Telah Kembali',
              valueColor: Colors.green,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(
              'Menu Peminjaman',
              'Lihat Semua',
              AppRoutes.history,
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.edit_document,
              title: 'Form Peminjaman',
              subtitle: 'Buat permohonan peminjaman arsip baru',
              route: AppRoutes.form,
            ),
            const SizedBox(height: 10),
            _buildMenuItem(
              icon: Icons.list_alt,
              title: 'Daftar Peminjaman',
              subtitle: 'Pantau status seluruh dokumen keluar',
              route: AppRoutes.history,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(
              'Menu Pengembalian',
              'Log Harian',
              AppRoutes.returnPage,
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.assignment_return_outlined,
              title: 'Pengembalian Dokumen',
              subtitle: 'Proses verifikasi dokumen yang kembali',
              route: AppRoutes.returnPage,
            ),
            const SizedBox(height: 10),
            _buildMenuItem(
              icon: Icons.qr_code_scanner,
              title: 'Scan Dokumen',
              subtitle: 'Digitalisasi arsip fisik ke sistem cloud',
              route: AppRoutes.scan,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── ANIMATED MENU ITEM CARD ───
// Shows a growing shadow + subtle scale/border highlight while the card is
// pressed, and a lighter version of the same highlight on hover (web/desktop).
class _MenuItemCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _MenuItemCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<_MenuItemCard> {
  bool _pressed = false;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bool active = _pressed || _hovering;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFF7FBF9) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? widget.accentColor.withOpacity(0.35)
                    : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? widget.accentColor.withOpacity(0.20)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: active ? 20 : 10,
                  offset: Offset(0, active ? 8 : 3),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: active
                        ? widget.accentColor.withOpacity(0.14)
                        : const Color(0xFFEDF4F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.accentColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  transform: Matrix4.translationValues(active ? 3 : 0, 0, 0),
                  child: Icon(
                    Icons.chevron_right,
                    color: active ? widget.accentColor : Colors.black26,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
