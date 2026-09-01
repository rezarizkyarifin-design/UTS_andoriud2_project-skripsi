import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../routes/app_routes.dart';
import '../screens/services/auth_service.dart';

/// Which drawer item should render as "active" (highlighted) for the
/// current page. One enum value per screen that has a drawer entry.
enum DrawerSection {
  dashboard,
  peminjaman,
  archive,
  daftarPeminjaman,
  pengembalian,
}

/// Shared app drawer, used identically across Home/Form/History/Return.
///
/// Previously this ~110-line widget (header + 4 nav items + logout tile)
/// was copy-pasted into every page, so any tweak (wording, icon, color)
/// had to be repeated 4x. Now it lives once, and each page only tells it
/// which item is currently active + how navigation should behave.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.active, required this.onNavigate});

  /// Which item to highlight (usually the page hosting this drawer).
  final DrawerSection active;

  /// Called with the target route (e.g. [AppRoutes.form]) *after* the
  /// drawer has already been popped. Each page decides how it wants to
  /// navigate — `pushReplacementNamed` for Dashboard, `pushNamed` +
  /// refresh-on-return for everything else — so this widget stays pure UI.
  final ValueChanged<String> onNavigate;

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    onNavigate(route);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            color: AppTheme.primaryGreen,
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
          _item(
            context,
            icon: Icons.dashboard,
            label: 'Dashboard',
            section: DrawerSection.dashboard,
            route: AppRoutes.home,
          ),
          _item(
            context,
            icon: Icons.edit_document,
            label: 'Peminjaman',
            section: DrawerSection.peminjaman,
            route: AppRoutes.form,
          ),
          _item(
            context,
            icon: Icons.folder_outlined,
            label: 'Arsip',
            section: DrawerSection.archive,
            route: AppRoutes.archive,
          ),
          _item(
            context,
            icon: Icons.list_alt,
            label: 'Daftar Peminjaman',
            section: DrawerSection.daftarPeminjaman,
            route: AppRoutes.history,
          ),
          _item(
            context,
            icon: Icons.assignment_return,
            label: 'Pengembalian',
            section: DrawerSection.pengembalian,
            route: AppRoutes.returnPage,
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
              onTap: () async {
                // Sebelumnya cuma pindah ke halaman Login tanpa benar-benar
                // logout — sesi Supabase & AuthService.currentUser tetap
                // aktif di belakang layar. Ini yang dipakai di 4 halaman
                // (Home/Form/History/Return), jadi ini jalur logout utama.
                Navigator.pop(context);
                try {
                  await AuthService.logout();
                } catch (_) {
                  // Non-fatal: sesi lokal biasanya tetap terhapus walau
                  // panggilan ke server gagal — tetap lanjut ke Login.
                }
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.onboarding,
                    (route) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required DrawerSection section,
    required String route,
  }) {
    final isActive = section == active;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive ? AppTheme.primaryGreen : Colors.transparent,
        leading: Icon(icon, color: isActive ? Colors.white : Colors.black54),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: isActive
            ? () => Navigator.pop(context)
            : () => _go(context, route),
      ),
    );
  }
}
