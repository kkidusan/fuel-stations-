import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../services/api_client.dart';
import '../../services/app_api.dart';

import 'dart:math' show sin, cos, sqrt, atan2;

class LocationMapFullScreen extends StatefulWidget {
  final Position? initialPosition;

  const LocationMapFullScreen({super.key, this.initialPosition});

  @override
  State<LocationMapFullScreen> createState() => _LocationMapFullScreenState();
}

class _LocationMapFullScreenState extends State<LocationMapFullScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  List<Map<String, dynamic>> _nearbyStations = [];
  bool _stationsLoading = true;
  bool _locationLoading = false;

  static const double MAX_DISTANCE_KM = 25.0;

  @override
  void initState() {
    super.initState();

    if (widget.initialPosition != null) {
      _currentPosition = widget.initialPosition;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerOnPosition(widget.initialPosition!);
      });
      _loadNearbyStations(widget.initialPosition!);
    } else {
      _getCurrentLocation();
    }
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m';
    return '${km.toStringAsFixed(1)} km';
  }

  Future<void> _loadNearbyStations(Position userPos) async {
    try {
      final rows = await AppApi.locations();

      final List<Map<String, dynamic>> loaded = [];

      for (final data in rows) {
        // Skip inactive locations (keeps the old isActive filter behavior).
        if (data['isActive'] == false) continue;

        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final distance = _haversineDistance(
          userPos.latitude,
          userPos.longitude,
          lat,
          lng,
        );

        if (distance <= MAX_DISTANCE_KM) {
          loaded.add({
            'id': data['id']?.toString(),
            'name': data['name'] as String? ?? 'Station',
            'lat': lat,
            'lng': lng,
            'distanceKm': distance,
            'distanceText': _formatDistance(distance),
          });
        }
      }

      loaded.sort((a, b) => (a['distanceKm'] as double).compareTo(b['distanceKm'] as double));

      if (mounted) {
        setState(() {
          _nearbyStations = loaded;
          _stationsLoading = false;
        });
      }
    } on ApiException catch (e) {
      debugPrint("Error loading stations: ${e.message}");
      if (mounted) setState(() => _stationsLoading = false);
    } catch (e, stack) {
      debugPrint("Error loading stations: $e\n$stack");
      if (mounted) setState(() => _stationsLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _locationLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions permanently denied. Open settings.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _locationLoading = false;
        });
        _centerOnPosition(position);
        _loadNearbyStations(position);
      }
    } catch (e) {
      debugPrint("Location error: $e");
      if (mounted) {
        setState(() => _locationLoading = false);
      }
    }
  }

  void _centerOnPosition(Position pos) {
    _mapController.move(LatLng(pos.latitude, pos.longitude), 14.0);
  }

  void _showStationInfo(Map<String, dynamic> station) {
    final distanceText = station['distanceText'] as String? ?? '? km';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    station['name'] as String,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.straighten, color: Colors.green),
                title: Text(
                  'Distance from you',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                subtitle: Text(
                  distanceText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // You can add more info later: address, fuel status, queue, navigate button...
              FilledButton.icon(
                onPressed: () {
                  // Optional: open navigation / go to queue page
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Navigation to ${station['name']} coming soon')),
                  );
                },
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialPos = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(9.03, 38.74); // Addis Ababa fallback

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const CircleAvatar(
            backgroundColor: Colors.black54,
            child: Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentPosition != null)
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.my_location, color: Colors.white),
              ),
              onPressed: () => _centerOnPosition(_currentPosition!),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialPos,
              initialZoom: 13.5,
              interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.gas',
              ),
              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      width: 52,
                      height: 52,
                      child: const _PulsingMarker(),
                    ),
                  ..._nearbyStations.map((station) {
                    return Marker(
                      point: LatLng(station['lat'] as double, station['lng'] as double),
                      width: 48,
                      height: 60,
                      child: GestureDetector(
                        onTap: () => _showStationInfo(station),
                        child: _GreenStationMarker(name: station['name'] as String),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          if (_stationsLoading)
            const Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  color: Colors.black54,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Loading stations...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_locationLoading)
            const Center(
              child: Card(
                color: Colors.black54,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('Getting location...', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _locationLoading
            ? null
            : (_currentPosition != null ? () => _centerOnPosition(_currentPosition!) : _getCurrentLocation),
        child: _locationLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              )
            : const Icon(Icons.my_location),
      ),
    );
  }
}

// Keep your existing marker widgets
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

class _GreenStationMarker extends StatelessWidget {
  final String name;

  const _GreenStationMarker({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.35),
                boxShadow: [
                  BoxShadow(color: Colors.green.withOpacity(0.6), blurRadius: 12, spreadRadius: 2),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18), bottom: Radius.circular(4)),
                border: Border.all(color: Colors.white70, width: 2.2),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 4))],
              ),
              child: const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 24),
            ),
            Positioned(
              bottom: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green.shade900),
              ),
            ),
          ],
        ),
        // Small distance label under marker (optional – you can remove if too crowded)
        // Container(
        //   margin: const EdgeInsets.only(top: 4),
        //   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        //   decoration: BoxDecoration(
        //     color: Colors.black.withOpacity(0.65),
        //     borderRadius: BorderRadius.circular(12),
        //   ),
        //   child: Text(
        //     distanceText,
        //     style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        //   ),
        // ),
      ],
    );
  }
}