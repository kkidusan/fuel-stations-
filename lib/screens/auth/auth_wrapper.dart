import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_user_service.dart';
import '../driver/driver_dashboard.dart';
import '../station/station_dashboard.dart';
import '../user/user_dashboard.dart';
import 'login_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Remove the GlobalKey that references private class
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print('=== AUTH WRAPPER ===');
        print('Auth state: ${snapshot.data?.uid ?? "Not logged in"}');
        print('Connection state: ${snapshot.connectionState}');
        print('Has data: ${snapshot.hasData}');

        // ── Loading ────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingView(message: 'Initializing...');
        }

        // ── Not signed in ──────────────────────────────────────────
        if (snapshot.data == null) {
          print('Showing LoginScreen');
          return LoginScreen(
            onLoginSuccess: () {
              print('=== CALLBACK TRIGGERED ===');
              print('Forcing rebuild of AuthWrapper');
              // Force a complete rebuild
              if (mounted) {
                setState(() {});
              }
            },
          );
        }

        // ── Signed in → load role ──────────────────────────────────
        print('User is signed in, loading role...');
        return FutureBuilder<String>(
          future: AuthService.getUserRole(),
          builder: (context, roleSnapshot) {
            print('Role loading state: ${roleSnapshot.connectionState}');
            
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingView(message: 'Loading profile...');
            }

            if (roleSnapshot.hasError) {
              print('Role error: ${roleSnapshot.error}');
              return _ErrorView(
                error: roleSnapshot.error.toString(),
                onRetry: () {
                  setState(() {});
                },
              );
            }

            final role = (roleSnapshot.data ?? 'user').toLowerCase().trim();
            print('=== NAVIGATING TO DASHBOARD ===');
            print('User role: $role');
            
            // Navigate based on role
            Widget dashboard;
            switch (role) {
              case 'driver':
                dashboard = const DriverDashboard();
                break;
              case 'station':
                dashboard = const StationDashboard();
                break;
              default:
                dashboard = const UserDashboard();
            }
            
            return dashboard;
          },
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Profile Loading Error',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  final String message;

  const _LoadingView({this.message = 'Loading...'});

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