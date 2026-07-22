import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AppScanFab extends StatelessWidget {
  const AppScanFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // ── Note item #2 (15.07.2026): hides itself while the keyboard is
    // open so it doesn't float on top of whatever the user is typing.
    // viewInsets.bottom > 0 means the keyboard (or another bottom inset
    // like an IME) is currently showing.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: keyboardOpen ? 0 : 1,
      child: IgnorePointer(
        ignoring: keyboardOpen,
        child: FloatingActionButton(
          onPressed: onTap,
          backgroundColor: AppTheme.primaryGreen,
          elevation: 2,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.qr_code_scanner_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
