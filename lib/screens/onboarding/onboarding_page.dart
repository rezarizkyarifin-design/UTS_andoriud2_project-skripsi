import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../models/onboarding_slide.dart';
import '../../routes/app_routes.dart';
import '../../widgets/double_back_to_exit.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  // Same palette as login_page.dart, on purpose — onboarding should feel
  // like the first act of the same story, not a separate app.
  static const _forestDark = AppTheme.forestDark;
  static const _sage = AppTheme.sage;
  static const _gold = AppTheme.gold;
  static const _parchment = AppTheme.parchment;
  static const _ink = AppTheme.ink;

  late final PageController _pageController;
  double _page = 0;
  int _currentIndex = 0;

  final List<OnboardingSlide> _slides = const [
    OnboardingSlide(
      title: 'Kelola Arsip\nPertanahan',
      description:
          'Satu aplikasi untuk mencatat, meminjam, dan mengembalikan '
          'dokumen arsip pertanahan dengan rapi.',
      icon: Icons.map_outlined,
    ),
    OnboardingSlide(
      title: 'Ajukan Peminjaman\ndengan Cepat',
      description:
          'Isi data pemohon, jenis hak, dan keperluan peminjaman '
          'langsung dari genggaman Anda.',
      icon: Icons.assignment_outlined,
    ),
    OnboardingSlide(
      title: 'Pindai & Lacak\nSetiap Dokumen',
      description:
          'Gunakan kode QR untuk memindai dokumen dan memantau '
          'status peminjaman secara instan.',
      icon: Icons.qr_code_scanner_outlined,
    ),
    OnboardingSlide(
      title: 'Semua Sudah\nSiap',
      description:
          'Masuk sekarang untuk mulai mengelola arsip pertanahan '
          'Anda dengan SIAP.',
      icon: Icons.verified_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController()..addListener(_onScroll);
  }

  void _onScroll() {
    setState(() => _page = _pageController.page ?? 0);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  void _next() {
    if (_currentIndex == _slides.length - 1) {
      _finishOnboarding();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastIndex = _slides.length - 1;
    final isLast = _currentIndex == lastIndex;

    return DoubleBackToExit(
      child: Scaffold(
        backgroundColor: _parchment,
        // Flex-based split (Expanded flex: 42 / 58) instead of manual pixel
        // math off MediaQuery — a fixed-pixel offset could end up leaving
        // the bottom section only a few px tall on some devices depending
        // on how their insets report; flex guarantees a real proportional
        // share of whatever height is actually available.
        body: Column(
          children: [
            // ── Header: same terrain-toned gradient + faint cadastral grid
            // as the login page, but with a big animated icon badge instead
            // of the small corner badge — this is the "hero" moment.
            Expanded(
              flex: 42,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_forestDark, AppTheme.primaryGreen, _sage],
                    stops: [0.0, 0.55, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _GridPainter()),
                    ),
                    ..._buildBlobs(),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SIAP',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (!isLast)
                              TextButton(
                                onPressed: _finishOnboarding,
                                child: Text(
                                  'Lewati',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _AnimatedBadge(page: _page, slides: _slides),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content sheet: rounded top so it still reads as one
            // continuous surface sliding up over the header gradient.
            // Uses Expanded (flex) instead of a fixed pixel offset so it
            // always gets a real share of the available height, whatever
            // a given device reports for insets/status/nav bars.
            Expanded(
              flex: 58,
              child: Container(
                decoration: const BoxDecoration(
                  color: _parchment,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 28),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _slides.length,
                          onPageChanged: (index) =>
                              setState(() => _currentIndex = index),
                          itemBuilder: (context, index) =>
                              _SlideText(slide: _slides[index]),
                        ),
                      ),
                      _DotIndicator(
                        count: _slides.length,
                        page: _page,
                        activeColor: AppTheme.primaryGreen,
                        inactiveColor: _ink.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
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
                                onTap: _next,
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Text(
                                      isLast ? 'Mulai Sekarang' : 'Lanjut',
                                      key: ValueKey(isLast),
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

  List<Widget> _buildBlobs() {
    // Abstract, minimal blobs that drift slightly as you swipe — the
    // "soft shapes" half of the mix, kept subtle so they don't compete
    // with the badge icon, which carries the literal land/document theme.
    return [
      Positioned(
        top: -30 - (_page * 6),
        left: -20 + (_page * 10),
        child: _blob(120, _gold.withValues(alpha: 0.10)),
      ),
      Positioned(
        bottom: -40 + (_page * 8),
        right: -30 - (_page * 6),
        child: _blob(160, Colors.white.withValues(alpha: 0.06)),
      ),
    ];
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _AnimatedBadge extends StatelessWidget {
  final double page;
  final List<OnboardingSlide> slides;

  const _AnimatedBadge({required this.page, required this.slides});

  static const _gold = Color(0xFFC08A3E);

  @override
  Widget build(BuildContext context) {
    final lastIndex = slides.length - 1;
    final t = page.clamp(0, lastIndex.toDouble());
    final loIndex = t.floor();
    final hiIndex = math.min(loIndex + 1, lastIndex);
    final localT = t - loIndex;

    final icon = localT < 0.5 ? slides[loIndex].icon : slides[hiIndex].icon;

    return Transform.rotate(
      angle: 0.09 - (localT * 0.18),
      child: Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _gold.withValues(alpha: 0.5), width: 1.4),
        ),
        child: Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  size: 44,
                  color: const Color(0xFF2E7D52),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideText extends StatelessWidget {
  final OnboardingSlide slide;
  const _SlideText({required this.slide});

  static const _ink = Color(0xFF1E2A22);

  @override
  Widget build(BuildContext context) {
    // Wrapped in a scroll view so this can never hard-overflow again —
    // on shorter screens or longer copy it now scrolls instead of
    // throwing the yellow/black "BOTTOM OVERFLOWED" band.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              height: 1.15,
              color: _ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: _ink.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final int count;
  final double page;
  final Color activeColor;
  final Color inactiveColor;

  const _DotIndicator({
    required this.count,
    required this.page,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final distance = (page - index).abs().clamp(0.0, 1.0);
        final width = 8.0 + (1 - distance) * 16.0;
        final color = Color.lerp(inactiveColor, activeColor, 1 - distance)!;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: width,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.6;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
