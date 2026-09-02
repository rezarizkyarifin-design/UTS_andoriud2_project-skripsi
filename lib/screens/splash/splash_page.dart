// Currently under development

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.nextRoute});

  /// Route name to navigate to once the splash animation finishes.
  final String nextRoute;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  // Use AppTheme constants for consistency across the app
  static const _forestDark = AppTheme.forestDark;
  static const _sage = AppTheme.sage;
  static const _gold = AppTheme.gold;
  static const _parchment = AppTheme.parchment;

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

    // Remove the native splash only once THIS widget's first frame has
    // actually been painted — addPostFrameCallback fires right after
    // that happens. Doing this here (rather than in main.dart right
    // before runApp()) guarantees there's no gap where NEITHER splash is
    // showing: the native splash stays up the whole time until this
    // frame is genuinely on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    await _controller.forward();
    if (!mounted) return;

    // Short hold once fully drawn in, so the finished state isn't just a
    // flash before navigating away.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, widget.nextRoute);
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
