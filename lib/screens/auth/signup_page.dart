import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../models/user_roles.dart';
import '../services/auth_service.dart';
import '../services/peminjaman_service.dart';
import '../../widgets/animated_terrain_bg.dart';

/// Self-registration screen. Always creates a 'pegawai' account — see the
/// note on AuthService.signUp for why admin accounts are never created
/// through this flow.
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _alasanController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSubmitting = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;

  // ─── ADMIN ROLE REQUEST (14.09.2026) ───
  // Every self-registered account is still created as 'pegawai' — see
  // AuthService.signUp's doc comment for why nobody can grant themselves
  // admin through this form. Picking "Admin" here doesn't change that;
  // it just tells signUp to also file a pending request (visible to the
  // first admin in the system) for a real admin to approve later.
  UserRole _selectedRole = UserRole.pegawai;

  @override
  void dispose() {
    _namaController.dispose();
    _usernameController.dispose();
    _jabatanController.dispose();
    _alasanController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _successMessage() {
    final base = AuthService.isLoggedIn
        ? 'Akun Anda sudah aktif sebagai Pegawai.'
        : 'Akun Anda berhasil dibuat sebagai Pegawai. Silakan login untuk melanjutkan.';
    if (_selectedRole != UserRole.admin) {
      return AuthService.isLoggedIn
          ? '$base Anda akan diarahkan ke Beranda.'
          : base;
    }
    // Requested Admin: account is still Pegawai until an existing admin
    // approves the request that was just filed.
    return '$base Permintaan untuk menjadi Admin telah dikirim dan sedang '
        'menunggu persetujuan.';
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accentGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Anda Berhasil Mendaftar!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            _successMessage(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Lanjutkan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Konfirmasi password tidak cocok.'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final error = await AuthService.signUp(
      nama: _namaController.text,
      username: _usernameController.text,
      jabatan: _jabatanController.text,
      password: _passwordController.text,
      requestedRole: _selectedRole,
      alasan: _selectedRole == UserRole.admin ? _alasanController.text : null,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

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

    if (AuthService.isLoggedIn) {
      // signUp() left us with an active session (email confirmation is
      // off on the project) — go straight in, same as a normal login.
      try {
        await PeminjamanService.refresh();
      } catch (_) {
        // Non-fatal: HomePage will just show whatever's cached.
      }
      if (!mounted) return;
      await _showSuccessDialog();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    } else {
      // Email confirmation is on for this project — no session yet.
      if (!mounted) return;
      await _showSuccessDialog();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  // ─── ROLE SELECTOR ───
  // Two-way toggle, not a dropdown: only two options, both need to be
  // visible at a glance since the "Admin" choice comes with a caveat
  // (see helper text below) that's easy to miss inside a closed menu.
  Widget _roleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _roleOption(
                role: UserRole.pegawai,
                label: 'Pegawai',
                icon: Icons.badge_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _roleOption(
                role: UserRole.admin,
                label: 'Admin',
                icon: Icons.admin_panel_settings_outlined,
              ),
            ),
          ],
        ),
        if (_selectedRole == UserRole.admin) ...[
          const SizedBox(height: 8),
          Text(
            'Akun tetap dibuat sebagai Pegawai. Permintaan untuk menjadi '
            'Admin akan dikirim ke admin yang sudah ada untuk disetujui.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: Colors.black45,
            ),
          ),
        ],
      ],
    );
  }

  Widget _roleOption({
    required UserRole role,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: _isSubmitting ? null : () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.10)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.primaryGreen : Colors.black45,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryGreen : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Tombol back di halaman ini sengaja tidak pop kembali ke Login
        // (walau secara teknis Login ada di bawahnya di stack) — sesuai
        // alur yang diminta, back dari Sign Up selalu kembali ke
        // Onboarding.
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: Text(
            'Buat Akun Pegawai',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        body: Stack(
          children: [
            // Ambient backdrop — same drifting-blob/grid motif as the
            // Login header, just turned way down since it sits behind an
            // entire light page instead of a compact gradient panel.
            const Positioned.fill(
              child: AnimatedTerrainBackground(
                mode: BackgroundMode.ambient,
                blobColors: [AppTheme.primaryGreen, AppTheme.accentGreen],
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daftar sebagai pegawai baru untuk mengakses SIAP.'
                        ' Akun admin hanya dapat dibuat oleh admin yang sudah ada.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _namaController,
                        decoration: _decoration(
                          'Nama Lengkap',
                          Icons.person_outline,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _usernameController,
                        decoration: _decoration(
                          'Username',
                          Icons.alternate_email,
                        ),
                        autocorrect: false,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Wajib diisi';
                          }
                          if (v.contains(' ')) return 'Tidak boleh ada spasi';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _jabatanController,
                        decoration: _decoration(
                          'Jabatan',
                          Icons.badge_outlined,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _roleSelector(),
                      if (_selectedRole == UserRole.admin) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _alasanController,
                          maxLines: 3,
                          decoration: _decoration(
                            'Alasan mengajukan Admin',
                            Icons.notes_outlined,
                          ),
                          validator: (v) {
                            if (_selectedRole != UserRole.admin) return null;
                            return (v == null || v.trim().isEmpty)
                                ? 'Wajib diisi untuk permintaan Admin'
                                : null;
                          },
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        decoration: _decoration('Password', Icons.lock_outline)
                            .copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                              ),
                            ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Wajib diisi';
                          if (v.length < 6) return 'Minimal 6 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _hideConfirm,
                        decoration:
                            _decoration(
                              'Konfirmasi Password',
                              Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _hideConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _hideConfirm = !_hideConfirm,
                                ),
                              ),
                            ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Daftar',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: GestureDetector(
                          onTap: _isSubmitting
                              ? null
                              : () => Navigator.pushReplacementNamed(
                                  context,
                                  AppRoutes.login,
                                ),
                          child: Text(
                            'Sudah punya akun? Masuk',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                    ],
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
