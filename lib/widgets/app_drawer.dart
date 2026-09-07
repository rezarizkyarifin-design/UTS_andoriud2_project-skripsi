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
///
/// REDESIGN (visual only — API unchanged): the old version was a flat
/// solid-green header + full-width solid-green active tile, which read
/// as a harder block of color than anything else in the app (every other
/// screen uses the soft brandGradient + white cards-on-tinted-background
/// language instead of a flat fill). This version reuses that same
/// language: gradient header with a ringed avatar, active item as a
/// white pill with a colored icon chip (matching the Home quick-access
/// icons) instead of a solid block, and a real section break above
/// Logout instead of a bare Spacer.
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
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'MENU UTAMA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _item(
            context,
            icon: Icons.dashboard_rounded,
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
            icon: Icons.folder_rounded,
            label: 'Arsip',
            section: DrawerSection.archive,
            route: AppRoutes.archive,
          ),
          _item(
            context,
            icon: Icons.list_alt_rounded,
            label: 'Daftar Peminjaman',
            section: DrawerSection.daftarPeminjaman,
            route: AppRoutes.history,
          ),
          _item(
            context,
            icon: Icons.assignment_return_rounded,
            label: 'Pengembalian',
            section: DrawerSection.pengembalian,
            route: AppRoutes.returnPage,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: AppTheme.divider, height: 1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.dangerBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.dangerRed,
                  size: 18,
                ),
              ),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: AppTheme.dangerRed,
                  fontWeight: FontWeight.w600,
                ),
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

  // ── Header: gradient (same brandGradient every other screen uses)
  // instead of a flat fill, with a ringed avatar so it doesn't look like
  // a plain circle sitting on a solid color block.
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 1.5),
                ),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Petugas Arsip',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kantor Pertanahan Cilegon',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // ── Nav item: active state is now a white pill + soft shadow with a
  // colored icon chip (mirrors the Home quick-access icon treatment)
  // instead of a full-width solid-green block, so it reads as "selected
  // card" rather than a hard color cutout.
  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required DrawerSection section,
    required String route,
  }) {
    final isActive = section == active;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isActive
              ? () => Navigator.pop(context)
              : () => _go(context, route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.accentGreen.withValues(alpha: 0.14)
                        : AppTheme.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isActive ? AppTheme.primaryGreen : Colors.black45,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? AppTheme.primaryGreen : Colors.black87,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentGreen,
                      shape: BoxShape.circle,
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
