import 'package:flutter/material.dart';

// IMPORT SEMUA PAGE
import '../screens/onboarding/onboarding_page.dart';
import '../screens/auth/login_page.dart';
import '../screens/auth/signup_page.dart';
import '../screens/home/home_page.dart';
import '../screens/peminjaman/form_page.dart';
import '../screens/peminjaman/history_page.dart';
import '../screens/peminjaman/scan_page.dart';
import '../screens/peminjaman/return_page.dart';
import '../screens/peminjaman/barcode_page.dart';
import '../screens/peminjaman/profile_page.dart';
import '../screens/peminjaman/archive_page.dart';

class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String form = '/form';
  static const String history = '/history';
  static const String archive = '/archive';
  static const String scan = '/scan';
  static const String returnPage = '/return';
  static const String barcode = '/barcode';
  static const String profile = '/profile';

  // Plain builders per route — unchanged from before. The actual page
  // widget for each name still lives here; only *how* Navigator gets
  // from one to the next changes, in onGenerateRoute below.
  static final Map<String, WidgetBuilder> _pages = {
    onboarding: (context) => const OnboardingPage(),
    login: (context) => const LoginPage(),
    signup: (context) => const SignUpPage(),
    home: (context) => const HomePage(),
    form: (context) => const FormPage(),
    history: (context) => const HistoryPage(),
    archive: (context) => const ArchivePage(),
    scan: (context) => const ScanPage(),
    returnPage: (context) => const ReturnPage(),
    barcode: (context) => const BarcodePage(),
    profile: (context) => const ProfilPage(),
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final builder = _pages[settings.name];

    if (builder == null) {
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => Scaffold(
          body: Center(
            child: Text('Halaman "${settings.name}" tidak ditemukan.'),
          ),
        ),
      );
    }

    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final slide =
            Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }
}
