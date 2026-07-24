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
    //
    // Deliberately NOT using AnimatedOpacity/AnimatedSwitcher here: this
    // FAB is almost always used with
    // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    // which makes Scaffold track the FAB's geometry internally for the
    // BottomAppBar notch. An implicit animation on top of that geometry
    // tracking can trip framework.dart's '_dependents.isEmpty' assertion
    // if the Scaffold hosting it gets torn down (route change, logout,
    // pushReplacementNamed, etc.) mid-tick. A plain conditional swap has
    // no animation controller in play, so there's nothing to race.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    if (keyboardOpen) return const SizedBox.shrink();

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
