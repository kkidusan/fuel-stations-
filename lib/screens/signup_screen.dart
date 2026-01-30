import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedRole;
  bool _loading = false;
  String? _errorMessage;

  final List<String> _roles = ['user', 'driver', 'station'];

  Future<String?> _generateStationId() async {
    final firestore = FirebaseFirestore.instance;
    final counterRef = firestore.collection('counters').doc('station_id_counter');

    return await firestore.runTransaction<String?>((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int lastNumber = 0;
      if (snapshot.exists) {
        lastNumber = snapshot.data()?['lastNumber'] ?? 0;
      }

      final nextNumber = lastNumber + 1;
      final padded = nextNumber.toString().padLeft(4, '0');
      final newId = 'FS_WLD_$padded';

      // Optional: verify this ID doesn't already exist (extra safety)
      final existing = await firestore
          .collection('users')
          .where('stationId', isEqualTo: newId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Rare collision — in real app you might retry with +2, etc.
        throw Exception('ID collision detected - please try again');
      }

      // Update counter
      transaction.set(
        counterRef,
        {'lastNumber': nextNumber},
        SetOptions(merge: true),
      );

      return newId;
    });
  }

  Future<void> _signUp() async {
    final loc = AppLocalizations.of(context)!;

    // ── Basic validation ────────────────────────────────────────
    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      setState(() => _errorMessage = loc.passwordsDoNotMatch);
      return;
    }

    if (_selectedRole == null) {
      setState(() => _errorMessage = loc.pleaseSelectRole);
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Create user in Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception('User creation failed');

      // Prepare base user data
      final userData = <String, dynamic>{
        'uid': uid,
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // ── Special handling for station role ───────────────────────
      if (_selectedRole == 'station') {
        final stationId = await _generateStationId();
        if (stationId == null) {
          throw Exception('Failed to generate station ID');
        }
        userData['stationId'] = stationId;
        // You can also add: userData['stationName'] = null, etc. if needed later
      }

      // Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);

      // IMPORTANT: Do NOT navigate here!
      // AuthWrapper / StreamBuilder should handle redirection automatically

    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? loc.authenticationError;
      });
    } on FirebaseException catch (e) {
      setState(() {
        _errorMessage = '${loc.firestoreError}: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = '${loc.unexpectedError}: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.signUp)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: loc.email,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: loc.password,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: loc.confirmPassword,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 32),

              Text(
                loc.selectYourRole,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              Column(
                children: _roles.map((role) {
                  return ListTile(
                    title: Text(_formatRole(role)),
                    leading: Radio<String>(
                      value: role,
                      groupValue: _selectedRole,
                      onChanged: _loading
                          ? null
                          : (String? value) {
                              if (value != null) {
                                setState(() {
                                  _selectedRole = value;
                                  _errorMessage = null;
                                });
                              }
                            },
                    ),
                    onTap: _loading
                        ? null
                        : () {
                            setState(() {
                              _selectedRole = role;
                              _errorMessage = null;
                            });
                          },
                  );
                }).toList(),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 40),

              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _signUp,
                  child: Text(loc.signUp, style: const TextStyle(fontSize: 17)),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'user':
        return 'Passenger / User';
      case 'driver':
        return 'Driver';
      case 'station':
        return 'Fuel Station / Company';
      default:
        return role;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}