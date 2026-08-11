import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Which context an [AnimatedTerrainBackground] is being used in.
///
/// - [header]: sits behind a small, saturated colored panel (e.g. the
///   dark-green gradient header on LoginPage). Grid + blobs read clearly.
/// - [ambient]: sits behind an entire light-colored page (e.g. SignUpPage's
///   body). Everything is turned down to a bare hint — texture, not decor.
enum BackgroundMode { header, ambient }

/// Reusable animated backdrop combining a faint cadastral grid with a
/// handful of slow-drifting, soft-edged color blobs.
///
/// Usage: drop it as the first child of a [Stack], sized to fill (e.g.
/// `Positioned.fill(child: AnimatedTerrainBackground(mode: ...))`). It
/// never intercepts touches, so nothing else needs to change around it.
///
/// PREVIOUS BUG ("looping inconsistency"): this used to be driven by a
/// bounded `AnimationController(duration: ...)..repeat()`, whose value
/// resets from 1 back to 0 every cycle. Blob motion was computed as
/// `angle = t * 2*pi * speed`, and unless `speed` was an exact whole
/// number, `angle` at t=1 didn't land back on a multiple of a full turn
/// — so the blob's position jumped visibly every time the controller
/// wrapped. Only one of the four blobs (speed 1.0) happened to loop
/// seamlessly; the other three (0.7, 1.3, 0.9) jumped 252°/108°/324°
/// on every restart.
///
/// Fix: drive this from a raw [Ticker] instead. Its elapsed time counts
/// up forever and is never reset, so there is no wraparound moment at
/// all — sin/cos of an ever-increasing value has no seam by
/// construction, regardless of what `speed` values are chosen.
class AnimatedTerrainBackground extends StatefulWidget {
  const AnimatedTerrainBackground({
    super.key,
    required this.mode,
    this.blobColors = const [Color(0xFF3D8361), Color(0xFFC08A3E)],
    this.gridColor,
  });

  final BackgroundMode mode;

  /// Colors cycled through across the blobs. Provide at least one.
  final List<Color> blobColors;

  /// Overrides the grid line color. Defaults to white for [BackgroundMode
  /// .header] (reads on a dark gradient) and a dark ink tone for
  /// [BackgroundMode.ambient] (reads on a light page background).
  final Color? gridColor;

  @override
  State<AnimatedTerrainBackground> createState() =>
      _AnimatedTerrainBackgroundState();
}

class _AnimatedTerrainBackgroundState extends State<AnimatedTerrainBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _elapsedSeconds = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _elapsedSeconds.value =
          elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsedSeconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHeader = widget.mode == BackgroundMode.header;
    final gridColor =
        widget.gridColor ?? (isHeader ? Colors.white : const Color(0xFF1E2A22));

    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: _elapsedSeconds,
          builder: (context, t, _) {
            return CustomPaint(
              painter: _TerrainBackgroundPainter(
                t: t,
                blobColors: widget.blobColors,
                gridColor: gridColor,
                gridAlpha: isHeader ? 0.06 : 0.04,
                gridSpacing: isHeader ? 28.0 : 34.0,
                blobAlpha: isHeader ? 0.28 : 0.16,
                blobCount: isHeader ? 3 : 4,
                additiveBlobs: isHeader,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _Blob {
  const _Blob(
    this.cx,
    this.cy,
    this.radius,
    this.angularSpeed,
    this.colorIndex,
  );

  /// Center position as a fraction of the canvas (0..1).
  final double cx;
  final double cy;

  /// Radius as a fraction of the canvas's shortest side.
  final double radius;

  /// Radians per second. Any value works now — there's no loop to land
  /// on, since `t` (seconds elapsed) never wraps back to 0.
  final double angularSpeed;

  final int colorIndex;
}

// Fixed layout so blobs stay spread out and don't cluster; `blobCount`
// just decides how many of these (in order) get drawn. Small, unrelated
// angularSpeed values are intentional — they used to have to line up to
// a whole-turn boundary to avoid a jump; now they don't, so it's safe to
// pick whatever reads as pleasantly uneven drift.
const _blobs = [
  _Blob(0.15, 0.18, 0.55, 0.045, 0),
  _Blob(0.88, 0.12, 0.42, 0.032, 1),
  _Blob(0.78, 0.88, 0.60, 0.058, 0),
  _Blob(0.08, 0.90, 0.38, 0.041, 1),
];

class _TerrainBackgroundPainter extends CustomPainter {
  _TerrainBackgroundPainter({
    required this.t,
    required this.blobColors,
    required this.gridColor,
    required this.gridAlpha,
    required this.gridSpacing,
    required this.blobAlpha,
    required this.blobCount,
    required this.additiveBlobs,
  });

  /// Seconds elapsed since this widget was first built. Monotonically
  /// increasing, never resets — see the class doc comment on
  /// AnimatedTerrainBackground for why that matters.
  final double t;
  final List<Color> blobColors;
  final Color gridColor;
  final double gridAlpha;
  final double gridSpacing;
  final double blobAlpha;
  final int blobCount;
  final bool additiveBlobs;

  @override
  void paint(Canvas canvas, Size size) {
    // Blobs first, so the grid still reads clearly on top of them.
    final blobPaint = Paint()
      ..blendMode = additiveBlobs ? BlendMode.plus : BlendMode.srcOver;
    final colors = blobColors.isEmpty ? const [Color(0xFF3D8361)] : blobColors;

    for (var i = 0; i < blobCount && i < _blobs.length; i++) {
      final b = _blobs[i];
      final angle = t * b.angularSpeed;
      final driftX = math.cos(angle) * 0.14;
      final driftY = math.sin(angle * 0.8) * 0.14;
      final center = Offset(
        (b.cx + driftX) * size.width,
        (b.cy + driftY) * size.height,
      );
      final radius = b.radius * size.shortestSide;
      final color = colors[b.colorIndex % colors.length];

      blobPaint.shader = RadialGradient(
        colors: [
          color.withValues(alpha: blobAlpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, blobPaint);
    }

    // Faint cadastral grid on top — a quiet nod to land-survey plot lines.
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: gridAlpha)
      ..strokeWidth = 0.6;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TerrainBackgroundPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.blobColors != blobColors ||
      oldDelegate.gridColor != gridColor;
}
