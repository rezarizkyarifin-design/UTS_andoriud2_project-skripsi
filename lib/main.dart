import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/peminjaman_service.dart';
import 'screens/splash/splash_page.dart';

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

  // Same decision as before — just renamed, since it's no longer the
  // literal first route. It's now where SplashPage sends the user once
  // its animation finishes (see MyApp below / SplashPage.nextRoute).
  final String nextRoute;
  if (kDebugMode && forceOnboardingInDebug) {
    nextRoute = AppRoutes.onboarding;
  } else if (restored) {
    nextRoute = AppRoutes.home;
  } else if (!seenOnboarding) {
    nextRoute = AppRoutes.onboarding;
  } else {
    nextRoute = AppRoutes.login;
  }

  runApp(MyApp(nextRoute: nextRoute));
}

class MyApp extends StatelessWidget {
  final String nextRoute;
  const MyApp({super.key, required this.nextRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Arsip',
      theme: AppTheme.lightTheme,
      // Every cold start now opens on SplashPage first, regardless of
      // nextRoute — it plays its intro animation, then does
      // pushReplacementNamed(nextRoute) itself once that finishes. This
      // is a plain widget built directly with `home:`, not a named
      // route, precisely so it's NOT part of the route table and can't
      // be navigated back to with the back button once it's been
      // replaced.
      //
      // The NOT-`initialRoute:` reasoning from before still applies to
      // nextRoute itself, just one level down — see SplashPage's
      // Navigator.pushReplacementNamed call, which goes through
      // AppRoutes.onGenerateRoute like any other named navigation, so
      // there's still no phantom "/" route hiding underneath it.
      home: SplashPage(nextRoute: nextRoute),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
