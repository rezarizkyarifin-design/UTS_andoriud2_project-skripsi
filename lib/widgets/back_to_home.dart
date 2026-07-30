import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

/// Wraps [child] so the back button never falls through to whatever
/// happens to be underneath it on the navigation stack — it always
/// lands on Home instead, with the rest of the stack cleared out from
/// under it (so Home is left as the sole route, ready for its own
/// double-back-to-exit behavior).
///
/// Used on Profile/History/Return — screens that can be reached by
/// several different paths (bottom nav, drawer, from each other), so
/// "go back to whatever was previously on the stack" would be
/// inconsistent depending on how the user got there. Redirecting to
/// Home unconditionally keeps it predictable.
class BackToHome extends StatelessWidget {
  const BackToHome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
      },
      child: child,
    );
  }
}
