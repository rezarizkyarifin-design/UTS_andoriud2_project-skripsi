import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../screens/services/auth_service.dart';
import 'notification_bell.dart';

/// Top bar row (hamburger menu, logo, page title, notification bell,
/// avatar) used inside the gradient header of every main page — Home,
/// History, Return, dst.
///
/// This used to be copy-pasted into each page's own
/// `_showProfileMenu()`. That's how history_page.dart and
/// return_page.dart ended up with a stale copy: logout fired
/// immediately with no confirmation (history_page's copy didn't even
/// call AuthService.logout(), so the session was never actually
/// cleared), and "Profil Saya" just showed a SnackBar instead of
/// opening ProfilePage. Only home_page.dart's copy had been kept up to
/// date. Centralizing the logic here means a fix only has to happen
/// once, and every page that uses this widget gets it automatically.
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, required this.title});

  /// Page title shown next to the logo (e.g. 'Riwayat Peminjaman').
  final String title;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Kamu perlu login lagi untuk mengakses SIAP setelah keluar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.onboarding,
      (route) => false,
    );
  }

  void _showProfileMenu(BuildContext context, TapDownDetails details) async {
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
    if (!context.mounted) return;
    if (selected == 'logout') {
      await _confirmLogout(context);
    } else if (selected == 'profile') {
      Navigator.pushNamed(context, AppRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        const NotificationBell(),
        GestureDetector(
          onTapDown: (details) => _showProfileMenu(context, details),
          child: const CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }
}
