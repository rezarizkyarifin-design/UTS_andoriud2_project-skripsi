import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps [child] so the Android/hardware back button doesn't leave the
/// screen (and doesn't try to pop to some other route) — instead it
/// shows "Tekan sekali lagi untuk keluar" and only exits the app if
/// pressed again within [window].
///
/// Meant for the app's "terminal" screens (Onboarding, Login, Home) —
/// the only places where back button should be allowed to close the
/// app at all. Every other screen redirects back button elsewhere
/// instead (see e.g. how Profile/History/Return use PopScope to send
/// the user to Home).
class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({
    super.key,
    required this.child,
    this.window = const Duration(seconds: 2),
  });

  final Widget child;
  final Duration window;

  @override
  State<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends State<DoubleBackToExit> {
  DateTime? _lastPressedAt;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final now = DateTime.now();
        final isSecondPress =
            _lastPressedAt != null &&
            now.difference(_lastPressedAt!) <= widget.window;

        if (isSecondPress) {
          SystemNavigator.pop();
          return;
        }

        _lastPressedAt = now;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Tekan sekali lagi untuk keluar'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      child: widget.child,
    );
  }
}
