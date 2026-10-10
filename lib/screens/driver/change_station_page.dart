// lib/screens/driver/change_station_page.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/api_client.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';

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
      if (mounted) setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────
  //   Keeping fetch logic mostly unchanged (only minor cleanups)
  // ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchAndSortStations() async {
    final userPos = await _getCurrentPositionSafely();

    try {
      final rows = await AppApi.stations(order: 'name', activeOnly: true);

      final List<Map<String, dynamic>> stations = [];

      for (final row in rows) {
        final name = (row['display_name'] as String?)?.trim() ?? 'Unnamed';
        final address = (row['address'] as String?)?.trim() ?? '';
        final city = (row['station_city'] as String?)?.trim() ?? '';

        final lat = double.tryParse(row['latitude']?.toString() ?? '');
        final lng = double.tryParse(row['longitude']?.toString() ?? '');

        double? distKm;
        if (userPos != null && lat != null && lng != null) {
          distKm = _calculateDistance(userPos.latitude, userPos.longitude, lat, lng);
        }

        stations.add({
          'id': (row['uid'] as String?) ?? '',
          'name': name,
          'address': address.isNotEmpty ? '$address, $city' : 'No address',
          'distanceKm': distKm,
          'lat': lat,
          'lng': lng,
          'isPartner': _isPartnerStation(name),
        });
      }

      if (userPos != null) {
        stations.sort((a, b) {
          final da = a['distanceKm'] as double?;
          final db = b['distanceKm'] as double?;
          if (da != null && db != null) return da.compareTo(db);
          if (da == null) return 1;
          if (db == null) return -1;
          return (a['name'] as String).compareTo(b['name'] as String);
        });
      } else {
        stations.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      }

      return stations;
    } catch (_) {
      return [];
    }
  }

  Future<Position?> _getCurrentPositionSafely() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      if (mounted) setState(() => _locationDenied = true);
      return null;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  bool _isPartnerStation(String name) {
    final n = name.toLowerCase();
    return n.contains('total') || n.contains('noc') || n.contains('mis') || n.contains('partner');
  }

  Future<Map<String, dynamic>?> _getStationQueueInfo(String stationId) async {
    try {
      final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0).toUtc();

      final count = await AppApi.countPreorders(
        stationId: stationId,
        statuses: const ['waiting', 'preparing'],
        from: todayStart.toIso8601String(),
      );

      return {'count': count, 'estMin': count * 4};
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleTransfer() async {
    if (_selectedStationId == null || _selectedStationId == widget.currentStationId) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildCompactConfirmSheet(),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final user = AuthService.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await AppApi.transferPreorder({
        'old_order_id': widget.orderId,
        'driver_uid': user.uid,
        'driver_email': user.email,
        'driver_name': widget.orderData['driver_name'] ?? '—',
        'driver_plate': widget.orderData['driver_plate'] ?? '—',
        'station_id': _selectedStationId,
        'station_name': _selectedStationName,
        'fuel_type': widget.orderData['fuel_type'] ?? '—',
        'price_per_liter': double.tryParse(widget.orderData['price_per_liter']?.toString() ?? '0') ?? 0.0,
        'liters': double.tryParse(widget.orderData['liters']?.toString() ?? '0') ?? 0.0,
        'total_amount': double.tryParse(widget.orderData['total_amount']?.toString() ?? '0') ?? 0.0,
        'is_custom_amount': widget.orderData['is_custom_amount'] ?? false,
        'max_order_limit': double.tryParse(widget.orderData['max_order_limit']?.toString() ?? '100') ?? 100.0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transferred'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildCompactConfirmSheet() {
    final fuel = widget.orderData['fuel_type'] ?? '—';
    final liters = widget.orderData['liters']?.toString() ?? '—';

    return DraggableScrollableSheet(
      initialChildSize: 0.50,
      minChildSize: 0.40,
      maxChildSize: 0.85,
      builder: (context, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const Text(
              'Transfer Order',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildTinyRow('From', widget.currentStationName, Icons.arrow_outward_rounded),
            const SizedBox(height: 12),
            _buildTinyRow('To', _selectedStationName ?? '—', Icons.arrow_forward_rounded),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              color: Colors.green.shade50,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('$fuel • ${liters} L', style: const TextStyle(fontSize: 13)),
                    if (_selectedWaitingCount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '~$_selectedWaitingCount waiting • ≈${_selectedEstWaitMin?.toStringAsFixed(0) ?? "?"} min',
                        style: TextStyle(fontSize: 12.5, color: Colors.green.shade800),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: const Text('Confirm'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 15),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTinyRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Station', style: TextStyle(fontSize: 18)),
        centerTitle: true,
        toolbarHeight: 48,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchCtrl,
              leading: const Icon(Icons.search_rounded, size: 20),
              hintText: 'Search stations...',
              hintStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14)),
              elevation: const WidgetStatePropertyAll(0.8),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 0)),
            ),
          ),

          if (_locationDenied)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'No location → sorted by name',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
              ),
            ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _stationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No stations', style: TextStyle(fontSize: 15)));
                }

                final stations = snapshot.data!;
                final filtered = _searchQuery.isEmpty
                    ? stations
                    : stations.where((s) => (s['name'] as String).toLowerCase().contains(_searchQuery)).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    final id = s['id'] as String;
                    final name = s['name'] as String;
                    final isSelected = id == _selectedStationId;
                    final isCurrent = id == widget.currentStationId;
                    final dist = s['distanceKm'] as double?;

                    String sub = s['address'] as String? ?? '—';
                    if (dist != null) sub = '${dist.toStringAsFixed(1)} km • $sub';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: isSelected ? 2.5 : 0.8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isSelected ? colorScheme.primaryContainer.withOpacity(0.5) : null,
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minLeadingWidth: 36,
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: isSelected ? colorScheme.primary : Colors.green.shade100,
                          child: Icon(
                            Icons.local_gas_station_rounded,
                            size: 20,
                            color: isSelected ? Colors.white : Colors.green.shade700,
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub,
                              style: const TextStyle(fontSize: 11.5),
                              maxLines: 1,
                            ),
                            if (isCurrent)
                              Text(
                                'Current',
                                style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, size: 22, color: Colors.green)
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.8, color: Colors.white),
                  )
                : const Icon(Icons.swap_horiz_rounded, size: 20),
            label: Text(
              _isSubmitting ? 'Transferring...' : 'Transfer',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: (_selectedStationId != null && _selectedStationId != widget.currentStationId)
                  ? null
                  : Colors.grey.shade400,
            ),
            onPressed: _isSubmitting || _selectedStationId == null || _selectedStationId == widget.currentStationId
                ? null
                : _handleTransfer,
          ),
        ),
      ),
    );
  }
}