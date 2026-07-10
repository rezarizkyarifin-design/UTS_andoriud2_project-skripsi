import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/auth_service.dart';
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

  // Silently detect a restored session (if any) so returning users skip
  // the login screen. If restored, also warm up the peminjaman cache so
  // HomePage/HistoryPage have data ready immediately instead of showing
  // an empty state for a frame.
  final restored = Supabase.instance.client.auth.currentSession != null;
  if (restored) {
    await PeminjamanService.refresh();
  }

  runApp(MyApp(startLoggedIn: restored));
}

class MyApp extends StatelessWidget {
  final bool startLoggedIn;
  const MyApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Arsip',
      theme: AppTheme.lightTheme,
      initialRoute: startLoggedIn ? AppRoutes.home : AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}
