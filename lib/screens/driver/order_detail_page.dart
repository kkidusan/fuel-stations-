import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDetailPage({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  String? _feedback;
  bool _isProcessing = false;
  bool _success = false;

  Future<void> _handleScannedQrCode(String rawQrContent) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final jsonMap = jsonDecode(rawQrContent.trim()) as Map<String, dynamic>;

      final scannedOrderId = jsonMap['orderId'] as String?;
      final scannedDriverUid = jsonMap['driverUid'] as String?;
      final scannedPlate = (jsonMap['driverPlate'] as String?)?.toUpperCase();
      final exp = jsonMap['exp'] as String?;

      // 1. Must be the correct order
      if (scannedOrderId != widget.orderId) {
        setState(() => _feedback = 'Wrong order QR code');
        return;
      }

      // 2. Check expiry if present
      if (exp != null) {
        final expDate = DateTime.tryParse(exp);
        if (expDate == null || expDate.isBefore(DateTime.now().toUtc())) {
          setState(() => _feedback = 'QR code expired');
          return;
        }
      }

      // 3. Driver identity check
      final myUid = widget.orderData['driverUid'] as String?;
      final myPlate = (widget.orderData['driverPlate'] as String?)?.toUpperCase();

      final uidMatch = myUid != null && scannedDriverUid == myUid;
      final plateMatch = myPlate != null && scannedPlate == myPlate && scannedPlate != 'UNKNOWN';

      if (!uidMatch && !plateMatch) {
        setState(() => _feedback = 'Driver verification failed');
        return;
      }

      // SUCCESS
      await FirebaseFirestore.instance.collection('preorders').doc(widget.orderId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'qrScannedAt': FieldValue.serverTimestamp(),
        'completedByDriver': true,
      });

      setState(() {
        _feedback = 'Success! Fuel collection confirmed';
        _success = true;
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      setState(() => _feedback = 'Invalid QR format');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const QRScannerScreen(),
      ),
    );

    if (result is String && result.trim().isNotEmpty && mounted) {
      await _handleScannedQrCode(result.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final statusRaw = (widget.orderData['status'] as String?)?.toLowerCase() ?? 'waiting';
    final isWaiting = ['waiting', 'pending', 'confirmed'].contains(statusRaw);

    final createdAt = (widget.orderData['createdAt'] as Timestamp?)?.toDate();
    final createdStr = createdAt != null
        ? DateFormat('dd MMM yyyy • HH:mm').format(createdAt)
        : '—';

    final liters = (widget.orderData['liters'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-order Details'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Minimal status row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isWaiting ? Icons.hourglass_empty : Icons.check_circle,
                    size: 28,
                    color: isWaiting ? Colors.orange[800] : Colors.green[800],
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isWaiting ? 'Waiting to Collect' : 'Completed',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isWaiting ? Colors.orange[900] : Colors.green[900],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Compact info rows
              _buildRow('Fuel Type', widget.orderData['fuelType'] ?? '—'),
              _buildRow('Liters', '$liters L'),
              _buildRow('Driver', widget.orderData['driverName'] ?? '—'),
              _buildRow('Plate', (widget.orderData['driverPlate'] as String?)?.toUpperCase() ?? '—'),
              _buildRow('Ordered', createdStr),

              const Spacer(),

              if (isWaiting)
                FilledButton.icon(
                  icon: const Icon(Icons.qr_code_scanner, size: 26),
                  label: const Text('Scan to Collect', style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _openScanner,
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 24),
                  label: const Text('Already Collected', style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: null,
                ),

              if (_feedback != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _success ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _success ? Colors.green.shade300 : Colors.red.shade300,
                    ),
                  ),
                  child: Text(
                    _feedback!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _success ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QRScannerScreen extends StatelessWidget {
  const QRScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
              facing: CameraFacing.back,
            ),
            onDetect: (capture) {
              final code = capture.barcodes.firstOrNull?.rawValue?.trim();
              if (code != null && code.isNotEmpty) {
                Navigator.pop(context, code);
              }
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 36),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white70, width: 4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Scan station QR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Fit code inside the frame',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}