import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_roles.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_scan_fab.dart';
import '../../widgets/back_to_home.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  bool _isLoggingOut = false;

  static const int _selectedNavIndex = 3;

  String _initials(String nama) {
    final parts = nama.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isSaving = false;
    bool hideCurrent = true;
    bool hideNew = true;
    bool hideConfirm = true;

    showDialog(
      context: context,
      // Fix: tapping outside the dialog used to dismiss it through
      // Flutter's own default barrier-tap path, which pops immediately
      // with no chance to unfocus first — the focused field's selection/
      // context-menu overlay hadn't detached yet, tripping framework.dart's
      // '_dependents.isEmpty' assertion. The Batal button already runs the
      // safe unfocus-then-delay-then-pop sequence below; barrier-tap had
      // no way to run that same sequence, so it's disabled here instead —
      // "Batal" is still there and works the same as before.
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> save() async {
            if (newCtrl.text.length < 6) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('Password baru minimal 6 karakter.'),
                ),
              );
              return;
            }
            if (newCtrl.text != confirmCtrl.text) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('Konfirmasi password baru tidak cocok.'),
                ),
              );
              return;
            }
            setDialogState(() => isSaving = true);
            final error = await AuthService.changePassword(
              currentPassword: currentCtrl.text,
              newPassword: newCtrl.text,
            );
            if (!mounted) return;
            // Toolbar sudah dimatikan lewat contextMenuBuilder di atas —
            // ini jaga-jaga tambahan untuk overlay selection handle bawaan
            // OS (mis. Android) yang tidak dikontrol contextMenuBuilder.
            FocusManager.instance.primaryFocus?.unfocus();
            await Future.delayed(const Duration(milliseconds: 50));
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error ?? 'Password berhasil diubah.'),
                backgroundColor: error == null
                    ? AppTheme.accentGreen
                    : Colors.red.shade400,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text('Ganti Password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: currentCtrl,
                    obscureText: hideCurrent,
                    // Toolbar Copy/Paste dimatikan: sumber sebenarnya dari
                    // crash '_dependents.isEmpty' — overlay toolbar-nya
                    // belum sempat lepas saat dialog di-pop. Password
                    // field juga sebaiknya memang tidak bisa di-copy.
                    contextMenuBuilder: (context, editableTextState) =>
                        const SizedBox.shrink(),
                    decoration: InputDecoration(
                      labelText: 'Password Saat Ini',
                      suffixIcon: IconButton(
                        icon: Icon(
                          hideCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setDialogState(() => hideCurrent = !hideCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newCtrl,
                    obscureText: hideNew,
                    contextMenuBuilder: (context, editableTextState) =>
                        const SizedBox.shrink(),
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      suffixIcon: IconButton(
                        icon: Icon(
                          hideNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setDialogState(() => hideNew = !hideNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: hideConfirm,
                    contextMenuBuilder: (context, editableTextState) =>
                        const SizedBox.shrink(),
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Password Baru',
                      // Item #5 fix: this used to reuse hideNew, so
                      // revealing "Password Baru" silently revealed this
                      // field too with no toggle of its own to hide it
                      // back independently. Now it has its own state and
                      // its own eye icon, matching the other two fields.
                      suffixIcon: IconButton(
                        icon: Icon(
                          hideConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setDialogState(() => hideConfirm = !hideConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  await Future.delayed(const Duration(milliseconds: 50));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Simpan',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      // Dipanggil di setiap jalur keluar dialog (Batal, Simpan, atau
      // tap di luar dialog) supaya controller tidak bocor.
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    });
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoggingOut = true);
    try {
      await AuthService.logout();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal logout dari server, sesi lokal tetap dihapus: $e',
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Session was likely cleared locally by AuthService.logout() even if
      // the network call failed — send them to onboarding regardless so
      // they're not stuck on a page for a user that's no longer considered
      // logged in.
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.onboarding,
        (route) => false,
      );
      return;
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.onboarding,
      (route) => false,
    );
  }

  void _onNavTap(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case 1:
        Navigator.pushNamed(context, AppRoutes.history);
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.returnPage);
        break;
      case 3:
        break; // sudah di Profil
    }
  }

  // ── EDIT NAMA ──────────────────────────────────────────────────
  // Replaces the old username-edit row: nama is a plain display name
  // (spaces are fine — "Naira Tahira"), unlike username which had to
  // fit into a real email address. See AuthService.updateNama — this
  // never touches Supabase Auth or the login username at all.
  Future<void> _editNama() async {
    final currentNama = AuthService.currentUser?.nama ?? '';
    final controller = TextEditingController(text: currentNama);

    Future<void> safePop(BuildContext dialogContext, [String? value]) async {
      // Same fix as the other dialogs on this page — see _editContactEmail.
      FocusManager.instance.primaryFocus?.unfocus();
      await Future.delayed(const Duration(milliseconds: 50));
      if (!dialogContext.mounted) return;
      Navigator.pop(dialogContext, value);
    }

    final result = await showDialog<String>(
      context: context,
      // Same fix as _showChangePasswordDialog above — see its comment.
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Ubah Nama'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          contextMenuBuilder: (context, editableTextState) =>
              const SizedBox.shrink(),
          decoration: const InputDecoration(
            hintText: 'Nama lengkap',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => safePop(dialogContext),
            child: const Text('Batal', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => safePop(dialogContext, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim() == currentNama) return;

    final error = await AuthService.updateNama(result.trim());
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Nama berhasil diubah.'),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── EDIT EMAIL KONTAK ──────────────────────────────────────────
  // A genuinely separate, real inbox — used only for notifications
  // (see AuthService.updateContactEmail). Completely unrelated to login;
  // changing this never touches Supabase Auth or the Username above.
  Future<void> _editContactEmail() async {
    final controller = TextEditingController(
      text: AuthService.currentUser?.contactEmail ?? '',
    );

    Future<void> safePop(BuildContext dialogContext, [String? value]) async {
      // Same fix applied across every dialog on this page — see
      // _editNama or _showChangePasswordDialog for why this matters.
      FocusManager.instance.primaryFocus?.unfocus();
      await Future.delayed(const Duration(milliseconds: 50));
      if (!dialogContext.mounted) return;
      Navigator.pop(dialogContext, value);
    }

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Email Kontak'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Email asli buat nerima notifikasi — beda dari Username yang '
              'dipakai buat login.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              contextMenuBuilder: (context, editableTextState) =>
                  const SizedBox.shrink(),
              decoration: const InputDecoration(
                hintText: 'nama@gmail.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => safePop(dialogContext),
            child: const Text('Batal', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => safePop(dialogContext, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;

    final error = await AuthService.updateContactEmail(result.trim());
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Email kontak diperbarui.'),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.accentGreen),
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
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    return BackToHome(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F5),
        bottomNavigationBar: AppBottomNav(
          activeIndex: _selectedNavIndex,
          onItemSelected: _onNavTap,
        ),
        floatingActionButton: AppScanFab(
          onTap: () => Navigator.pushNamed(context, AppRoutes.scan),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER: gradient + avatar, matches other pages' visual style
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryGreen, AppTheme.accentGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Profil Saya',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _initials(user?.nama ?? '?'),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user?.nama ?? 'Pengguna',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            user?.role.label ?? '-',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── INFO CARD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _infoRow(
                        icon: Icons.badge_outlined,
                        label: 'Nama',
                        value: user?.nama ?? '-',
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.black45,
                          ),
                          tooltip: 'Ubah nama',
                          onPressed: _editNama,
                        ),
                      ),
                      const Divider(height: 1),
                      _infoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user?.contactEmail ?? 'Belum diisi',
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.black45,
                          ),
                          tooltip: 'Ubah email kontak',
                          onPressed: _editContactEmail,
                        ),
                      ),
                      const Divider(height: 1),
                      _infoRow(
                        icon: Icons.apartment_outlined,
                        label: 'Jabatan',
                        value: user?.jabatan ?? '-',
                      ),
                      const Divider(height: 1),
                      _infoRow(
                        icon: Icons.shield_outlined,
                        label: 'Peran',
                        value: user?.role.label ?? '-',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── GANTI PASSWORD (note item #8 — see AuthService.changePassword
              // for why this is a self-service change rather than an emailed
              // reset link: accounts use a synthetic @siap.local address that
              // isn't a real inbox).
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showChangePasswordDialog,
                    icon: const Icon(
                      Icons.lock_reset_rounded,
                      size: 18,
                      color: AppTheme.primaryGreen,
                    ),
                    label: const Text(
                      'Ganti Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      side: const BorderSide(color: AppTheme.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── LOGOUT BUTTON
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoggingOut ? null : _confirmLogout,
                    icon: _isLoggingOut
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.dangerRed,
                            ),
                          )
                        : const Icon(
                            Icons.logout_rounded,
                            size: 18,
                            color: AppTheme.dangerRed,
                          ),
                    label: Text(
                      _isLoggingOut ? 'Sedang Logout...' : 'Logout',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.dangerRed,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerRed,
                      side: const BorderSide(color: AppTheme.dangerRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
