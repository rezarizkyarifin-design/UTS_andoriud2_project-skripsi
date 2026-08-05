// import 'dart:math' as math;

// import 'package:flutter/material.dart';

// enum BackgroundMode { header, ambient }

// class AnimatedTerrainBackground extends StatefulWidget {
//   const AnimatedTerrainBackground({
//     super.key,
//     required this.mode,
//     this.blobColors = const [Color(0xFF3D8361), Color(0xFFC08A3E)],
//     this.gridColor,
//   });
//   final BackgroundMode mode;
//   final List<Color> blobColors;
//   final Color? gridColor;

//   @override
//   State<AnimatedTerrainBackground> createState() =>
//       _AnimatedTerrainBackgroundState();
// }

// class _AnimatedTerrainBackgroundState extends State<AnimatedTerrainBackground>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 10),
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isHeader = widget.mode == BackgroundMode.header;
//     final gridColor =
//         widget.gridColor ?? (isHeader ? Colors.white : const Color(0xFF1E2A22));

//     return IgnorePointer(
//       child: RepaintBoundary(
//         child: AnimatedBuilder(
//           animation: _controller,
//           builder: (context, _) {
//             return CustomPaint(
//               painter: _TerrainBackgroundPainter(
//                 t: _controller.value,
//                 blobColors: widget.blobColors,
//                 gridColor: gridColor,
//                 gridAlpha: isHeader ? 0.05 : 0.035,
//                 gridSpacing: isHeader ? 28.0 : 34.0,
//                 blobAlpha: isHeader ? 0.38 : 0.22,
//                 blobCount: isHeader ? 3 : 4,
//                 additiveBlobs: isHeader,
//               ),
//               size: Size.infinite,
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// class _Blob {
//   const _Blob(this.cx, this.cy, this.radius, this.speed, this.colorIndex);

//   /// Center position as a fraction of the canvas (0..1).
//   final double cx;
//   final double cy;

//   /// Radius as a fraction of the canvas's shortest side.
//   final double radius;

//   /// Relative drift speed (higher = faster orbit).
//   final double speed;

//   final int colorIndex;
// }

// const _blobs = [
//   _Blob(0.15, 0.18, 0.55, 1.0, 0),
//   _Blob(0.88, 0.12, 0.42, 0.7, 1),
//   _Blob(0.78, 0.88, 0.60, 1.3, 0),
//   _Blob(0.08, 0.90, 0.38, 0.9, 1),
// ];

// class _TerrainBackgroundPainter extends CustomPainter {
//   _TerrainBackgroundPainter({
//     required this.t,
//     required this.blobColors,
//     required this.gridColor,
//     required this.gridAlpha,
//     required this.gridSpacing,
//     required this.blobAlpha,
//     required this.blobCount,
//     required this.additiveBlobs,
//   });

//   final double t;
//   final List<Color> blobColors;
//   final Color gridColor;
//   final double gridAlpha;
//   final double gridSpacing;
//   final double blobAlpha;
//   final int blobCount;
//   final bool additiveBlobs;

//   @override
//   void paint(Canvas canvas, Size size) {
//     final blobPaint = Paint()
//       ..blendMode = additiveBlobs ? BlendMode.plus : BlendMode.srcOver;
//     final colors = blobColors.isEmpty ? const [Color(0xFF3D8361)] : blobColors;

//     for (var i = 0; i < blobCount && i < _blobs.length; i++) {
//       final b = _blobs[i];
//       final angle = t * 2 * math.pi * b.speed;
//       final driftX = math.cos(angle) * 0.14;
//       final driftY = math.sin(angle * 0.8) * 0.14;
//       final center = Offset(
//         (b.cx + driftX) * size.width,
//         (b.cy + driftY) * size.height,
//       );
//       final radius = b.radius * size.shortestSide;
//       final color = colors[b.colorIndex % colors.length];

//       blobPaint.shader = RadialGradient(
//         colors: [
//           color.withValues(alpha: blobAlpha),
//           color.withValues(alpha: 0),
//         ],
//       ).createShader(Rect.fromCircle(center: center, radius: radius));
//       canvas.drawCircle(center, radius, blobPaint);
//     }

//     // Faint cadastral grid on top — a quiet nod to land-survey plot lines.
//     final gridPaint = Paint()
//       ..color = gridColor.withValues(alpha: gridAlpha)
//       ..strokeWidth = 0.6;
//     for (double x = 0; x < size.width; x += gridSpacing) {
//       canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
//     }
//     for (double y = 0; y < size.height; y += gridSpacing) {
//       canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _TerrainBackgroundPainter oldDelegate) =>
//       oldDelegate.t != t ||
//       oldDelegate.blobColors != blobColors ||
//       oldDelegate.gridColor != gridColor;
// }
