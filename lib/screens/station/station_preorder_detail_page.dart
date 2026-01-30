// ================================================
// station_preorder_detail_page.dart
// ================================================

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class StationPreorderDetailPage extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const StationPreorderDetailPage({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  void _showQrCodeDialog(BuildContext context) {
    final now = DateTime.now().toUtc();

    final qrData = {
      'orderId': orderId,
      'stationId': orderData['stationId'] ?? 'unknown',
      'driverUid': orderData['driverUid'] ?? 'unknown',
      'driverPlate': (orderData['driverPlate'] as String?)?.toUpperCase() ?? '—',
      'driverName': orderData['driverName'] ?? '—',
      'fuelType': orderData['fuelType'] ?? '—',
      'liters': (orderData['liters'] as num?)?.toInt() ?? 0,
      'generatedAt': now.toIso8601String(),
      'exp': now.add(const Duration(hours: 4)).toIso8601String(), // optional expiry
      'version': '1.0',
    };

    final qrContent = jsonEncode(qrData);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Collection QR Code', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12),
                ],
              ),
              child: QrImageView(
                data: qrContent,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Order #$orderId',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${orderData['driverName'] ?? '—'} • ${(orderData['driverPlate'] as String?)?.toUpperCase() ?? '—'}',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Show this code to the driver.\n'
              'The order status will update only after they scan it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size(140, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = (orderData['createdAt'] as Timestamp?)?.toDate();
    final createdStr = createdAt != null
        ? DateFormat('dd MMM yyyy • HH:mm').format(createdAt)
        : '—';

    final driverName = orderData['driverName'] as String? ?? '—';
    final driverEmail = orderData['driverEmail'] as String? ?? '—';
    final driverPlate = (orderData['driverPlate'] as String?)?.toUpperCase() ?? '—';
    final fuelType = orderData['fuelType'] as String? ?? '—';
    final liters = (orderData['liters'] as num?)?.toDouble() ?? 0.0;
    final position = orderData['positionInQueue']?.toString() ?? '—';
    final status = (orderData['status'] as String?)?.toLowerCase() ?? 'waiting';

    final bool canShowQr = ['waiting', 'pending', 'confirmed'].contains(status);

    final statusInfo = _getStatusDisplay(status);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$orderId'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              elevation: 0,
              color: statusInfo.color.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      statusInfo.icon,
                      size: 48,
                      color: statusInfo.color,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      statusInfo.label,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: statusInfo.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Queue position: $position',
                      style: TextStyle(
                        fontSize: 16,
                        color: statusInfo.color.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _DetailRow('Fuel Type', fuelType),
            _DetailRow('Liters', '${liters.toStringAsFixed(0)} L'),
            _DetailRow('Driver', driverName),
            _DetailRow('Plate', driverPlate),
            _DetailRow('Email', driverEmail),
            _DetailRow('Ordered', createdStr),
            const SizedBox(height: 40),
            if (canShowQr)
              FilledButton.icon(
                icon: const Icon(Icons.qr_code_rounded),
                label: const Text('Generate QR for Driver'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => _showQrCodeDialog(context),
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.info_outline_rounded),
                label: Text('Order is ${statusInfo.label}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: null,
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _DetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, String label, Color color}) _getStatusDisplay(String status) {
    switch (status) {
      case 'waiting':
      case 'pending':
        return (icon: Icons.hourglass_bottom_rounded, label: 'Waiting', color: Colors.orange);
      case 'confirmed':
        return (icon: Icons.verified_rounded, label: 'Confirmed', color: Colors.teal);
      case 'completed':
        return (icon: Icons.check_circle_rounded, label: 'Completed', color: Colors.green.shade700);
      case 'cancelled':
      case 'rejected':
        return (icon: Icons.cancel_rounded, label: 'Cancelled', color: Colors.red.shade700);
      default:
        return (icon: Icons.help_outline_rounded, label: 'Unknown', color: Colors.blueGrey);
    }
  }
}