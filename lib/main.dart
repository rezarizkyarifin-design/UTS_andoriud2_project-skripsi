import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/peminjaman_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Get these two values from your Supabase project:
  // Dashboard → Project Settings → API → Project URL / anon public key
  await Supabase.initialize(
    url: 'https://axiulqpwrzbzihphfwwm.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF4aXVscXB3cnpiemlocGhmd3dtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2Mzk1NTcsImV4cCI6MjA5OTIxNTU1N30.Ke20mXol554sglYHvwfGfCOjyJcTxsQ3YG6-D3oYMOs',
  );

  // DEV ONLY — forces the onboarding slides to show on every hot restart,
  // regardless of a restored session or the persisted onboarding_seen
  // flag. Only active in debug builds (kDebugMode), so it never runs in
  // a release/profile build. Set this to false to go back to normal
  // behavior (skip onboarding when a session is restored).
  const forceOnboardingInDebug = true;

  // Silently detect a restored session (if any) so returning users skip
  // straight to home. If restored, also warm up the peminjaman cache so
  // HomePage/HistoryPage have data ready immediately.
  final restored = Supabase.instance.client.auth.currentSession != null;
  if (restored) {
    await PeminjamanService.refresh();
  }

  // Onboarding only ever shows once, on a fresh install / before first
  // login — never again after that, even after logout.
  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('onboarding_seen') ?? false;

  final String initialRoute;
  if (kDebugMode && forceOnboardingInDebug) {
    initialRoute = AppRoutes.onboarding;
  } else if (restored) {
    initialRoute = AppRoutes.home;
  } else if (!seenOnboarding) {
    initialRoute = AppRoutes.onboarding;
  } else {
    initialRoute = AppRoutes.login;
  }

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Arsip',
      theme: AppTheme.lightTheme,
      // NOT `initialRoute:` — when the initial route name isn't literally
      // "/", Flutter's default behavior synthesizes a "/" route and
      // pushes it *underneath* the real initial route (so back button
      // has "somewhere to go"). Since our route table has no "/" entry,
      // that phantom route falls through to onGenerateRoute's not-found
      // fallback — invisible until the user presses back once from the
      // first screen, then they land on "Halaman '/' tidak ditemukan.".
      // onGenerateInitialRoutes bypasses that synthesis entirely: it
      // builds exactly the one route we ask for, nothing hidden beneath.
      onGenerateInitialRoutes: (_) => [
        AppRoutes.onGenerateRoute(RouteSettings(name: initialRoute)),
      ],
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
