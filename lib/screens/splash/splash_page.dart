// Currently under development

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// First screen shown on every cold start (see main.dart /
/// AppRoutes.splash) — logo + name animate in, then this
/// auto-navigates to whatever route main.dart already decided is next
/// (onboarding, login, or home), passed in via [nextRoute].
///
/// Same dark-forest palette as onboarding_page.dart on purpose — see
/// that file's comment: this should read as the first frame of the
/// same story, not a separate splash bolted on top.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.nextRoute});

  /// Route name to navigate to once the splash animation finishes.
  final String nextRoute;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static const _forestDark = Color(0xFF0F2A1E);
  static const _sage = Color(0xFF3D8361);
  static const _gold = Color(0xFFC08A3E);
  static const _parchment = Color(0xFFFAF6EE);

  late final AnimationController _controller;

  // Logo: pops in with a slight overshoot (elastic), 0% → 55% of the
  // timeline.
  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
  );

  // Wordmark + tagline: fades/slides up right after the logo settles,
  // 35% → 75% of the timeline.
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
  );
  late final Animation<Offset> _textSlide =
      Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
        ),
      );

  // Thin gold ring: draws itself around the logo, 20% → 90%.
  late final Animation<double> _ringProgress = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.2, 0.9, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    // Total time on screen: animation duration + a short hold so the
    // finished state isn't just a flash before navigating away.
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, widget.nextRoute);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _forestDark,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: SizedBox(
                      width: 128,
                      height: 128,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Gold ring that "draws" itself in.
                          CustomPaint(
                            size: const Size(128, 128),
                            painter: _RingPainter(
                              progress: _ringProgress.value,
                              color: _gold,
                            ),
                          ),
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _sage.withOpacity(0.18),
                              border: Border.all(
                                color: _sage.withOpacity(0.6),
                                width: 1.2,
                              ),
                            ),
                            child: const Icon(
                              Icons.map_outlined,
                              color: _parchment,
                              size: 42,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        Text(
                          'SIAP',
                          style: GoogleFonts.plusJakartaSans(
                            color: _parchment,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Kantor Pertanahan Kota Cilegon',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: _parchment.withOpacity(0.7),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Draws an arc from 0 to `progress * 360` degrees, giving the ring a
/// "drawing itself in" feel rather than just appearing at full opacity.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final rect = Offset.zero & size;
    const startAngle = -1.5708; // -90deg, start at the top
    final sweepAngle = 6.28319 * progress; // 2*pi * progress

    canvas.drawArc(
      rect.deflate(paint.strokeWidth / 2),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
