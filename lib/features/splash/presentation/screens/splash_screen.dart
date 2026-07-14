import 'package:flutter/material.dart';

/// Flutter-side splash. Shows the **same** drawable that the native
/// `Theme.SplashScreen` icon points at (`splash_icon_full.png`), at the same
/// 240dp footprint Android 12+ reserves for `windowSplashScreenAnimatedIcon`.
///
/// Matching size + asset + background means the OS splash and the Flutter
/// splash are visually indistinguishable, so the hand-off when Flutter
/// renders its first frame doesn't create a second perceived splash.
///
/// The widget also serves as the holding screen while [AuthNotifier] hydrates
/// the persisted session — once auth resolves, the router navigates the user
/// straight to home / login / onboarding.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 240,
          height: 240,
          child: Image(
            image: AssetImage('assets/branding/splash_icon_full.png'),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
