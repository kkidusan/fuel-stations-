import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../signup_screen.dart';
import '../../services/auth_user_service.dart'; // Add this import
import '../user/user_dashboard.dart'; // Add this import
import '../driver/driver_dashboard.dart'; // Add this import
import '../station/station_dashboard.dart'; // Add this import

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  
  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  Future<void> _signIn() async {
    final loc = AppLocalizations.of(context)!;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = loc.pleaseFillAllFields);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('=== LOGIN ATTEMPT ===');
      print('Email: $email');
      
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('=== LOGIN SUCCESSFUL ===');
      print('User ID: ${userCredential.user?.uid}');
      
      if (mounted) {
        // Force Firebase to update auth state
        await FirebaseAuth.instance.currentUser?.reload();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.loginSuccessful),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        
        // Wait briefly for state to sync
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Call the callback if provided
        if (widget.onLoginSuccess != null) {
          print('Calling onLoginSuccess callback');
          widget.onLoginSuccess!();
        } else {
          print('ERROR: No callback provided! Using direct navigation');
          // Direct navigation as fallback
          await _navigateToDashboardDirectly();
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Login error: ${e.code} - ${e.message}');
      String message = e.message ?? loc.authenticationError;

      switch (e.code) {
        case 'user-not-found':
          message = loc.userNotFound;
          break;
        case 'wrong-password':
          message = loc.wrongPassword;
          break;
        case 'invalid-email':
          message = loc.invalidEmail;
          break;
        case 'user-disabled':
          message = loc.accountDisabled;
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Try again later.';
          break;
      }

      if (mounted) {
        setState(() => _errorMessage = message);
      }
    } catch (e) {
      print('Unexpected error: $e');
      if (mounted) {
        setState(() => _errorMessage = loc.unexpectedError);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Direct navigation method as fallback
  Future<void> _navigateToDashboardDirectly() async {
    try {
      // Get user role
      final role = await AuthService.getUserRole();
      print('Direct navigation - User role: $role');
      
      // Navigate based on role
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) {
              switch (role.toLowerCase().trim()) {
                case 'driver':
                  return const DriverDashboard();
                case 'station':
                  return const StationDashboard();
                default:
                  return const UserDashboard();
              }
            },
          ),
        );
      });
    } catch (e) {
      print('Error in direct navigation: $e');
      // Fallback to user dashboard
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const UserDashboard(),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.local_gas_station,
                  size: 150,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                Text(
                  loc.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  loc.welcomeBack,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: loc.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    labelText: loc.password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _signIn,
                    child: Text(
                      loc.login,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.forgotPasswordComingSoon)),
                    );
                  },
                  child: Text(loc.forgotPassword),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(loc.dontHaveAccount),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                        );
                      },
                      child: Text(
                        loc.signUp,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}