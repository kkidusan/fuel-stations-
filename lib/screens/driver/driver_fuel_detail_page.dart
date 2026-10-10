// TODO Implement this library.
// File: driver_fuel_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DriverFuelDetailPage extends StatelessWidget {
  final Map<String, dynamic> order;

  const DriverFuelDetailPage({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final liters = order['liters'] as double;
    final fuelType = order['fuel_type'] as String;
    final dateStr = order['date'] as String;
    final status = (order['status'] as String).toLowerCase();
    final notes = order['notes'] as String;

    // Better timestamp handling
    DateTime? completedAt;
    final completedRaw = order['completed_at'];
    if (completedRaw != null) {
      if (completedRaw is String) {
        completedAt = DateTime.tryParse(completedRaw)?.toLocal();
      } else if (completedRaw is DateTime) {
        completedAt = completedRaw.toLocal();
      }
    }

    final timeFormat = DateFormat('hh:mm a');
    final fullDateFormat = DateFormat('EEEE, MMMM d, yyyy • hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Pickup Details'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: status.contains('complete')
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    status.contains('complete')
                        ? Icons.check_circle_rounded
                        : Icons.info_rounded,
                    color: status.contains('complete')
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.contains('complete') ? 'Completed' : 'Status: $status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: status.contains('complete')
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          completedAt != null
                              ? fullDateFormat.format(completedAt!)
                              : dateStr,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                      label: 'Fuel Type',
                      value: fuelType,
                      icon: Icons.local_gas_station_rounded,
                    ),
                    const Divider(height: 32),
                    _DetailRow(
                      label: 'Quantity',
                      value: '${liters.toStringAsFixed(1)} Liters',
                      icon: Icons.opacity_rounded,
                      valueStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const Divider(height: 32),
                    _DetailRow(
                      label: 'Station',
                      value: order['station'] as String? ?? '—',
                      icon: Icons.storefront_rounded,
                    ),
                    if (notes.isNotEmpty) ...[
                      const Divider(height: 32),
                      _DetailRow(
                        label: 'Notes',
                        value: notes,
                        icon: Icons.note_alt_rounded,
                        multiLine: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (order['id'] != null && (order['id'] as String).isNotEmpty)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.numbers_rounded, color: Colors.grey),
                  title: const Text('Order ID'),
                  subtitle: Text(
                    order['id'] as String,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),

            const SizedBox(height: 40),

            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text('Share Receipt'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share feature coming soon...')),
                  );
                },
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final TextStyle? valueStyle;
  final bool multiLine;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueStyle,
    this.multiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: Colors.teal.shade700,
          size: 28,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: valueStyle ??
                    const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: multiLine ? null : 1,
                overflow: multiLine ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
