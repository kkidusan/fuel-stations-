import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../services/auth_user_service.dart';
import '../driver/driver_dashboard.dart';
import '../station/station_dashboard.dart';
import '../user/user_dashboard.dart'; // passenger / regular user screen
import 'login_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _restoring = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Restores the JWT session (one /api/auth/me call). Called again after
  /// login / logout to re-evaluate the dashboard.
  Future<void> _restore() async {
    if (mounted) {
      setState(() {
        _restoring = true;
        _error = null;
      });
    }
    try {
      await AuthService.restoreSession(force: true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _restoring = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const _SplashLoadingView();
    }

    if (_error != null) {
      return _ErrorView(
        error: _error!,
        onRetry: _restore,
        onSignOut: () async {
          await AuthService.signOut();
          if (mounted) _restore();
        },
      );
    }

    final user = AuthService.currentUser;
    if (user == null) {
      return LoginScreen(onSignedIn: _restore);
    }

    return switch (user.role) {
      'driver' => const DriverDashboard(),
      'station' => const StationDashboard(),
      _ => const UserDashboard(),
    };
  }
}

class _SplashLoadingView extends StatelessWidget {
  const _SplashLoadingView();

  @override
  Widget build(BuildContext context) {
    // Only the splash animation — no text and no extra messages.
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Lottie.asset(
          'assets/lottie/splash.json',
          fit: BoxFit.contain,
          repeat: true,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  const _ErrorView({required this.error, required this.onRetry, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 90),
              const SizedBox(height: 24),
              const Text('Connection issue', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
              const SizedBox(height: 48),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: onRetry,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
                onPressed: onSignOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}