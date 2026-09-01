import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../routes/app_routes.dart';
import '../services/auth_service.dart'; // exposes AuthService + NetworkException
import '../services/peminjaman_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/double_back_to_exit.dart';
import '../../widgets/animated_terrain_bg.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isPasswordHidden = true;
  bool _isSubmitting = false;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const _forestDark = AppTheme.forestDark;
  static const _sage = AppTheme.sage;
  static const _gold = AppTheme.gold;
  static const _fieldFill = AppTheme.surfaceMuted;
  static const _ink = AppTheme.ink;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      setState(() => _isSubmitting = true);

      bool success = false;
      String? networkErrorMessage;
      try {
        success = await AuthService.login(username, password);
      } on NetworkException catch (e) {
        // Previously uncaught: this exception used to escape straight out
        // of _handleLogin, which meant the setState below that turns off
        // the loading spinner never ran — the button just stayed stuck
        // "loading" forever with no error shown, indistinguishable from
        // the app having frozen.
        networkErrorMessage = e.message;
      }

      String? refreshError;
      if (success) {
        // main.dart only calls this on a restored session — a fresh
        // manual login here also needs the cache populated, or every
        // page reads an empty PeminjamanService._cache until something
        // gets written locally in this session.
        try {
          await PeminjamanService.refresh();
        } catch (e) {
          refreshError = e.toString();
        }
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (networkErrorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(networkErrorMessage),
            backgroundColor: AppTheme.warningAmber,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      if (success) {
        // Unfocus first: replacing this route while the username/password
        // field still holds focus tears down its InheritedElement before
        // the keyboard/focus overlay detaches, tripping framework.dart's
        // '_dependents.isEmpty' assertion. Unfocusing first avoids it.
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        if (refreshError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Login berhasil, tapi gagal memuat data: $refreshError',
              ),
              backgroundColor: AppTheme.warningAmber,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username atau password salah'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DoubleBackToExit(
      child: Scaffold(
        backgroundColor: AppTheme.parchment,
        body: CustomScrollView(
          slivers: [
            // ── Header: Responsive height (42% of screen) instead of fixed pixels ──
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.42,
                width: double.infinity,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipPath(
                      clipper: _TerrainClipper(),
                      child: Stack(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _forestDark,
                                  AppTheme.primaryGreen,
                                  _sage,
                                ],
                                stops: [0.0, 0.55, 1.0],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          const Positioned.fill(
                            child: AnimatedTerrainBackground(
                              mode: BackgroundMode.header,
                              blobColors: [_gold, _sage],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 18,
                      right: 22,
                      child: Transform.rotate(
                        angle: 0.09,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _gold.withValues(alpha: 0.55),
                              width: 1.3,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.shield_outlined,
                                color: _gold.withValues(alpha: 0.85),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      'https://pbs.twimg.com/profile_images/1525051472873783296/zBL0VecH_400x400.jpg',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.account_balance,
                                                color: AppTheme.primaryGreen,
                                                size: 24,
                                              ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Arsip Kantah Kota Cilegon',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selamat Datang,',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white70,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Silakan Masuk',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize:
                                        32, // Replaced Newsreader and adjusted size
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Form: Uses SliverFillRemaining to safely adapt to screen space ──
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Masuk untuk mengelola peminjaman arsip dokumen Anda.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        color: _ink.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            style: GoogleFonts.plusJakartaSans(color: _ink),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: GoogleFonts.plusJakartaSans(),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: _ink,
                              ),
                              filled: true,
                              fillColor: _fieldFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: _gold,
                                  width: 1.6,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Username tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: isPasswordHidden,
                            style: GoogleFonts.plusJakartaSans(color: _ink),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: GoogleFonts.plusJakartaSans(),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: _ink,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isPasswordHidden
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: _ink,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isPasswordHidden = !isPasswordHidden;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: _fieldFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: _gold,
                                  width: 1.6,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Password tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 26),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [
                                    _forestDark,
                                    AppTheme.primaryGreen,
                                    _sage,
                                  ],
                                  stops: [0.0, 0.5, 1.0],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryGreen.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: _isSubmitting ? null : _handleLogin,
                                  child: Center(
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
                                            'Masuk',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 36,
                            height: 3,
                            decoration: BoxDecoration(
                              color: _gold,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_outlined,
                            size: 14,
                            color: _gold,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Melayani Profesional dan Terpercaya',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.primaryGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.pushNamed(context, AppRoutes.signup);
                            },
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: _ink.withValues(alpha: 0.6),
                          ),
                          children: [
                            const TextSpan(text: 'Belum punya akun? '),
                            TextSpan(
                              text: 'Daftar di sini',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerrainClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height * 0.68);
    path.cubicTo(
      size.width * 0.30,
      size.height * 0.95,
      size.width * 0.55,
      size.height * 0.55,
      size.width * 0.78,
      size.height * 0.72,
    );
    path.cubicTo(
      size.width * 0.92,
      size.height * 0.82,
      size.width * 0.97,
      size.height * 0.60,
      size.width,
      size.height * 0.68,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
