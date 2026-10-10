import '../constants/app_enums.dart';
import 'api_client.dart';

/// Typed wrapper around the Next.js backend (Prisma → Supabase).
///
/// Response shape convention (matches the old app's data access):
///  • SQL-backed rows (users, preorders, history, queues, stats) → snake_case
///  • Document-backed rows (locations, pumps, inventory…) → camelCase
///  • Dates are ISO-8601 strings → parse with `DateTime.tryParse(...)`
///  • 404 on a document GET resolves to `null` (doc didn't exist)
class AppApi {
  AppApi._();

  // ── Auth ───────────────────────────────────────────────────────────

  /// POST /api/auth/login → stores the JWT, returns {token, user}
  static Future<Map<String, dynamic>> signIn({
    required String phone,
    required String password,
  }) async {
    final res = await ApiClient.post(
      '/api/auth/login',
      body: {'phone': phone, 'password': password},
    );
    final token = res['token']?.toString();
    if (token != null) await ApiClient.setToken(token);
    return res;
  }

  /// GET /api/auth/me → {user} (throws 401 when the token is invalid)
  static Future<Map<String, dynamic>> me() =>
      ApiClient.get('/api/auth/me');

  /// GET /api/users/me → {user}
  static Future<Map<String, dynamic>> myProfile() =>
      ApiClient.get('/api/users/me');

  /// PATCH /api/users/me — partial snake_case update → {user}
  ///
  /// Fuel / vehicle values are normalised to the canonical enumerations
  /// (see `constants/app_enums.dart`) so the backend, driver, station and
  /// this app always speak the same values.
  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> fields) {
    final body = Map<String, dynamic>.from(fields);
    if (body.containsKey('fuel_types')) {
      body['fuel_types'] = normalizeFuelTypes(body['fuel_types']);
    }
    if (body.containsKey('fuel_type')) {
      body['fuel_type'] =
          normalizeFuelType(body['fuel_type']?.toString(), allowBoth: true) ??
              body['fuel_type'];
    }
    if (body.containsKey('vehicle_type')) {
      body['vehicle_type'] =
          normalizeVehicleType(body['vehicle_type']?.toString()) ??
              body['vehicle_type'];
    }
    return ApiClient.patch('/api/users/me', body: body);
  }

  static Future<void> signOut() => ApiClient.setToken(null);

  // ── Stations / users ───────────────────────────────────────────────

  /// GET /api/users/stations → [user rows…] (+ waiting_orders, today_waiting)
  static Future<List<Map<String, dynamic>>> stations({
    String? order,
    int? limit,
    bool activeOnly = true,
    bool withWaiting = false,
    bool todayWaiting = false,
  }) async {
    final res = await ApiClient.get('/api/users/stations', params: {
      if (order != null) 'order': order,
      if (limit != null) 'limit': limit,
      if (!activeOnly) 'active_only': 0,
      if (withWaiting) 'with_waiting': 1,
      if (todayWaiting) 'today_waiting': 1,
    });
    return ApiClient.items(res);
  }

  /// GET /api/users/station-by-email → {uid} | null (404)
  static Future<String?> stationByEmail(String email) async {
    try {
      final res =
          await ApiClient.get('/api/users/station-by-email', params: {'email': email});
      return res['uid']?.toString();
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// GET /api/stations/overview → merged station list (profile + map
  /// coords + pumps + waiting counts). Replaces the old N+1 doc-read loop.
  static Future<List<Map<String, dynamic>>> stationsOverview({
    int limit = 50,
    bool todayWaiting = false,
  }) async {
    final res = await ApiClient.get('/api/stations/overview', params: {
      'limit': limit,
      if (todayWaiting) 'today_waiting': 1,
    });
    return ApiClient.items(res);
  }

  /// POST /api/stations/bootstrap → {station_key} (creates station docs)
  static Future<String> bootstrapStation() async {
    final res = await ApiClient.post('/api/stations/bootstrap');
    return res['station_key']?.toString() ?? '';
  }

  // ── Locations map ──────────────────────────────────────────────────

  /// GET /api/locations → [location docs…]  (public — login-screen map)
  static Future<List<Map<String, dynamic>>> locations() async {
    final res = await ApiClient.get('/api/locations');
    return ApiClient.items(res);
  }

  /// PUT /api/locations/:stationId — merge upsert → {…location…}
  static Future<Map<String, dynamic>> upsertLocation(
    String stationId, {
    String? uid,
    String? name,
    String? address,
    String? phone,
    List<String>? fuelTypes,
    int? capacityLiters,
    double? latitude,
    double? longitude,
    bool? isActive,
  }) =>
      ApiClient.put('/api/locations/${Uri.encodeComponent(stationId)}', body: {
        if (uid != null) 'uid': uid,
        if (name != null) 'name': name,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (fuelTypes != null) 'fuelTypes': normalizeFuelTypes(fuelTypes),
        if (capacityLiters != null) 'capacityLiters': capacityLiters,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (isActive != null) 'isActive': isActive,
      });

  // ── Pre-orders ─────────────────────────────────────────────────────

  /// GET /api/preorders → [preorder rows…]
  static Future<List<Map<String, dynamic>>> preorders({
    String? stationId,
    String? driverUid,
    String? driverEmail,
    List<String>? statuses,
    String? from,
    String? to,
    bool today = false,
    String? order,
    int? limit,
  }) async {
    final res = await ApiClient.get('/api/preorders', params: {
      if (stationId != null) 'station_id': stationId,
      if (driverUid != null) 'driver_uid': driverUid,
      if (driverEmail != null) 'driver_email': driverEmail,
      if (statuses != null && statuses.isNotEmpty)
        'statuses': statuses.join(','),
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (today) 'today': 1,
      if (order != null) 'order': order,
      if (limit != null) 'limit': limit,
    });
    return ApiClient.items(res);
  }

  /// GET /api/preorders/:id → row | null (404)
  static Future<Map<String, dynamic>?> preorder(String id) async {
    try {
      return await ApiClient.get('/api/preorders/${Uri.encodeComponent(id)}');
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// POST /api/preorders → created row (snake_case body)
  static Future<Map<String, dynamic>> createPreorder(
      Map<String, dynamic> body) {
    final payload = Map<String, dynamic>.from(body);
    if (payload.containsKey('fuel_type')) {
      payload['fuel_type'] =
          normalizeFuelType(payload['fuel_type']?.toString()) ??
              payload['fuel_type'];
    }
    return ApiClient.post('/api/preorders', body: payload);
  }

  /// POST /api/preorders/transfer → new row (old order marked transferred)
  static Future<Map<String, dynamic>> transferPreorder(
          Map<String, dynamic> body) =>
      ApiClient.post('/api/preorders/transfer', body: body);

  /// POST /api/preorders/:id/complete → {success}
  static Future<Map<String, dynamic>> completePreorder(
          String id, String confirmationCode) =>
      ApiClient.post('/api/preorders/${Uri.encodeComponent(id)}/complete',
          body: {'confirmation_code': confirmationCode});

  /// POST /api/preorders/:id/archive → {success} (moves to history)
  static Future<Map<String, dynamic>> archivePreorder(
          String id, String confirmationCode) =>
      ApiClient.post('/api/preorders/${Uri.encodeComponent(id)}/archive',
          body: {'confirmation_code': confirmationCode});

  /// GET /api/preorders/count → {count}
  static Future<int> countPreorders({
    required String stationId,
    List<String>? statuses,
    String? from,
    String? before,
    bool sameDay = false,
  }) async {
    final res = await ApiClient.get('/api/preorders/count', params: {
      'station_id': stationId,
      if (statuses != null && statuses.isNotEmpty)
        'statuses': statuses.join(','),
      if (from != null) 'from': from,
      if (before != null) 'before': before,
      if (sameDay) 'same_day': 1,
    });
    return (res['count'] as num?)?.toInt() ?? 0;
  }

  /// GET /api/preorders/driver-day-count → {count} (active + history)
  static Future<int> driverDayOrderCount({
    required String driverPlate,
    String? from,
    String? to,
  }) async {
    final res = await ApiClient.get('/api/preorders/driver-day-count', params: {
      'driver_plate': driverPlate,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return (res['count'] as num?)?.toInt() ?? 0;
  }

  // ── History ────────────────────────────────────────────────────────

  /// GET /api/history → [history rows…]
  static Future<List<Map<String, dynamic>>> history({
    String? stationId,
    String? driverPlate,
    String? from,
    bool today = false,
    int? limit,
    String? order,
    String? status,
  }) async {
    final res = await ApiClient.get('/api/history', params: {
      if (stationId != null) 'station_id': stationId,
      if (driverPlate != null) 'driver_plate': driverPlate,
      if (from != null) 'from': from,
      if (today) 'today': 1,
      if (limit != null) 'limit': limit,
      if (order != null) 'order': order,
      if (status != null) 'status': status,
    });
    return ApiClient.items(res);
  }

  /// GET /api/history/today-count → {count}
  static Future<int> todayCompletedCount(String stationId) async {
    final res =
        await ApiClient.get('/api/history/today-count', params: {'station_id': stationId});
    return (res['count'] as num?)?.toInt() ?? 0;
  }

  // ── Physical queue ─────────────────────────────────────────────────

  /// GET /api/queues?station_id= → [queue rows…]
  static Future<List<Map<String, dynamic>>> queues(String stationId) async {
    final res = await ApiClient.get('/api/queues', params: {'station_id': stationId});
    return ApiClient.items(res);
  }

  /// POST /api/queues → created row
  static Future<Map<String, dynamic>> joinQueue({
    required String stationId,
    required String driverName,
    required String vehiclePlate,
    required String fuelType,
    required String vehicleType,
  }) =>
      ApiClient.post('/api/queues', body: {
        'station_id': stationId,
        'driver_name': driverName,
        'vehicle_plate': vehiclePlate,
        'fuel_type':
            normalizeFuelType(fuelType, allowBoth: true) ?? fuelType,
        'vehicle_type': normalizeVehicleType(vehicleType) ?? vehicleType,
      });

  // ── Station home stats ─────────────────────────────────────────────

  /// GET /api/stats/station → dashboard numbers (snake_case)
  static Future<Map<String, dynamic>> stationStats(String stationId) async {
    try {
      return await ApiClient.get('/api/stats/station', params: {'station_id': stationId});
    } on ApiException catch (e) {
      if (e.isNotFound) return <String, dynamic>{};
      rethrow;
    }
  }

  // ── Pumps document ─────────────────────────────────────────────────

  /// GET /api/stations/pumps → doc | null (404)
  static Future<Map<String, dynamic>?> pumpsDoc(String stationKey) async {
    try {
      return await ApiClient.get('/api/stations/pumps',
          params: {'station_key': stationKey});
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// PUT /api/stations/pumps — merge upsert → {…doc…}
  static Future<Map<String, dynamic>> savePumpsDoc(
          Map<String, dynamic> body) =>
      ApiClient.put('/api/stations/pumps', body: body);

  // ── Station summary document ───────────────────────────────────────

  /// GET /api/stations/docs?id= → doc | null (404)
  static Future<Map<String, dynamic>?> stationDoc(String id) async {
    try {
      return await ApiClient.get('/api/stations/docs', params: {'id': id});
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// PUT /api/stations/docs — merge upsert → {…doc…}
  static Future<Map<String, dynamic>> saveStationDoc(
          Map<String, dynamic> body) =>
      ApiClient.put('/api/stations/docs', body: body);

  // ── Station fuel inventory document (manage page) ──────────────────

  /// GET /api/station-inventory?station_key= → doc | null (404)
  static Future<Map<String, dynamic>?> stationInventory(
      String stationKey) async {
    try {
      return await ApiClient.get('/api/station-inventory',
          params: {'station_key': stationKey});
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// PUT /api/station-inventory — merge upsert → {…doc…}
  static Future<Map<String, dynamic>> saveStationInventory(
          Map<String, dynamic> body) =>
      ApiClient.put('/api/station-inventory', body: body);

  // ── Announcements / reports documents ──────────────────────────────

  /// GET /api/announcements → {announcements: []}  ([] when missing)
  static Future<List<dynamic>> announcements(String stationKey) async {
    final res = await ApiClient.get('/api/announcements',
        params: {'station_key': stationKey});
    return (res['announcements'] as List?) ?? const [];
  }

  /// PUT /api/announcements → {announcements}
  static Future<List<dynamic>> saveAnnouncements(
    String stationKey,
    List<dynamic> announcements,
  ) async {
    final res = await ApiClient.put('/api/announcements', body: {
      'station_key': stationKey,
      'announcements': announcements,
    });
    return (res['announcements'] as List?) ?? const [];
  }

  /// GET /api/reports → {reports: []}  ([] when missing)
  static Future<List<dynamic>> reports(String stationKey) async {
    final res = await ApiClient.get('/api/reports', params: {'station_key': stationKey});
    return (res['reports'] as List?) ?? const [];
  }

  /// PUT /api/reports → {reports}
  static Future<List<dynamic>> saveReports(
    String stationKey,
    List<dynamic> reports,
  ) async {
    final res = await ApiClient.put('/api/reports', body: {
      'station_key': stationKey,
      'reports': reports,
    });
    return (res['reports'] as List?) ?? const [];
  }

  // ── Problem reports (driver → station) ─────────────────────────────

  /// POST /api/problem-reports → creates report + station notification
  static Future<Map<String, dynamic>> submitProblemReport({
    String? stationId,
    String? stationName,
    required String problemType,
    String? description,
  }) =>
      ApiClient.post('/api/problem-reports', body: {
        if (stationId != null) 'station_id': stationId,
        if (stationName != null) 'station_name': stationName,
        'problem_type': problemType,
        if (description != null) 'description': description,
      });

  // ── Notifications ──────────────────────────────────────────────────

  /// GET /api/notifications?user_id= → [notification rows…]
  static Future<List<Map<String, dynamic>>> notifications(String userId) async {
    final res = await ApiClient.get('/api/notifications', params: {'user_id': userId});
    return ApiClient.items(res);
  }

  // ── Union applications ─────────────────────────────────────────────

  /// GET /api/union-applications → {application: row | null}
  static Future<Map<String, dynamic>?> myUnionApplication() async {
    final res = await ApiClient.get('/api/union-applications');
    final app = res['application'];
    if (app is Map<String, dynamic>) return app;
    return null;
  }

  /// POST /api/union-applications → {application} (upsert)
  static Future<Map<String, dynamic>?> submitUnionApplication(
      Map<String, dynamic> body) async {
    final payload = Map<String, dynamic>.from(body);
    if (payload.containsKey('vehicle_type')) {
      payload['vehicle_type'] =
          normalizeVehicleType(payload['vehicle_type']?.toString()) ??
              payload['vehicle_type'];
    }
    final res = await ApiClient.post('/api/union-applications', body: payload);
    final app = res['application'];
    if (app is Map<String, dynamic>) return app;
    return null;
  }
}
