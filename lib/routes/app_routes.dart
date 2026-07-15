import 'package:flutter/material.dart';

// IMPORT SEMUA PAGE
import '../screens/auth/login_page.dart';
import '../screens/auth/signup_page.dart';
import '../screens/home/home_page.dart';
import '../screens/peminjaman/form_page.dart';
import '../screens/peminjaman/history_page.dart';
import '../screens/peminjaman/scan_page.dart';
import '../screens/peminjaman/return_page.dart';
import '../screens/peminjaman/barcode_page.dart';
import '../screens/peminjaman/profile.dart';

class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String form = '/form';
  static const String history = '/history';
  static const String scan = '/scan';
  static const String returnPage = '/return';
  static const String barcode = '/barcode';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginPage(),
    signup: (context) => const SignUpPage(),
    home: (context) => const HomePage(),
    form: (context) => const FormPage(),
    history: (context) => const HistoryPage(),
    scan: (context) => const ScanPage(),
    returnPage: (context) => const ReturnPage(),
    barcode: (context) => const BarcodePage(),
    profile: (context) => const ProfilPage(),
  };
}
