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
  Widget _buildSectionHeader(String title, String actionLabel) {
    return Row(
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
    );
  }

  // ─── MENU ITEM ───
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => _navigateAndRefresh(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEDF4F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _accentGreen, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
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
                onTap: () => setState(() => _selectedNavIndex = index),
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
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {},
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
            _buildSectionHeader('Menu Peminjaman', 'Lihat Semua'),
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
            _buildSectionHeader('Menu Pengembalian', 'Log Harian'),
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
