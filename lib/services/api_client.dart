import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Error thrown for any non-2xx backend response.
class ApiException implements Exception {
  ApiException(this.message, {this.status = 0, this.code});

  final String message;
  final int status;
  final String? code;

  bool get isUnauthorized => status == 401;
  bool get isNotFound => status == 404;

  @override
  String toString() => message;
}

/// Thin HTTP client for the Next.js backend.
///
///  • Base URL comes from `.env` → `API_BASE_URL`
///  • The JWT is stored in flutter_secure_storage and attached automatically
///  • Every method returns a decoded JSON **map**; list endpoints return the
///    bare JSON array under the `data` key (see [items]).
class ApiClient {
  ApiClient._();

  /// Singleton (all methods are static-friendly; kept instantiable for
  /// callers that hold a reference like `AppApi`).
  static final ApiClient instance = ApiClient._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String tokenKey = 'auth_token';

  static String get baseUrl {
    // 1. --dart-define=API_BASE_URL=... wins. This is how a real phone is
    //    pointed at this PC:
    //      flutter run --dart-define=API_BASE_URL=http://192.168.x.x:4000
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return _noTrailingSlash(fromDefine);

    // 2. Fall back to .env → API_BASE_URL (Android emulator default).
    return _noTrailingSlash(
        dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:4000');
  }

  static String _noTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  // ── token storage ────────────────────────────────────────────────
  static Future<String?> getToken() => _storage.read(key: tokenKey);

  static Future<void> setToken(String? token) async {
    if (token == null) {
      await _storage.delete(key: tokenKey);
    } else {
      await _storage.write(key: tokenKey, value: token);
    }
  }

  // ── verbs ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> get(String path,
          {Map<String, dynamic>? params}) =>
      _request('GET', path, params: params);

  static Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _request('POST', path, body: body);

  static Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _request('PUT', path, body: body);

  static Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _request('PATCH', path, body: body);

  static Future<Map<String, dynamic>> delete(String path, {Object? body}) =>
      _request('DELETE', path, body: body);

  /// Extract a JSON array returned as the raw response body.
  /// List endpoints return bare arrays — the client wraps them as `data`.
  static List<Map<String, dynamic>> items(Map<String, dynamic> response) {
    final raw = response['data'];
    if (raw is List) {
      return raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    }
    return const [];
  }

  // ── internals ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? params,
    Object? body,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (params != null && params.isNotEmpty) {
      uri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...params.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      });
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    const timeout = Duration(seconds: 25);
    http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: headers).timeout(timeout);
          break;
        case 'POST':
          res = await http
              .post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(timeout);
          break;
        case 'PUT':
          res = await http
              .put(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(timeout);
          break;
        case 'PATCH':
          res = await http
              .patch(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(timeout);
          break;
        case 'DELETE':
          res = await http
              .delete(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(timeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      // Socket/timeout errors → friendly message with the URL we tried.
      throw ApiException(
        'Could not reach the server at $baseUrl.\n'
        'Check your connection and make sure the backend '
        '(npm run dev in backend/) is running on port 4000.',
        status: 0,
        code: 'network',
      );
    }

    // Decode body (bare arrays are wrapped so callers always get a map).
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else if (decoded is List) {
        data = {'data': decoded};
      } else if (decoded != null) {
        data = {'data': decoded};
      }
    } catch (_) {
      // empty/non-JSON body is fine for 204-style responses
    }

    if (res.statusCode >= 400) {
      throw ApiException(
        data['error']?.toString() ?? 'Request failed (${res.statusCode})',
        status: res.statusCode,
        code: data['code']?.toString(),
      );
    }

    return data;
  }
}
