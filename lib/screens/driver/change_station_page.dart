// change_station_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _stationsFuture = _fetchAvailableStations();
    _selectedStationId = widget.currentStationId;
    _selectedStationName = widget.currentStationName;
  }

  // Reuse/improve your station fetch logic (same as DriverHomePage)
  Future<List<Map<String, dynamic>>> _fetchAvailableStations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'station')
          .where('isActive', isEqualTo: true) // only active stations
          .limit(30)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'autoID': data['autoID'] as String?,
          'name': data['name'] as String? ?? 'Unnamed',
          'address': data['address'] as String? ?? '',
          'priceDiesel': data['priceDiesel'] as num?,
          'priceBenzene': data['priceBenzene'] as num?,
          'isRecommended': (data['name'] as String?)?.toLowerCase().contains('total') == true ||
              (data['name'] as String?)?.toLowerCase().contains('noc') == true,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading stations: $e');
      return [];
    }
  }

  Future<void> _confirmChange(String newStationId, String newStationName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Station?'),
        content: Text(
          'Move this order from\n"${widget.currentStationName}"\nto\n"$newStationName"?\n\nQueue position will be recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdating = true);

    try {
      final updateData = {
        'stationId': newStationId,
        'stationName': newStationName,
        'stationAutoID': null, // if you have autoID
        'lastStationChangedAt': FieldValue.serverTimestamp(),
        'stationChangeCount': FieldValue.increment(1),
        // Optional: log history
        'stationHistory': FieldValue.arrayUnion([
          {
            'from': widget.currentStationName,
            'to': newStationName,
            'changedAt': FieldValue.serverTimestamp(),
          }
        ]),
      };

      await FirebaseFirestore.instance
          .collection('preorders')
          .doc(widget.orderId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Station updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // return true to signal change happened
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Fuel Station'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Current selection header
          Container(
            width: double.infinity,
            color: colorScheme.primaryContainer.withOpacity(0.4),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Station',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.currentStationName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _stationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No stations available'));
                }

                final stations = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: stations.length,
                  itemBuilder: (context, index) {
                    final station = stations[index];
                    final stationId = station['id'] as String;
                    final name = station['name'] as String;
                    final isSelected = stationId == _selectedStationId;
                    final isCurrent = stationId == widget.currentStationId;
                    final diesel = station['priceDiesel'] as num?;

                    return Card(
                      elevation: isSelected ? 4 : 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isSelected ? colorScheme.primaryContainer : null,
                      child: ListTile(
                        leading: Icon(
                          Icons.local_gas_station_rounded,
                          color: isSelected ? colorScheme.primary : Colors.green[700],
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? colorScheme.primary : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(station['address'] as String? ?? '—'),
                            if (diesel != null)
                              Text(
                                'Diesel: ${diesel.toStringAsFixed(2)} ETB',
                                style: TextStyle(color: Colors.green[800]),
                              ),
                            if (isCurrent)
                              Text(
                                'Current station',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: colorScheme.primary)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedStationId = stationId;
                            _selectedStationName = name;
                          });

                          // Optional: auto-confirm after selection
                          // _confirmChange(stationId, name);
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
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              _isUpdating ? 'Updating...' : 'Confirm New Station',
              style: const TextStyle(fontSize: 16),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: (_isUpdating ||
                    _selectedStationId == null ||
                    _selectedStationId == widget.currentStationId)
                ? null
                : () => _confirmChange(_selectedStationId!, _selectedStationName!),
          ),
        ),
      ),
    );
  }
}