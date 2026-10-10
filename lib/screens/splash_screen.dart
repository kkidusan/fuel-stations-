import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_wrapper.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    // Show splash for maximum 5 seconds
    await Future.delayed(const Duration(milliseconds: 5000));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool onboardingSeen = prefs.getBool('onboarding_seen') ?? false;

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => onboardingSeen 
              ? const AuthWrapper() 
              : const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only the splash animation — no text and no extra messages.
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Lottie.asset(
          'assets/lottie/splash.json',
          fit: BoxFit.contain,
          repeat: false,
        ),
      ),
    );
  }
}