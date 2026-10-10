import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_enums.dart';
import 'station_preorder_detail_page.dart'; // ← your existing detail page

class DailyHistoryDetailPage extends StatelessWidget {
  final DateTime date;
  final List<Map<String, dynamic>> orders;

  const DailyHistoryDetailPage({
    super.key,
    required this.date,
    required this.orders,
  });

  @override
  Widget build(BuildContext context) {
    final totalLiters = orders.fold<double>(
      0,
      (sum, o) => sum + (double.tryParse(o['liters']?.toString() ?? '0') ?? 0),
    );
    final count = orders.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_formatTitle(date)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$count orders',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${totalLiters.toStringAsFixed(1)} L',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final o = orders[index];

                final driver = (o['driver_name'] as String?)?.trim() ?? '—';
                final plate = (o['driver_plate'] as String?)?.trim().toUpperCase() ?? '—';
                final fuel = fuelTypeLabel(o['fuel_type']?.toString());
                final liters = double.tryParse(o['liters']?.toString() ?? '0') ?? 0.0;
                final orderId = o['id']?.toString() ?? '';

                final statusRaw = (o['status'] as String?)?.toLowerCase() ?? 'completed';
                final isCancelled = statusRaw.contains('cancel') || statusRaw.contains('reject');
                final statusColor = isCancelled ? Colors.red : Colors.green;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: orderId.isNotEmpty
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StationPreorderDetailPage(
                                  orderId: orderId,
                                  orderData: o,
                                  isFromHistory: true,
                                ),
                              ),
                            )
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // reduced vertical padding
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isCancelled ? Icons.cancel_rounded : Icons.check_circle_rounded,
                              color: statusColor.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  driver,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$fuel  •  ${liters.toStringAsFixed(1)} L  •  $plate',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey[700],
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTitle(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    if (d.year == now.year && d.month == now.month && d.day == now.day - 1) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, MMM d').format(d);
  }
}