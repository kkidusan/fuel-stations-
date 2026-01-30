import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _emailKey = 'user_email';
  static const String _roleKey = 'user_role';

  static Future<void> saveUserData({
    required String email,
    required String role,
  }) async {
    await _storage.write(key: _emailKey, value: email.trim());
    await _storage.write(key: _roleKey, value: role.trim().toLowerCase());
  }

  static Future<Map<String, String?>> getCachedUserData() async {
    final email = await _storage.read(key: _emailKey);
    final role = await _storage.read(key: _roleKey);
    return {'email': email, 'role': role};
  }

  static Future<void> clearUserData() async {
    await _storage.deleteAll();
  }

  /// Returns the role ('user', 'driver', 'station', etc.)
  static Future<String> getUserRole({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'guest';

    if (!forceRefresh) {
      final cached = await getCachedUserData();
      final cachedRole = cached['role'];
      if (cachedRole != null && cachedRole.isNotEmpty && cachedRole != 'guest') {
        return cachedRole;
      }
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final role = (data['role'] as String?)?.trim().toLowerCase();

        if (role != null && role.isNotEmpty) {
          await saveUserData(email: user.email ?? '', role: role);
          return role;
        }
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
    }

    // Fallback
    await saveUserData(email: user.email ?? '', role: 'user');
    return 'user';
  }

  static Future<String> getCurrentEmail() async {
    final cached = await getCachedUserData();
    return cached['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '—';
  }
}