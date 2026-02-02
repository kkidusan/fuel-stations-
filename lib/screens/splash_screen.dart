import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'auth/auth_wrapper.dart';           // ← goes to AuthWrapper
import 'onboarding_screen.dart';          // only if onboarding not seen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Give splash screen some time to be visible (adjust as needed)
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool onboardingSeen = prefs.getBool('onboarding_seen') ?? false;

    if (!onboardingSeen) {
      // First time user → show onboarding
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    } else {
      // Onboarding already seen → go to AuthWrapper
      // (it will decide: login or correct dashboard based on auth state & role)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon / logo
              Icon(
                Icons.local_gas_station_rounded,
                size: 120,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 32),

              // App name
              Text(
                loc.appName,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              // Optional tagline
              Text(
                'Fuel Delivery in Ethiopia',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),

              const SizedBox(height: 60),

              // Loading indicator
              const CircularProgressIndicator(
                strokeWidth: 3,
              ),

              const SizedBox(height: 24),

              // Optional status text
              
            ],
          ),
        ),
      ),
    );
  }
}