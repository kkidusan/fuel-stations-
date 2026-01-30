import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_user_service.dart';
import '../driver/driver_dashboard.dart';
import '../station/station_dashboard.dart';
import '../user/user_dashboard.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ── Loading ────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingView(message: 'Initializing...');
        }

        // ── Not signed in ──────────────────────────────────────────
        if (snapshot.data == null) {
          return const LoginScreen();
        }

        // ── Signed in → load role ──────────────────────────────────
        return FutureBuilder<String>(
          future: AuthService.getUserRole(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingView(message: 'Loading profile...');
            }

            if (roleSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Error loading role:\n${roleSnapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            final role = (roleSnapshot.data ?? 'user').toLowerCase().trim();

            switch (role) {
              case 'driver':
                return const DriverDashboard();
              case 'station':
                return const StationDashboard();
              default:
                return const UserDashboard();
            }
          },
        );
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  final String message;

  const _LoadingView({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.local_gas_station_rounded,
              size: 90,
              color: Colors.blue,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              message,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}