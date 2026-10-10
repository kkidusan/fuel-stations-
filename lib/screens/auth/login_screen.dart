import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../services/api_client.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';
import '../../services/location_service.dart';
import '../../widgets/phone_input.dart';
import 'location_map_full_screen.dart';
import 'station_search_screen.dart';

// ────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onSignedIn});

  /// Called by the login sheet after a successful authentication so
  /// AuthWrapper can restore the session and navigate.
  final VoidCallback? onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String _currentLanguage = 'en';
  Position? _userPosition;
  bool _isLocating = false;
  String? _locationError;

  // ── Station search ────────────────────────────────────────────────
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _allStations = [];
  Map<String, dynamic>? _selectedStation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryGetLocation();
      _loadStations();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String _translate(String en, String am) {
    return _currentLanguage == 'en' ? en : am;
  }

  Future<void> _loadStations() async {
    try {
      final rows = await AppApi.locations();
      final List<Map<String, dynamic>> loaded = [];
      for (final data in rows) {
        if (data['isActive'] == false) continue;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final address = (data['address'] ?? data['city'])?.toString().trim();
        loaded.add({
          'id': data['id']?.toString(),
          'name': data['name'] as String? ?? 'Station',
          'address': (address == null || address.isEmpty) ? null : address,
          'lat': lat,
          'lng': lng,
        });
      }
      if (mounted) setState(() => _allStations = loaded);
    } catch (_) {
      // Search simply stays empty if stations can't be loaded.
    }
  }

  /// Opens the full-screen station search. When a station is chosen the map
  /// jumps to it and a red pin is dropped.
  Future<void> _openStationSearch() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => StationSearchScreen(
          initialStations: _allStations,
          language: _currentLanguage,
        ),
      ),
    );
    if (!mounted || result == null) return;
    _selectStation(result);
  }

  void _selectStation(Map<String, dynamic> station) {
    setState(() => _selectedStation = station);
    _mapController.move(
      LatLng(station['lat'] as double, station['lng'] as double),
      15.0,
    );
  }

  void _clearSearch() {
    setState(() => _selectedStation = null);
  }

  Future<void> _tryGetLocation({bool force = false}) async {
    if (!mounted) return;
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      final permission = await LocationService.checkAndRequestPermission(
        context,
        _currentLanguage,
        forceRequest: force,
      );
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw Exception('permission_denied');
      }

      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _userPosition = pos;
          _isLocating = false;
        });
      }
    } catch (e) {
      String? msg;
      if (e.toString().contains('permission_denied')) {
        msg = _translate('Location permission is required', 'የቦታ ፍቃድ ያስፈልጋል');
      } else if (e is TimeoutException) {
        msg = _translate('Location timed out – try again', 'ቦታ መውሰድ ጊዜው አለፈ – እንደገና ይሞክሩ');
      } else {
        msg = _translate('Could not get location. Check GPS.', 'ቦታ ማግኘት አልተቻለም። ጂፒኤስ ያረጋግጡ።');
      }

      if (mounted) {
        setState(() {
          _locationError = msg;
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _showLoginBottomSheet() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.68),
      builder: (_) => _LoginFormBottomSheet(onSuccess: widget.onSignedIn),
    );
    if (mounted) setState(() => _isLoading = false);
  }

  // Map-only view (no tabs, no station list).
  Widget _buildMap() {
    if (_isLocating) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF32CD32)),
            SizedBox(height: 20),
            Text('Locating...', style: TextStyle(color: Color(0xFF6B6B6B))),
          ],
        ),
      );
    }

    if (_locationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_disabled, size: 90, color: Colors.deepOrange),
              const SizedBox(height: 24),
              Text(
                _locationError!,
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => _tryGetLocation(force: true),
                icon: const Icon(Icons.my_location, color: Color(0xFF1C1C1E)),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1C1C1E),
                  side: const BorderSide(color: Color(0xFFB0B8B2), width: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_userPosition == null) {
      return const Center(
        child: Text('No location available', style: TextStyle(color: Color(0xFF6B6B6B))),
      );
    }

    final position = _userPosition!;

    void openFullMap() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocationMapFullScreen(initialPosition: position),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: openFullMap,
          child: AbsorbPointer(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(position.latitude, position.longitude),
                initialZoom: 13.5,
                interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.rotate),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.fuelapp',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(position.latitude, position.longitude),
                      width: 52,
                      height: 52,
                      child: const _PulsingMarker(),
                    ),
                    if (_selectedStation != null)
                      Marker(
                        point: LatLng(
                          _selectedStation!['lat'] as double,
                          _selectedStation!['lng'] as double,
                        ),
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFFD32F2F),
                          size: 42,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Bottom hint – tap anywhere on the map to open the full map.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onTap: openFullMap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _translate('Your location – tap for full map', 'የእርስዎ ቦታ – ሙሉ ካርታ ለመክፈት መታ ያድርጉ'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.fullscreen, color: Colors.white70, size: 22),
                ],
              ),
            ),
          ),
        ),
        // Station search (centered) + language switcher.
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: _buildSearchOverlay(),
        ),
      ],
    );
  }

  Widget _buildSearchOverlay() {
    final selectedName = _selectedStation?['name'] as String?;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            elevation: 4,
            shadowColor: Colors.black45,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: _openStationSearch,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF1C1C1E)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        selectedName ?? _translate('Search station...', 'ጣቢያ ይፈልጉ...'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          color: selectedName == null
                              ? const Color(0xFF8A8A8E)
                              : const Color(0xFF1C1C1E),
                          fontWeight:
                              selectedName == null ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_selectedStation != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _clearSearch,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.close, color: Color(0xFF1C1C1E), size: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildLanguageButton(),
      ],
    );
  }

  Widget _buildLanguageButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _currentLanguage,
          icon: const Icon(Icons.language, color: Color(0xFF1C1C1E)),
          items: const [
            DropdownMenuItem(value: 'en', child: Text('EN')),
            DropdownMenuItem(value: 'am', child: Text('አማ')),
          ],
          onChanged: (v) {
            if (v != null && mounted) setState(() => _currentLanguage = v);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0F8F4), Color(0xFFE8F5EA)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildMap(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 16, 40, 32),
                child: FilledButton(
                  onPressed: _isLoading ? null : _showLoginBottomSheet,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF32CD32),
                    foregroundColor: const Color(0xFF1C1C1E),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.8,
                            color: Color(0xFF1C1C1E),
                          ),
                        )
                      : Text(
                          _translate('Sign In', 'ግባ'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingMarker extends StatelessWidget {
  const _PulsingMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.4)),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: const Icon(Icons.person_pin_circle, color: Color(0xFF1976D2), size: 34),
        ),
      ],
    );
  }
}

class _LoginFormBottomSheet extends StatefulWidget {
  const _LoginFormBottomSheet({this.onSuccess});

  /// Invoked after a successful sign-in (the sheet pops itself first).
  final VoidCallback? onSuccess;

  @override
  State<_LoginFormBottomSheet> createState() => _LoginFormBottomSheetState();
}

class _LoginFormBottomSheetState extends State<_LoginFormBottomSheet> {
  final _phone = PhoneController();
  final _passwordController = TextEditingController();
  final _loading = ValueNotifier<bool>(false);
  final _error = ValueNotifier<String?>(null);
  bool _obscure = true;

  @override
  void dispose() {
    _phone.dispose();
    _passwordController.dispose();
    _loading.dispose();
    _error.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final phone = _phone.fullPhone;
    final pass = _passwordController.text.trim();

    if (_phone.isEmpty || pass.isEmpty) {
      _error.value = 'Phone number and password required';
      return;
    }

    _loading.value = true;
    _error.value = null;

    try {
      await AuthService.signIn(phone: phone, password: pass);

      if (!mounted) return;

      // Close the sheet — AuthWrapper restores the session and routes by role.
      Navigator.pop(context);
      widget.onSuccess?.call();
    } on ApiException catch (e) {
      _error.value = switch (e.code) {
        'user_not_found' => 'No account with this phone number',
        'wrong_password' => 'Incorrect password',
        'invalid_phone' || 'phone_exists' => 'Invalid phone number',
        'invalid_email' || 'validation' => 'Invalid phone number or password',
        'network' => 'Could not reach the server. Check your connection.',
        _ => e.message,
      };
    } catch (_) {
      _error.value = 'Something went wrong';
    } finally {
      if (mounted) _loading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // A modal bottom sheet is anchored to the bottom of the screen and is NOT
    // resized automatically when the keyboard opens, so we (1) lift the whole
    // sheet by the keyboard height and (2) never let it grow taller than the
    // space that is actually visible above the keyboard / below the status bar.
    final keyboard = media.viewInsets.bottom;
    final topInset = media.padding.top;
    final screenHeight = media.size.height;

    final available = screenHeight - keyboard - topInset - 8;
    final preferred = screenHeight * 0.60;
    final sheetHeight = preferred < available ? preferred : available;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(top: 16, bottom: 8),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(999)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Welcome Back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              ),
              // The body scrolls, so when the keyboard shrinks the sheet the
              // focused phone/password field is always brought into view.
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PhoneField(
                        controller: _phone,
                        label: 'Phone Number',
                        hint: '9xx xxx xxx',
                        textInputAction: TextInputAction.next,
                        borderRadius: 16,
                        fillColor: const Color(0xFFF0F8F4),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _signIn(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: const Color(0xFFF0F8F4),
                        ),
                      ),
                      ValueListenableBuilder<String?>(
                        valueListenable: _error,
                        builder: (_, err, __) {
                          if (err == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              err,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      ValueListenableBuilder<bool>(
                        valueListenable: _loading,
                        builder: (_, loading, __) {
                          return FilledButton(
                            onPressed: loading ? null : _signIn,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              backgroundColor: const Color(0xFF32CD32),
                              foregroundColor: const Color(0xFF1C1C1E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(color: Color(0xFF1C1C1E), strokeWidth: 2.5),
                                  )
                                : const Text('Sign In', style: TextStyle(fontSize: 17)),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Forgot password — coming soon')),
                          );
                        },
                        child: const Text('Forgot password?'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
