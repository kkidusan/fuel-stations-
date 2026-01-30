// lib/screens/driver/change_station_page.dart
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class ChangeStationPage extends StatefulWidget {
  final String orderId;
  final String currentStationId;
  final String currentStationName;
  final Map<String, dynamic> orderData;

  const ChangeStationPage({
    super.key,
    required this.orderId,
    required this.currentStationId,
    required this.currentStationName,
    required this.orderData,
  });

  @override
  State<ChangeStationPage> createState() => _ChangeStationPageState();
}

class _ChangeStationPageState extends State<ChangeStationPage> {
  late Future<List<Map<String, dynamic>>> _stationsFuture;

  String? _selectedStationId;
  String? _selectedStationName;
  int? _selectedWaitingCount;
  double? _selectedEstWaitMin;

  bool _isSubmitting = false;
  bool _locationDenied = false;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedStationId = widget.currentStationId;
    _selectedStationName = widget.currentStationName;

    _stationsFuture = _fetchAndSortStations();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchAndSortStations() async {
    final userPos = await _getCurrentPositionSafely();

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'station')
        .get();

    final List<Map<String, dynamic>> list = [];

    for (final doc in snap.docs) {
      final data = doc.data();
      final name = (data['name'] as String? ?? 'Unnamed').trim();
      final address = data['address'] as String? ?? 'No address';
      final lat = data['latitude'] as num?;
      final lng = data['longitude'] as num?;
      final diesel = data['priceDiesel'] as num?;
      final benzene = data['priceBenzene'] as num?;

      double? distKm;
      if (userPos != null && lat != null && lng != null) {
        distKm = _calculateDistance(
          userPos.latitude,
          userPos.longitude,
          lat.toDouble(),
          lng.toDouble(),
        );
      }

      list.add({
        'id': doc.id,
        'name': name,
        'address': address,
        'distanceKm': distKm,
        'priceDiesel': diesel?.toDouble(),
        'priceBenzene': benzene?.toDouble(),
        'lat': lat?.toDouble(),
        'lng': lng?.toDouble(),
        'isPartner': _isPartnerStation(name),
      });
    }

    // Sort: distance → name
    if (userPos != null) {
      list.sort((a, b) {
        final da = a['distanceKm'] as double?;
        final db = b['distanceKm'] as double?;
        if (da != null && db != null) return da.compareTo(db);
        if (da == null) return 1;
        if (db == null) return -1;
        return a['name'].compareTo(b['name']);
      });
    } else {
      list.sort((a, b) => a['name'].compareTo(b['name']));
    }

    return list;
  }

  Future<Position?> _getCurrentPositionSafely() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;

      LocationSettings settings;

      if (Theme.of(context).platform == TargetPlatform.android) {
        settings = AndroidSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 0,
          forceLocationManager: false,
          intervalDuration: const Duration(seconds: 6),
        );
      } else {
        settings = const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 0,
        );
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _locationDenied = true);
      }
      return null;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371; // km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  bool _isPartnerStation(String name) {
    final n = name.toLowerCase();
    return n.contains('total') || n.contains('noc') || n.contains('mis') || n.contains('partner');
  }

  Future<Map<String, dynamic>?> _getStationQueueInfo(String stationId) async {
    final todayStart = DateTime.now().copyWith(
      hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0,
    );

    final query = await FirebaseFirestore.instance
        .collection('preorders')
        .where('stationId', isEqualTo: stationId)
        .where('status', whereIn: ['waiting', 'preparing'])
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .count()
        .get();

    final count = query.count;
    final estMin = count! * 4; // ~4 min per vehicle – adjust based on real data

    return {'count': count, 'estMin': estMin};
  }

  Future<void> _handleTransfer() async {
    if (_selectedStationId == null || _selectedStationId == widget.currentStationId) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildModernConfirmSheet(),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // 1. Create new preorder
      final newData = {
        ...widget.orderData,
        'stationId': _selectedStationId,
        'stationName': _selectedStationName,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
        'positionInQueue': null,
        'transferredFrom': {
          'orderId': widget.orderId,
          'stationId': widget.currentStationId,
          'stationName': widget.currentStationName,
        },
        'transferCount': FieldValue.increment(1),
      };

      final newRef = await FirebaseFirestore.instance.collection('preorders').add(newData);

      // 2. Mark old as transferred / cancelled
      await FirebaseFirestore.instance.collection('preorders').doc(widget.orderId).update({
        'status': 'transferred',
        'transferredTo': {
          'orderId': newRef.id,
          'stationId': _selectedStationId,
          'stationName': _selectedStationName,
        },
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelReason': 'Station changed by driver',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order transferred to $_selectedStationName'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.pop(context, true); // success → parent can refresh
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildModernConfirmSheet() {
    final fuel = widget.orderData['fuelType'] ?? '—';
    final liters = widget.orderData['liters']?.toString() ?? '—';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              'Transfer Order',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildPreviewRow('From', widget.currentStationName, Icons.arrow_outward),
            const SizedBox(height: 16),
            _buildPreviewRow('To', _selectedStationName ?? '', Icons.arrow_forward),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: Colors.green.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order Summary', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text('$fuel • $liters L'),
                    if (_selectedWaitingCount != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '≈ $_selectedWaitingCount waiting • ~${_selectedEstWaitMin?.toStringAsFixed(0) ?? "?"} min',
                        style: TextStyle(color: Colors.green.shade800),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Confirm Transfer', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade700, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Station'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _searchCtrl,
              leading: const Icon(Icons.search_rounded),
              hintText: 'Search stations...',
              elevation: const WidgetStatePropertyAll(1),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          if (_locationDenied)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Location access denied → sorted by name',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 13.5),
              ),
            ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _stationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No stations available'));
                }

                final all = snapshot.data!;
                final filtered = _searchQuery.isEmpty
                    ? all
                    : all.where((s) => (s['name'] as String).toLowerCase().contains(_searchQuery)).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    final id = s['id'] as String;
                    final name = s['name'] as String;
                    final isSelected = id == _selectedStationId;
                    final isCurrent = id == widget.currentStationId;
                    final dist = s['distanceKm'] as double?;
                    final diesel = s['priceDiesel'] as double?;
                    final benzene = s['priceBenzene'] as double?;

                    String subtitle = s['address'] as String? ?? '—';
                    if (dist != null) subtitle = '${dist.toStringAsFixed(1)} km • $subtitle';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: isSelected ? 3 : 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      color: isSelected ? colorScheme.primaryContainer.withAlpha(153) : null, // 0.6 opacity ≈ 153 alpha
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? colorScheme.primary : Colors.green.shade100,
                          radius: 26,
                          child: Icon(
                            Icons.local_gas_station_rounded,
                            color: isSelected ? Colors.white : Colors.green.shade700,
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 16.5,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subtitle, style: const TextStyle(fontSize: 13)),
                            if (diesel != null || benzene != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (diesel != null)
                                    Text(
                                      'Diesel ${diesel.toStringAsFixed(1)} ',
                                      style: TextStyle(color: Colors.green.shade800, fontSize: 12.5),
                                    ),
                                  if (benzene != null)
                                    Text(
                                      'Benzene ${benzene.toStringAsFixed(1)}',
                                      style: TextStyle(color: Colors.blue.shade800, fontSize: 12.5),
                                    ),
                                ],
                              ),
                            ],
                            if (isCurrent)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Current • queued here',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueGrey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 30)
                            : null,
                        onTap: () async {
                          setState(() {
                            _selectedStationId = id;
                            _selectedStationName = name;
                            _selectedWaitingCount = null;
                            _selectedEstWaitMin = null;
                          });

                          final info = await _getStationQueueInfo(id);
                          if (mounted && info != null) {
                            setState(() {
                              _selectedWaitingCount = info['count'] as int;
                              _selectedEstWaitMin = (info['estMin'] as int).toDouble();
                            });
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: FilledButton.icon(
            icon: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                  )
                : const Icon(Icons.swap_horiz_rounded),
            label: Text(
              _isSubmitting ? 'Transferring...' : 'Transfer Order',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: _selectedStationId != widget.currentStationId && _selectedStationId != null
                  ? null
                  : Colors.grey.shade400,
            ),
            onPressed: _isSubmitting ||
                    _selectedStationId == null ||
                    _selectedStationId == widget.currentStationId
                ? null
                : _handleTransfer,
          ),
        ),
      ),
    );
  }
}