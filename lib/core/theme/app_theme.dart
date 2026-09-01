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

  // ── Shared shape and surface tokens ──
  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 20;
  static const double radiusSheet = 24;
  static const Color textPrimary = Color(0xFF1F2933);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textMuted = Color(0xFF98A2B3);
  static const Color forestDark = Color(0xFF0F2A1E);
  static const Color sage = Color(0xFF3D8361);
  static const Color gold = Color(0xFFC08A3E);
  static const Color parchment = Color(0xFFFAF6EE);
  static const Color ink = Color(0xFF1E2A22);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryGreen, accentGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static final lightTheme = ThemeData(
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      surface: Colors.white,
      error: dangerRed,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusLarge)),
      ),
      color: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceMuted,
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        borderSide: BorderSide(color: accentGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: divider),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusLarge)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      backgroundColor: textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      modalBackgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
      ),
    ),
  );
}
