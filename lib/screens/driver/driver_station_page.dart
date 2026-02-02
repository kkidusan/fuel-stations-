import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverStationPage extends StatefulWidget {
  const DriverStationPage({super.key});

  @override
  State<DriverStationPage> createState() => _DriverStationPageState();
}

class _DriverStationPageState extends State<DriverStationPage> {
  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _filteredStations = [];
  bool _isLoading = true;
  bool _showMap = false;
  Position? _currentPosition;
  String _currentAddress = 'Fetching location...';
  double _filterRadius = 15.0; // Default 15km radius
  String _selectedFuelType = 'All';
  List<String> _fuelTypes = ['All', 'Petrol', 'Diesel', 'CNG', 'Electric'];
  Map<String, int> _stationWaitingCounts = {};
  bool _locationPermissionGranted = false;
  bool _locationServiceEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadStations();
  }

  Future<void> _initializeLocation() async {
    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      debugPrint('=== Starting location request ===');

      // Check if location services are enabled
      _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('Location service enabled: $_locationServiceEnabled');

      if (!_locationServiceEnabled) {
        setState(() {
          _currentAddress = 'Please enable GPS/Location services';
        });
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('Current permission status: $permission');

      if (permission == LocationPermission.denied) {
        debugPrint('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        debugPrint('Permission after request: $permission');

        if (permission == LocationPermission.denied) {
          setState(() {
            _currentAddress = 'Location permission denied. Please enable in app settings.';
            _locationPermissionGranted = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentAddress = 'Location permission permanently denied. Please enable manually in app settings.';
          _locationPermissionGranted = false;
        });
        return;
      }

      // If we have permission
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        
        _locationPermissionGranted = true;
        debugPrint('Getting current position...');

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        ).timeout(const Duration(seconds: 15));
        
        debugPrint('Got position: ${position.latitude}, ${position.longitude}');

        // Get address from coordinates
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );

          String address = "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
          
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            address = place.locality != null && place.country != null
                ? "${place.locality}, ${place.country}"
                : address;
          }

          setState(() {
            _currentPosition = position;
            _currentAddress = address;
          });
          
          // Calculate distances after getting location
          _calculateDistances();
        } catch (e) {
          debugPrint('Error getting address: $e');
          setState(() {
            _currentPosition = position;
            _currentAddress = "Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
          });
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('Location timeout: $e');
      setState(() {
        _currentAddress = 'Location request timed out. Please try again.';
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _currentAddress = 'Unable to get location. Please check permissions.';
      });
    }
  }

  Future<void> _loadStations() async {
    try {
      final stationsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'station')
          .where('isActive', isEqualTo: true)
          .limit(20)
          .get();

      List<Map<String, dynamic>> stations = [];
      
      for (var doc in stationsSnapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? 'Unknown Station';
        final address = data['address'] as String? ?? 'No address provided';
        final autoID = data['autoID'] as String?;
        final stationId = _getStationId(doc.id, autoID);
        
        // Get station details from station_profiles or fuel_stations
        final stationDetails = await _getStationDetails(stationId);
        
        // Get pumps info
        final pumpsDoc = await FirebaseFirestore.instance
            .collection('station_pumps')
            .doc(stationId)
            .get();
        
        int availablePumps = 0;
        int totalPumps = 0;
        List<String> fuelTypes = [];
        double? latitude;
        double? longitude;
        String phone = 'N/A';
        bool isOpen = data['isOpen'] as bool? ?? true;
        
        // Get coordinates from station details
        if (stationDetails != null) {
          latitude = stationDetails['latitude']?.toDouble() ?? 0.0;
          longitude = stationDetails['longitude']?.toDouble() ?? 0.0;
          phone = stationDetails['phoneNumber'] as String? ?? 'N/A';
        }
        
        if (pumpsDoc.exists) {
          final pumpsData = pumpsDoc.data();
          final pumps = List<Map<String, dynamic>>.from(pumpsData?['pumps'] ?? []);
          totalPumps = pumps.length;
          
          for (var pump in pumps) {
            final status = pump['status']?.toString() ?? 'unknown';
            final isActive = pump['isActive'] ?? true;
            final fuelType = pump['fuelType']?.toString() ?? 'Unknown';
            
            if (status == 'available' && isActive == true) {
              availablePumps++;
            }
            
            if (!fuelTypes.contains(fuelType)) {
              fuelTypes.add(fuelType);
            }
          }
        }

        // Get today's waiting count
        final waitingCount = await _getTodayWaitingCount(stationId);
        _stationWaitingCounts[stationId] = waitingCount;
        
        stations.add({
          'id': stationId,
          'name': name,
          'address': address,
          'phone': phone,
          'rating': 4.5,
          'totalPumps': totalPumps,
          'availablePumps': availablePumps,
          'fuelTypes': fuelTypes,
          'isOpen': isOpen,
          'openingTime': '06:00',
          'closingTime': '22:00',
          'latitude': latitude ?? 0.0,
          'longitude': longitude ?? 0.0,
          'distance': 0.0,
          'waitingCount': waitingCount,
          'isRecommended': name.toLowerCase().contains('total') ||
              name.toLowerCase().contains('noc') ||
              name.toLowerCase().contains('mis'),
        });
      }

      setState(() {
        _stations = stations;
        _filteredStations = stations;
        _isLoading = false;
      });

      // Calculate distances if we have location
      if (_currentPosition != null) {
        _calculateDistances();
      }
    } catch (e) {
      debugPrint('Error loading stations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _getStationDetails(String stationId) async {
    try {
      // Try station_profiles first
      final profileDoc = await FirebaseFirestore.instance
          .collection('station_profiles')
          .doc(stationId)
          .get();
      
      if (profileDoc.exists) {
        return profileDoc.data();
      }
      
      // Try fuel_stations as fallback
      final stationDoc = await FirebaseFirestore.instance
          .collection('fuel_stations')
          .doc(stationId)
          .get();
      
      if (stationDoc.exists) {
        return stationDoc.data();
      }
    } catch (e) {
      debugPrint('Error getting station details: $e');
    }
    
    return null;
  }

  Future<int> _getTodayWaitingCount(String stationId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('preorders')
          .where('stationId', isEqualTo: stationId)
          .where('status', isEqualTo: 'waiting')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where(
            'createdAt',
            isLessThan: Timestamp.fromDate(todayEnd),
          )
          .get();

      return snapshot.size;
    } catch (e) {
      debugPrint('Error getting waiting count: $e');
      return 0;
    }
  }

  String _getStationId(String docId, String? autoID) {
    if (autoID != null && autoID != 'no-autoID' && autoID.trim().isNotEmpty) {
      return autoID.trim();
    }
    return docId;
  }

  void _calculateDistances() {
    if (_currentPosition == null) return;

    for (var station in _stations) {
      if (station['latitude'] == 0.0 && station['longitude'] == 0.0) {
        // If no coordinates, assign a default distance
        station['distance'] = 9999.0;
        continue;
      }

      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        station['latitude'],
        station['longitude'],
      ) / 1000; // Convert to kilometers

      station['distance'] = distance;
    }

    setState(() {
      _stations = List.from(_stations);
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_stations);

    // Filter by radius
    filtered = filtered.where((station) {
      return station['distance'] <= _filterRadius;
    }).toList();

    // Filter by fuel type
    if (_selectedFuelType != 'All') {
      filtered = filtered.where((station) {
        return station['fuelTypes'].contains(_selectedFuelType);
      }).toList();
    }

    // Sort by distance
    filtered.sort((a, b) => a['distance'].compareTo(b['distance']));

    setState(() {
      _filteredStations = filtered;
    });
  }

  Future<void> _openMap() async {
    if (!_locationPermissionGranted) {
      await _getCurrentLocation();
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available. Please enable location services.')),
      );
      return;
    }

    String mapUrl = '';
    
    if (_filteredStations.isNotEmpty && _filteredStations.any((s) => s['latitude'] != 0.0)) {
      // Open Google Maps with multiple markers for filtered stations
      final origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
      String destinations = '';
      
      // Add only stations with valid coordinates
      final validStations = _filteredStations.where((s) => s['latitude'] != 0.0).take(8).toList();
      
      for (var station in validStations) {
        if (destinations.isNotEmpty) destinations += '|';
        destinations += '${station['latitude']},${station['longitude']}';
      }
      
      if (destinations.isNotEmpty) {
        mapUrl = 'https://www.google.com/maps/dir/?api=1'
                 '&origin=$origin'
                 '&destination=${validStations.first['latitude']},${validStations.first['longitude']}'
                 '&travelmode=driving'
                 '&waypoints=$destinations';
      } else {
        // Fallback to just showing current location
        mapUrl = 'https://www.google.com/maps/search/?api=1'
                 '&query=gas+station'
                 '&center=${_currentPosition!.latitude},${_currentPosition!.longitude}'
                 '&zoom=13';
      }
    } else {
      // Show gas stations in the region
      mapUrl = 'https://www.google.com/maps/search/?api=1'
               '&query=petrol+station+diesel+station+fuel+station'
               '&center=${_currentPosition!.latitude},${_currentPosition!.longitude}'
               '&zoom=12';
    }

    try {
      if (await canLaunchUrl(Uri.parse(mapUrl))) {
        await launchUrl(Uri.parse(mapUrl));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open map application')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open map: $e')),
      );
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter Stations'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Radius Filter
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Search Radius',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_filterRadius.toInt()} km',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: _filterRadius,
                          min: 1,
                          max: 50,
                          divisions: 49,
                          label: '${_filterRadius.toInt()} km',
                          onChanged: (value) {
                            setState(() {
                              _filterRadius = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRadiusOption(5, setState),
                            _buildRadiusOption(10, setState),
                            _buildRadiusOption(15, setState),
                            _buildRadiusOption(25, setState),
                            _buildRadiusOption(50, setState),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Fuel Type Filter
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fuel Type',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _fuelTypes.map((type) {
                            return ChoiceChip(
                              label: Text(type),
                              selected: _selectedFuelType == type,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedFuelType = type;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    
                    // Current Location Info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const Text(
                          'Current Location',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentAddress,
                                        style: const TextStyle(fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_currentPosition != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, '
                                          'Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _applyFilters();
                  },
                  child: const Text('Apply Filters'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRadiusOption(double radius, StateSetter setState) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _filterRadius = radius;
          });
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide(
            color: _filterRadius == radius ? Colors.blue : Colors.grey[300]!,
            width: _filterRadius == radius ? 2 : 1,
          ),
          backgroundColor: _filterRadius == radius ? Colors.blue[50] : null,
        ),
        child: Text(
          '${radius.toInt()}km',
          style: TextStyle(
            fontSize: 12,
            color: _filterRadius == radius ? Colors.blue : Colors.grey[700],
            fontWeight: _filterRadius == radius ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station) {
    bool isOpen = station['isOpen'];
    double distance = station['distance'];
    int availablePumps = station['availablePumps'];
    int totalPumps = station['totalPumps'];
    int waitingCount = station['waitingCount'];
    List<String> fuelTypes = List<String>.from(station['fuelTypes']);
    bool isRecommended = station['isRecommended'] ?? false;
    bool hasCoordinates = station['latitude'] != 0.0;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Name and Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              station['name'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRecommended)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.recommend_rounded,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              station['address'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOpen ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOpen ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isOpen ? 'OPEN' : 'CLOSED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isOpen ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.directions_car,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            distance < 9999.0 
                                ? '${distance.toStringAsFixed(1)} km'
                                : 'N/A',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Distance',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.people,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$waitingCount',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Waiting',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.local_gas_station,
                          size: 16,
                          color: Colors.purple,
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$availablePumps/$totalPumps',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pumps',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Pump Availability
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Availability',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$availablePumps/$totalPumps',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: availablePumps > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: totalPumps > 0 ? availablePumps / totalPumps : 0,
                    backgroundColor: Colors.grey[300],
                    color: availablePumps > 0 ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Fuel Types
            if (fuelTypes.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fuel Types:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: fuelTypes.map((type) {
                      return Chip(
                        label: Text(
                          type,
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: _getFuelTypeColor(type),
                        labelStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      );
                    }).toList(),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // Action Buttons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.local_gas_station, size: 18),
                    label: const Text(
                      'Pre-order Fuel',
                      style: TextStyle(fontSize: 14),
                    ),
                    onPressed: availablePumps > 0 && isOpen
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PreOrderFuelPage(
                                  stationId: station['id'],
                                  stationName: station['name'],
                                ),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: availablePumps > 0 && isOpen
                          ? Colors.green
                          : Colors.grey[300],
                      foregroundColor: availablePumps > 0 && isOpen
                          ? Colors.white
                          : Colors.grey[500],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (hasCoordinates)
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.directions, size: 18),
                            label: const Text('Directions'),
                            onPressed: () {
                              final url = 'https://www.google.com/maps/dir/?api=1'
                                          '&destination=${station['latitude']},${station['longitude']}'
                                          '&travelmode=driving';
                              launchUrl(Uri.parse(url));
                            },
                          ),
                        ),
                      ),
                    if (hasCoordinates) const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.queue, size: 18),
                          label: const Text('Queue'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StationQueuePage(
                                  stationId: station['id'],
                                  stationName: station['name'],
                                  dieselPrice: '65.50 ETB/L',
                                  benzenePrice: '72.80 ETB/L',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getFuelTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'petrol':
        return Colors.orange[100]!;
      case 'diesel':
        return Colors.blue[100]!;
      case 'cng':
        return Colors.green[100]!;
      case 'electric':
        return Colors.purple[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  Widget _buildLocationErrorUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _locationServiceEnabled 
                  ? Icons.location_off 
                  : Icons.location_disabled,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _currentAddress,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.location_on),
              label: const Text('Enable Location'),
              onPressed: _getCurrentLocation,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Open App Settings'),
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingUI() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading stations...'),
        ],
      ),
    );
  }

  Widget _buildNoStationsUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.local_gas_station,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No stations found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try increasing the search radius\nor check your location permissions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reload Stations'),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadStations();
              _getCurrentLocation();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Stations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadStations();
              _getCurrentLocation();
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingUI()
          : (!_locationPermissionGranted || !_locationServiceEnabled)
              ? _buildLocationErrorUI()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Filters
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Nearby Stations',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Chip(
                                    label: Text('${_filteredStations.length}'),
                                    backgroundColor: Colors.blue[50],
                                    labelStyle: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _currentAddress,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      icon: const Icon(Icons.map, size: 20),
                                      label: const Text('Open Map'),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(50),
                                      ),
                                      onPressed: _openMap,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.filter_list, size: 20),
                                      label: const Text('Filter Stations'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(50),
                                      ),
                                      onPressed: _showFilterDialog,
                                    ),
                                  ),
                                ],
                              ),
                              if (_filterRadius != 15.0 || _selectedFuelType != 'All')
                                Column(
                                  children: [
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        if (_filterRadius != 15.0)
                                          Chip(
                                            label: Text('Radius: ${_filterRadius.toInt()}km'),
                                            onDeleted: () {
                                              setState(() {
                                                _filterRadius = 15.0;
                                                _applyFilters();
                                              });
                                            },
                                          ),
                                        if (_selectedFuelType != 'All') ...[
                                          const SizedBox(width: 8),
                                          Chip(
                                            label: Text('Fuel: $_selectedFuelType'),
                                            onDeleted: () {
                                              setState(() {
                                                _selectedFuelType = 'All';
                                                _applyFilters();
                                              });
                                            },
                                          ),
                                        ],
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _filterRadius = 15.0;
                                              _selectedFuelType = 'All';
                                              _applyFilters();
                                            });
                                          },
                                          child: const Text('Clear all'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Stations List
                      if (_filteredStations.isEmpty)
                        _buildNoStationsUI()
                      else
                        Column(
                          children: [
                            ..._filteredStations.map((station) {
                              return _buildStationCard(station);
                            }),
                            const SizedBox(height: 32),
                            Text(
                              'Showing stations within ${_filterRadius.toInt()}km radius',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
}

// Placeholder classes - replace with your actual implementations
class StationQueuePage extends StatelessWidget {
  final String stationId;
  final String stationName;
  final String dieselPrice;
  final String benzenePrice;

  const StationQueuePage({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.dieselPrice,
    required this.benzenePrice,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Queue @ $stationName'),
      ),
      body: const Center(
        child: Text('Station Queue Page'),
      ),
    );
  }
}

class PreOrderFuelPage extends StatelessWidget {
  final String stationId;
  final String stationName;

  const PreOrderFuelPage({
    super.key,
    required this.stationId,
    required this.stationName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pre-order @ $stationName'),
      ),
      body: const Center(
        child: Text('Pre-order Page'),
      ),
    );
  }
}