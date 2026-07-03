import 'package:flutter/material.dart';

/// Single source of truth for color/theming across the app.
///
/// Rule of thumb: if a widget needs a color, it should come from here.
/// Do NOT declare `static const Color _xxx = Color(0x...)` inside a page
/// anymore — that's exactly the duplication that made the app hard to
/// re-theme. Add the token here once, import AppTheme everywhere else.
class AppTheme {
  AppTheme._(); // no instances, static-only access

  // ── Brand ──
  static const Color primaryGreen = Color(
    0xFF1B4332,
  ); // Deep Professional Green — headers, drawer, active states
  static const Color accentGreen = Color(
    0xFF52B788,
  ); // Softer Action Green — buttons, highlights, gradient end
  static const Color background = Color(
    0xFFF8F9FA,
  ); // Off-white for less eye strain

  // ── Status / semantic colors ──
  // Used for "Sedang Dipinjam", "Telah Kembali", "Terlambat" chips & badges
  // across HomePage, HistoryPage, ReturnPage, and BarcodePage.
  static const Color successGreen = Color(0xFF2D6A4F); // "Telah Kembali" text
  static const Color successBg = Color(0xFFD8F3DC); // "Telah Kembali" chip bg

  static const Color warningAmber = Color(0xFFB07A00); // "Dipinjam" text
  static const Color warningBg = Color(0xFFFFF3D9); // "Dipinjam" chip bg

  static const Color dangerRed = Color(0xFFC0392B); // "Terlambat" text
  static const Color dangerBg = Color(0xFFFDE2E1); // "Terlambat" chip bg

  // ── Neutral surfaces ──
  static const Color surfaceMuted = Color(
    0xFFF5F5F5,
  ); // input fields, inner info boxes
  static const Color divider = Color(0xFFE0E0E0);

  static final lightTheme = ThemeData(
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F3F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
