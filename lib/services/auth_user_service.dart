import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'app_api.dart';

/// The signed-in account.
class AppUser {
  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName,
    Map<String, dynamic>? row,
  }) : row = row ?? const {};

  final String uid;
  final String email;
  final String role; // 'user' | 'driver' | 'station'
  final String? displayName;

  /// Full snake_case profile row from the backend (license_plate,
  /// station_id, latitude, …). Missing keys → null.
  final Map<String, dynamic> row;

  String? get plate =>
      (row['license_plate'] as String?) ?? (row['vehicle_plate'] as String?);

  /// Primary phone number (login identifier). Falls back to phone_number.
  String get phone =>
      (row['phone']?.toString() ?? row['phone_number']?.toString() ?? '').trim();

  factory AppUser.fromRow(Map<String, dynamic> row) {
    return AppUser(
      uid: (row['uid'] ?? row['sub'] ?? '').toString(),
      email: (row['email'] ?? '').toString(),
      role: (row['role'] ?? 'user').toString().trim().toLowerCase(),
      displayName: row['display_name'] as String?,
      row: Map<String, dynamic>.from(row),
    );
  }
}

/// Authentication against the Next.js backend (JWT + bcrypt).
///
/// Static API surface kept compatible with the original service helpers:
///   getUserRole / getCurrentEmail / saveUserData / clearUserData
///   getCachedUserData
/// plus the new session helpers: currentUser, restoreSession, signIn,
/// signOut.
class AuthService {
  AuthService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static AppUser? _currentUser;
  static Future<AppUser?>? _restoreFuture;

  // ── cache (secure storage) ────────────────────────────────────────

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
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _roleKey);
  }

  // ── current session ───────────────────────────────────────────────

  /// The signed-in user (null when signed out / session not restored yet).
  static AppUser? get currentUser => _currentUser;

  static String? get currentUid => _currentUser?.uid;

  static String get currentEmail {
    final email = _currentUser?.email ?? '';
    return email.isNotEmpty ? email : (_currentUser?.phone.isEmpty ?? true ? '—' : _currentUser!.phone);
  }

  /// Restores the session from the stored JWT (one backend call, memoized).
  /// Returns null when signed out or the token expired (401).
  static Future<AppUser?> restoreSession({bool force = false}) {
    if (force) {
      _restoreFuture = null;
      _currentUser = null;
    }
    return _restoreFuture ??= _doRestore();
  }

  static Future<AppUser?> _doRestore() async {
    try {
      final token = await ApiClient.getToken();
      if (token == null || token.isEmpty) return null;

      final res = await AppApi.me();
      final user = AppUser.fromRow(
          Map<String, dynamic>.from(res['user'] as Map? ?? {}));
      if (user.uid.isEmpty) return null;

      _currentUser = user;
      await saveUserData(
        email: user.email.isNotEmpty ? user.email : user.phone,
        role: user.role,
      );
      return user;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // Stale/invalid token — drop it so we don't loop.
        await ApiClient.setToken(null);
        return null;
      }
      debugPrint('Session restore error: $e');
      return null;
    } catch (e) {
      debugPrint('Session restore error: $e');
      return null;
    }
  }

  /// Updates the in-memory user after a profile PATCH.
  static void updateCachedUser(Map<String, dynamic> userRow) {
    _currentUser = AppUser.fromRow(userRow);
  }

  // ── sign in / sign out ────────────────────────────────────────────

  static Future<AppUser> signIn({
    required String phone,
    required String password,
  }) async {
    final res = await AppApi.signIn(phone: phone, password: password);
    final user = AppUser.fromRow(
        Map<String, dynamic>.from(res['user'] as Map? ?? {}));
    _currentUser = user;
    _restoreFuture = Future.value(user);
    await saveUserData(
        email: user.email.isNotEmpty ? user.email : user.phone,
        role: user.role,
      );
    return user;
  }

  static Future<void> signOut() async {
    await AppApi.signOut(); // clears the stored JWT
    await clearUserData(); // clears cached email/role
    _currentUser = null;
    _restoreFuture = null;
  }

  // ── legacy helpers (kept signatures) ──────────────────────────────

  /// Returns 'guest' when signed out, otherwise the account role.
  static Future<String> getUserRole({bool forceRefresh = false}) async {
    final user = await restoreSession(force: forceRefresh);
    if (user == null) return 'guest';

    if (!forceRefresh) {
      final cached = await getCachedUserData();
      final cachedRole = cached['role'];
      if (cachedRole != null &&
          cachedRole.isNotEmpty &&
          cachedRole != 'guest' &&
          cachedRole == user.role) {
        return cachedRole;
      }
    }

    await saveUserData(
        email: user.email.isNotEmpty ? user.email : user.phone,
        role: user.role,
      );
    return user.role;
  }

  static Future<String> getCurrentEmail() async {
    if (_currentUser != null) return _currentUser!.email;
    final cached = await getCachedUserData();
    return cached['email'] ?? '—';
  }
}
