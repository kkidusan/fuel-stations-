import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../constants/app_enums.dart';
import '../../services/api_client.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';
import 'change_station_page.dart';

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
  String? _feedbackMessage;
  bool _isSuccess = false;
  bool _isProcessing = false;
  bool _isLoading = true;

  late Map<String, dynamic> _currentOrderData;
  String driverName = 'Loading...';
  String driverPlate = '—';
  int? _queuePosition;

  @override
  void initState() {
    super.initState();
    _currentOrderData = Map.from(widget.orderData);
    _loadDriverInfo();
    _refreshOrderAndPosition();
  }

  String _normalizeStationId(dynamic value) {
    if (value == null) return '';
    var s = value.toString().trim().toUpperCase();
    s = s.replaceAll(RegExp(r'[\s\-_·|•]'), '');
    return s;
  }

  String _getCurrentStationId() {
    return _normalizeStationId(
      _currentOrderData['station_id'] ??
          _currentOrderData['stationId'] ??
          _currentOrderData['station_code'] ??
          '',
    );
  }

  Future<void> _loadDriverInfo() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          driverName = 'Unknown';
          driverPlate = '—';
        });
      }
      return;
    }

    final name = user.displayName?.trim() ?? '';
    final plate = user.plate?.trim().toUpperCase() ?? '';

    if (mounted) {
      setState(() {
        driverName = name.isEmpty ? 'Unknown' : name;
        driverPlate = plate.isEmpty ? '—' : plate;
      });
    }
  }

  Future<void> _refreshOrderStatus() async {
    try {
      final row = await AppApi.preorder(widget.orderId);
      if (row != null && mounted) {
        setState(() {
          _currentOrderData = row;
        });
      }
    } catch (_) {}
  }

  Future<int?> _getQueuePosition() async {
    final status = (_currentOrderData['status'] as String?)?.toLowerCase() ?? '';
    if (!['waiting', 'pending', 'confirmed', 'ready'].contains(status)) return null;

    final stationId = _getCurrentStationId();
    final createdAtRaw = _currentOrderData['created_at'];
    if (stationId.isEmpty || createdAtRaw == null) return null;

    DateTime? myCreatedAt;
    if (createdAtRaw is String) {
      myCreatedAt = DateTime.tryParse(createdAtRaw)?.toUtc();
    } else if (createdAtRaw is DateTime) {
      myCreatedAt = createdAtRaw.toUtc();
    }
    if (myCreatedAt == null) return null;

    try {
      final countBefore = await AppApi.countPreorders(
        stationId: stationId,
        statuses: const ['waiting', 'pending', 'confirmed', 'ready'],
        before: myCreatedAt.toIso8601String(),
        sameDay: true,
      );
      return countBefore + 1;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshOrderAndPosition() async {
    setState(() => _isLoading = true);
    await _refreshOrderStatus();
    final pos = await _getQueuePosition();
    if (mounted) {
      setState(() {
        _queuePosition = pos;
        _isLoading = false;
      });
    }
  }

  String _getPositionSuffix(int pos) {
    if (pos % 10 == 1 && pos % 100 != 11) return 'st';
    if (pos % 10 == 2 && pos % 100 != 12) return 'nd';
    if (pos % 10 == 3 && pos % 100 != 13) return 'rd';
    return 'th';
  }

  String _estimateWaitTime(int? position) {
    if (position == null || position < 1) return '';
    final minutes = position * 4;
    if (minutes < 10) return '<10 min';
    if (minutes < 60) return '~${minutes} min';
    return '~${(minutes / 60).floor()} h ${minutes % 60} min';
  }

  Future<void> _processScannedQr(String rawValue) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _feedbackMessage = null;
      _isSuccess = false;
    });

    String? userMessage;
    bool hasWarning = false;

    try {
      final json = jsonDecode(rawValue.trim()) as Map<String, dynamic>;

      if (json['v'] != '1.0') {
        throw const FormatException('unsupported-version');
      }

      final scannedOrderId = (json['oid']?.toString() ?? '').trim();
      final scannedCode    = (json['code']?.toString() ?? '').trim();
      final scannedStationRaw = json['sid']?.toString();
      final expStr = json['exp'] as String?;

      if (scannedOrderId.isEmpty || scannedCode.isEmpty || expStr == null) {
        throw const FormatException('missing-fields');
      }

      if (scannedCode.length != 4 || !RegExp(r'^\d{4}$').hasMatch(scannedCode)) {
        throw const FormatException('invalid-code-format');
      }

      if (scannedOrderId != widget.orderId) {
        throw const FormatException('wrong-order');
      }

      final exp = DateTime.tryParse(expStr)?.toUtc();
      final now = DateTime.now().toUtc();
      if (exp == null || exp.isBefore(now)) {
        throw const FormatException('expired');
      }

      final iatStr = json['iat'] as String?;
      if (iatStr != null) {
        final iat = DateTime.tryParse(iatStr)?.toUtc();
        if (iat != null && iat.isAfter(now.add(const Duration(minutes: 15)))) {
          throw const FormatException('invalid-timestamp');
        }
      }

      final row = await AppApi.preorder(widget.orderId);
      if (row == null) {
        throw const FormatException('order-not-found');
      }

      final dbCode = (row['confirmation_code'] as String?)?.trim() ?? '';
      final currentStatus = (row['status'] as String?)?.toLowerCase().trim() ?? '';

      if (dbCode.isEmpty) {
        throw const FormatException('no-confirmation-code');
      }

      if (dbCode != scannedCode) {
        throw const FormatException('incorrect-code');
      }

      if (!['waiting', 'pending', 'confirmed', 'ready'].contains(currentStatus)) {
        throw FormatException('cannot-collect-$currentStatus');
      }

      final dbStation = _normalizeStationId(row['station_id']);
      final scannedStation = _normalizeStationId(scannedStationRaw);
      if (dbStation.isNotEmpty && scannedStation.isNotEmpty && dbStation != scannedStation) {
        hasWarning = true;
      }

      // Complete the order on the backend (validates the confirmation code).
      await AppApi.completePreorder(widget.orderId, scannedCode);

      await _refreshOrderAndPosition();

      setState(() {
        _feedbackMessage = hasWarning
            ? 'Order collected successfully!\n(Station mismatch warning)'
            : 'Order collected successfully!';
        _isSuccess = true;
      });

      await Future.delayed(const Duration(seconds: 3));
      if (mounted) Navigator.pop(context);
      return;
    } on ApiException catch (e) {
      userMessage = 'Collection failed.\n${e.message}';
    } on FormatException catch (e) {
      userMessage = _humanizeQrError(e.message);
    } catch (e) {
      userMessage = 'Collection failed.\nPlease try again.\n$e';
    }

    if (mounted) {
      setState(() {
        _feedbackMessage = userMessage;
        _isSuccess = false;
      });
    }

    setState(() => _isProcessing = false);
  }

  String _humanizeQrError(String code) {
    if (code.startsWith('cannot-collect-')) {
      final status = code.replaceFirst('cannot-collect-', '');
      return 'Cannot collect — order is already $status';
    }

    return switch (code) {
      'unsupported-version'     => 'Invalid QR version',
      'missing-fields'          => 'Invalid QR format',
      'wrong-order'             => 'Wrong order ID',
      'expired'                 => 'QR has expired',
      'invalid-timestamp'       => 'Invalid QR timestamp',
      'invalid-code-format'     => 'Code must be 4 digits',
      'incorrect-code'          => 'Wrong confirmation code',
      'no-confirmation-code'    => 'No code set for this order',
      'order-not-found'         => 'Order not found',
      'update-protection-failed' => 'Order changed by someone else — try again',
      _                         => 'Invalid QR or processing error',
    };
  }

  void _openScanner() {
    if (_isProcessing) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const QRScannerScreen(),
      ),
    ).then((value) {
      if (value is String && value.trim().isNotEmpty && mounted) {
        _processScannedQr(value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusRaw = (_currentOrderData['status'] as String?)?.toLowerCase() ?? 'waiting';
    final isActive   = ['waiting', 'pending', 'confirmed', 'ready'].contains(statusRaw);
    final isCompleted = statusRaw == 'completed';
    final isCancelled = ['cancelled', 'rejected'].contains(statusRaw);

    DateTime? createdAt;
    final createdRaw = _currentOrderData['created_at'];
    if (createdRaw is String) createdAt = DateTime.tryParse(createdRaw);
    else if (createdRaw is DateTime) createdAt = createdRaw;

    final createdStr = createdAt != null
        ? DateFormat('dd MMM • HH:mm').format(createdAt.toLocal())
        : '—';

    final litersStr = (_currentOrderData['liters']?.toString() ?? '0')
        .replaceAll(RegExp(r'\.0$'), '');
    final fuelType    = fuelTypeLabel(_currentOrderData['fuel_type']?.toString());
    final stationName = _currentOrderData['station_name'] as String? ?? '—';

    final statusText = isCompleted
        ? 'Completed'
        : isActive
            ? 'Ready for collection'
            : isCancelled
                ? 'Cancelled'
                : '—';

    final statusColor = isCompleted
        ? Colors.green.shade700
        : isActive
            ? Colors.deepOrange.shade700
            : isCancelled
                ? Colors.red.shade700
                : Colors.grey.shade700;

    final waitEstimate = _estimateWaitTime(_queuePosition);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInfoRow(Icons.local_gas_station, "Station", stationName, bold: true),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.local_drink, "Fuel Type", fuelType),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.format_list_numbered, "Liters", '$litersStr L'),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.person, "Driver", driverName),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.directions_car, "Plate", driverPlate),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.calendar_today, "Ordered", createdStr),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow(
                            Icons.info_outline,
                            "Status",
                            statusText,
                            valueColor: statusColor,
                            bold: true,
                          ),
                        ),
                        if (_queuePosition != null && isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "#$_queuePosition${_getPositionSuffix(_queuePosition!)}",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.deepPurple.shade800, // ← removed const
                              ),
                            ),
                          ),
                      ],
                    ),

                    if (waitEstimate.isNotEmpty && isActive)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 20, color: Colors.deepPurple.shade700),
                            const SizedBox(width: 8),
                            Text(
                              "≈ $waitEstimate",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.deepPurple.shade800, // ← removed const
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),

                    if (_feedbackMessage != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isSuccess ? Colors.green.shade400 : Colors.red.shade400,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _isSuccess ? Icons.check_circle : Icons.error_outline,
                              color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                              size: 28,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _feedbackMessage!,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.4,
                                  color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_feedbackMessage != null) const SizedBox(height: 28),

                    if (isActive)
                      FilledButton.icon(
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 28),
                        label: const Text('Scan QR to Collect Order', style: TextStyle(fontSize: 17)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          minimumSize: const Size(double.infinity, 64),
                        ),
                        onPressed: _isProcessing ? null : _openScanner,
                      ),

                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(
                        isCompleted
                            ? 'Change Station (after collection)'
                            : isCancelled
                                ? 'Change Station (cancelled order)'
                                : 'Change Station',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        side: BorderSide(color: colorScheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        minimumSize: const Size(double.infinity, 64),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChangeStationPage(
                              orderId: widget.orderId,
                              currentStationId: _getCurrentStationId(),
                              currentStationName: stationName,
                              orderData: _currentOrderData,
                            ),
                          ),
                        ).then((updated) async {
                          if (updated == true && mounted) {
                            await _refreshOrderAndPosition();
                            setState(() {
                              _feedbackMessage = 'Station changed successfully.';
                              _isSuccess = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Station updated'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: Colors.grey.shade700),
        const SizedBox(width: 14),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(                      // ← removed const
              fontSize: 15,
              color: Colors.grey.shade700,         // ← this was the problem
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
              formats: [BarcodeFormat.qrCode],
            ),
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue?.trim();
                if (code != null && code.isNotEmpty) {
                  Navigator.pop(context, code);
                  return;
                }
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
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 40),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 300,
                          height: 300,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        const Text(
                          'Scan QR Code',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 12, color: Colors.black87)],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Align the code inside the square',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
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