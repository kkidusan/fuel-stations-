import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'change_station_page.dart'; // Make sure this file exists

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
      final scannedPlate = (jsonMap['driverPlate'] as String?)?.toUpperCase().trim();
      final exp = jsonMap['exp'] as String?;

      if (scannedOrderId != widget.orderId) {
        setState(() => _feedback = 'Wrong order QR code');
        return;
      }

      if (exp != null) {
        final expDate = DateTime.tryParse(exp)?.toUtc();
        if (expDate == null || expDate.isBefore(DateTime.now().toUtc())) {
          setState(() => _feedback = 'QR code expired');
          return;
        }
      }

      final myUid = widget.orderData['driverUid'] as String?;
      final myPlate = (widget.orderData['driverPlate'] as String?)?.toUpperCase().trim();
      final uidMatch = myUid != null && scannedDriverUid == myUid;
      final plateMatch =
          myPlate != null && scannedPlate == myPlate && scannedPlate != 'UNKNOWN';

      if (!uidMatch && !plateMatch) {
        setState(() => _feedback = 'Driver mismatch');
        return;
      }

      // Success – mark order as completed
      await FirebaseFirestore.instance.collection('preorders').doc(widget.orderId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'qrScannedAt': FieldValue.serverTimestamp(),
        'completedBy': 'station',
      });

      setState(() {
        _feedback = 'Fuel collection confirmed!';
        _success = true;
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      setState(() => _feedback = 'Invalid QR format');
      debugPrint('QR scan error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const QRScannerScreen(),
      ),
    ).then((result) {
      if (result is String && result.trim().isNotEmpty && mounted) {
        _handleScannedQrCode(result.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusRaw = (widget.orderData['status'] as String?)?.toLowerCase() ?? 'waiting';
    final isWaiting = ['waiting', 'pending', 'confirmed'].contains(statusRaw);
    final isCompleted = statusRaw == 'completed';

    final createdAt = (widget.orderData['createdAt'] as Timestamp?)?.toDate();
    final createdStr =
        createdAt != null ? DateFormat('dd MMM yyyy • HH:mm').format(createdAt) : '—';

    final liters = (widget.orderData['liters'] as num?)?.toInt() ?? 0;
    final fuelType = widget.orderData['fuelType'] as String? ?? '—';
    final stationName = widget.orderData['stationName'] as String? ?? '—';
    final driverName = widget.orderData['driverName'] as String? ?? '—';
    final driverPlate = (widget.orderData['driverPlate'] as String?)?.toUpperCase() ?? '—';

    final statusText = isCompleted ? 'Completed' : isWaiting ? 'Ready to Collect' : 'Other';
    final statusColor =
        isCompleted ? Colors.green : isWaiting ? Colors.orange[800] : Colors.blue[800];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.local_gas_station,
                      label: "Station",
                      value: stationName,
                    ),
                    _buildDivider(),
                    _buildInfoRow(
                      icon: Icons.local_drink,
                      label: "Fuel Type",
                      value: fuelType,
                    ),
                    _buildDivider(),
                    _buildInfoRow(
                      icon: Icons.format_list_numbered,
                      label: "Quantity",
                      value: '$liters L',
                    ),
                    _buildDivider(),
                    _buildInfoRow(
                      icon: Icons.person,
                      label: "Driver",
                      value: driverName,
                    ),
                    _buildDivider(),
                    _buildInfoRow(
                      icon: Icons.directions_car,
                      label: "Plate",
                      value: driverPlate,
                    ),
                    _buildDivider(),
                    _buildInfoRow(
                      icon: Icons.calendar_today,
                      label: "Ordered",
                      value: createdStr,
                    ),
                    _buildDivider(),
                    _buildInfoRow(
                      icon: isCompleted ? Icons.check_circle : Icons.hourglass_bottom,
                      label: "Status",
                      value: statusText,
                      valueColor: statusColor,
                      boldValue: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (_feedback != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _success ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _success ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _success ? Icons.check_circle : Icons.error_outline,
                      color: _success ? Colors.green[800] : Colors.red[800],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _feedback!,
                        style: TextStyle(
                          color: _success ? Colors.green[900] : Colors.red[900],
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (isWaiting)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: const Text('Scan QR', style: TextStyle(fontSize: 15)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isProcessing ? null : _openScanner,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz, size: 20),
                      label: const Text('Change Station', style: TextStyle(fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                        side: BorderSide(color: Colors.blue[700]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChangeStationPage(
                              orderId: widget.orderId,
                              currentStationId: widget.orderData['stationId'] as String? ?? '',
                              currentStationName: stationName,
                              orderData: widget.orderData,
                            ),
                          ),
                        ).then((changed) {
                          if (changed == true && mounted) {
                            setState(() {
                              _feedback = 'Station changed successfully';
                              _success = true;
                            });
                          }
                        });
                      },
                    ),
                  ),
                ],
              )
            else if (isCompleted)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Already Completed'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: null,
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool boldValue = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: Colors.grey[700],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: boldValue ? FontWeight.w600 : FontWeight.w500,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        color: Colors.grey.shade300,
      ),
    );
  }
}

// ────────────────────────────────────────────────
//               QR Scanner Screen (Full)
// ────────────────────────────────────────────────

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
              // You can add formats: [BarcodeFormat.qrCode] if you only want QR
            ),
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue?.trim();
                if (code != null && code.isNotEmpty) {
                  Navigator.pop(context, code);
                  return; // stop after first valid code
                }
              }
            },
          ),

          // Overlay / UI elements
          SafeArea(
            child: Column(
              children: [
                // Top bar with close button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 36),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // Center scanning frame + instructions
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Scanning window frame
                        SizedBox(
                          width: 280,
                          height: 280,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white70, width: 5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Scan Station QR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 10, color: Colors.black87)
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Fit code inside frame',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            shadows: [
                              Shadow(blurRadius: 6, color: Colors.black54)
                            ],
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