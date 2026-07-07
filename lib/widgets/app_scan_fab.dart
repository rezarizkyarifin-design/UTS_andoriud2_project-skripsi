import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AppScanFab extends StatelessWidget {
  const AppScanFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onTap,
      backgroundColor: AppTheme.primaryGreen,
      elevation: 2,
      shape: const CircleBorder(),
      child: const Icon(
        Icons.qr_code_scanner_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}
