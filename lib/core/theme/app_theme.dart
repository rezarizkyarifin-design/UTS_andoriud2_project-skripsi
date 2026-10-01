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

  /// "Diajukan" / pending — darker than warningAmber so it reads as
  /// distinct from "Dipinjam" when both chips are visible on the same
  /// screen.
  static const Color pendingAmber = Color(0xFF8A6D00);

  static const Color dangerRed = Color(0xFFC0392B); // "Terlambat" text
  static const Color dangerBg = Color(0xFFFDE2E1); // "Terlambat" chip bg

  // "Warkah" / QR-scan third-category accent — was scattered as a bare
  // Color(0xFF5C5FCD) literal across HomePage's quick-access grid, the
  // jenis-dokumen breakdown, and ArchivePage's filter chips. Same idea as
  // successGreen/warningAmber/dangerRed above: give it one name so every
  // screen that needs "the Warkah color" pulls from here instead of
  // retyping the hex and slowly drifting apart.
  static const Color infoPurple = Color(0xFF5C5FCD);
  static const Color infoBg = Color(0xFFE7E8FA);

  // Quick-access / action accents (HomePage grid) — solid fills with white
  // icons, so each destination reads as its own button.
  static const Color infoBlue = Color(0xFF2F80ED); // Inventaris Arsip
  static const Color actionOrange = Color(0xFFE08A1E); // Pengembalian

  // ── Neutral surfaces ──
  static const Color surfaceMuted = Color(
    0xFFF5F5F5,
  ); // input fields, inner info boxes
  static const Color divider = Color(0xFFE0E0E0);

  // Sheet body background — used behind the section cards in bottom
  // sheets (Edit Peminjaman, Edit/Tambah Arsip) so white cards have
  // something to sit on instead of floating on more white.
  static const Color sheetBody = Color(0xFFF7F8F7);

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
  static const Color parchment = Color.fromARGB(255, 252, 252, 252);
  static const Color ink = Color(0xFF1E2A22);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [
      Color(0xFF12382A), // slightly darker than primaryGreen, for depth
      primaryGreen,
      accentGreen,
    ],
    stops: [0.0, 0.45, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static final lightTheme = ThemeData(
    scaffoldBackgroundColor: pageBackground,
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

  // ── MODERNIZATION TOKENS ──────────────────────────────────────────
  // Elevation system — modern cards lift off the background with a
  // single soft shadow at three intensity levels, instead of the same
  // ad-hoc `blur: 10-14, y: 3-4, alpha: 0.04-0.06` copied into every
  // card's own BoxDecoration. Replacing those inline shadows with these
  // three tokens is what makes the whole app feel like one design
  // language instead of a dozen slightly-different ones.
  //
  //   - surface:  resting card on the page background (stat chips,
  //               recent-activity cards, list rows)
  //   - raised:   floating elements that should read as "above" others
  //               (dropdown panel, notification card, form section card)
  //   - overlay:  elements actually painted on top of everything, e.g.
  //               a bottom sheet header or an open menu
  static const List<BoxShadow> elevationSurface = [
    BoxShadow(
      color: Color(0x0A0F2A1E), // 4% of forestDark, not pure black
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> elevationRaised = [
    BoxShadow(
      color: Color(0x140F2A1E), // 8%
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> elevationOverlay = [
    BoxShadow(
      color: Color(0x1F0F2A1E), // 12%
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  // Soft green glow under the gradient page headers (primaryGreen @ 18%).
  // const-friendly, so headers can stay `const BoxDecoration`.
  static const List<BoxShadow> headerShadow = [
    BoxShadow(color: Color(0x2E1B4332), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // ── Refined surface palette ──
  // The single change that removes the "everything is white + hairline
  // border" look: cards sit on a *slightly* warm off-white page, and
  // card surfaces are a *barely-tinted* white instead of pure #FFFFFF.
  // Neither difference is visible on its own, but together they let
  // elevation do the work a border used to.
  static const Color pageBackground = Color(0xFFF4F6F5); // was #F8F9FA
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color cardSurfaceTinted = Color(0xFFFAFBFA); // for nested cards

  // Modern "active pill" background — used by the bottom nav indicator
  // and any chip that needs a soft, saturated-but-not-solid selected
  // state.
  static Color brandTint(Color base, [double alpha = 0.12]) =>
      base.withValues(alpha: alpha);

  // ── 2024-shaped radii ──
  // Existing radii stay, so nothing already using radiusSmall/Medium/
  // Large/Sheet changes. These are additions for the modernized
  // components below — slightly larger than the old defaults, because
  // a 20-24px corner radius on a 90px-tall card is what reads as
  // "modern" vs. the earlier 16px "slightly rounded rectangle".
  static const double radiusPill = 999;
  static const double radiusCard = 20;
  static const double radiusHeader = 28;
}
