import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/api_client.dart';
import '../../services/app_api.dart';

class StationPreorderDetailPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final bool isFromHistory;

  const StationPreorderDetailPage({
    super.key,
    required this.orderId,
    required this.orderData,
    this.isFromHistory = false,
  });

  @override
  State<StationPreorderDetailPage> createState() => _StationPreorderDetailPageState();
}

class _StationPreorderDetailPageState extends State<StationPreorderDetailPage> {
  String _normalizeStationId(String? raw) {
    if (raw == null) return '';
    var s = raw.toString().trim().toUpperCase();
    s = s.replaceAll(RegExp(r'[\s\-_·|•]'), '');
    return s;
  }

  String _getNormalizedStationId() {
    const keys = ['station_id', 'stationId', 'station_code', 'stationID', 'id'];
    for (final key in keys) {
      if (widget.orderData.containsKey(key)) {
        final norm = _normalizeStationId(widget.orderData[key]?.toString());
        if (norm.isNotEmpty) return norm;
      }
    }
    return '';
  }

  Future<String> _fetchConfirmationCode() async {
    try {
      final row = await AppApi.preorder(widget.orderId);
      if (row != null) {
        final code = (row['confirmation_code']?.toString() ?? '').trim();
        if (code.length == 4 && RegExp(r'^\d{4}$').hasMatch(code)) {
          return code;
        }
      }
      return '';
    } catch (e) {
      debugPrint('Error fetching confirmation code: $e');
      return '';
    }
  }

  void _showQrCodeDialog() async {
    final stationId = _getNormalizedStationId();
    if (stationId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No station ID available for QR'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmationCode = await _fetchConfirmationCode();

    if (confirmationCode.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot generate QR — no valid confirmation code found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nowUtc = DateTime.now().toUtc();
    final expires = nowUtc.add(const Duration(hours: 4));

    final qrData = {
      'v': '1.0',
      'oid': widget.orderId,
      'sid': stationId,
      'code': confirmationCode,           // ← Real verification code (4 digits)
      'iat': nowUtc.toIso8601String(),
      'exp': expires.toIso8601String(),
      // Optional — helpful for display or logging on station side
      'fuel': widget.orderData['fuel_type']?.toString().trim().toUpperCase() ?? 'UNKNOWN',
      'liters': widget.orderData['liters']?.toString() ?? '0',
      'driver': widget.orderData['driver_name']?.toString().trim() ?? '',
      'plate': widget.orderData['driver_plate']?.toString().trim().toUpperCase() ?? '',
    };

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Collection QR', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: jsonEncode(qrData),
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              'Order #${widget.orderId}  •  $stationId',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Code: $confirmationCode',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Valid until ${DateFormat('HH:mm – dd MMM yyyy').format(expires.toLocal())}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showManualCodeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ManualCodeDialog(
        orderId: widget.orderId,
        stationId: _getNormalizedStationId(),
        onSuccess: _handleCollectionSuccess,
      ),
    );
  }

  void _handleCollectionSuccess() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order collected successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        Navigator.of(context).pop(true); // success → trigger refresh in list page
      }
    });
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  ({String label, Color color}) _getStatusInfo(String status) {
    final s = status.toLowerCase().trim();
    return switch (s) {
      'waiting' || 'pending'   => (label: 'Waiting',   color: Colors.orange.shade800),
      'confirmed'              => (label: 'Confirmed', color: Colors.teal.shade700),
      'ready'                  => (label: 'Ready',     color: Colors.blue.shade700),
      'completed' || 'done'    => (label: 'Completed', color: Colors.green.shade700),
      'cancelled' || 'rejected' => (label: 'Cancelled', color: Colors.red.shade700),
      _                        => (label: 'Unknown',   color: Colors.grey.shade700),
    };
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey.shade700))),
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: color ?? Colors.black87))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createdAt   = _parseDate(widget.orderData['created_at'] ?? widget.orderData['createdAt']);
    final completedAt = _parseDate(widget.orderData['completed_at']);

    final createdStr = createdAt != null ? DateFormat('dd MMM yyyy • HH:mm').format(createdAt.toLocal()) : '—';
    final completedStr = completedAt != null ? DateFormat('dd MMM yyyy • HH:mm').format(completedAt.toLocal()) : null;

    final stationId   = _getNormalizedStationId();
    final driverName  = widget.orderData['driver_name']?.toString().trim() ?? '—';
    final driverPlate = widget.orderData['driver_plate']?.toString().trim().toUpperCase() ?? '—';
    final fuelType    = widget.orderData['fuel_type']?.toString().trim().toUpperCase() ?? '—';
    final liters      = double.tryParse(widget.orderData['liters']?.toString() ?? '0') ?? 0.0;
    final status      = (widget.orderData['status'] as String?)?.toLowerCase().trim() ?? 'waiting';

    final statusInfo = _getStatusInfo(status);
    final canCollect = !widget.isFromHistory && ['waiting', 'pending', 'confirmed'].contains(status);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFromHistory ? 'Order History' : 'Pre-order Detail'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDetailRow('Status', statusInfo.label, color: statusInfo.color),
          if (stationId.isNotEmpty) _buildDetailRow('Station ID', stationId),
          if (canCollect && stationId.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Warning: No station ID detected — QR code may not work',
                style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          if (!widget.isFromHistory && widget.orderData['positionInQueue'] != null)
            _buildDetailRow('Queue Position', '#${widget.orderData['positionInQueue']}'),
          if (completedStr != null) _buildDetailRow('Completed', completedStr),
          const Divider(height: 32),
          _buildDetailRow('Fuel', fuelType),
          _buildDetailRow('Liters', '${liters.toStringAsFixed(1)} L'),
          _buildDetailRow('Driver', driverName),
          _buildDetailRow('Plate', driverPlate),
          _buildDetailRow('Ordered', createdStr),
          const SizedBox(height: 48),

          if (canCollect) ...[
            FilledButton.icon(
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Show Collection QR'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              onPressed: _showQrCodeDialog,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.pin),
              label: const Text('Enter Code Manually'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              onPressed: _showManualCodeDialog,
            ),
          ] else ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.info_outline),
              label: Text('Order is ${statusInfo.label}'),
              onPressed: null,
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
//               MANUAL CODE DIALOG
// ────────────────────────────────────────────────

class ManualCodeDialog extends StatefulWidget {
  final String orderId;
  final String stationId;
  final VoidCallback onSuccess;

  const ManualCodeDialog({
    super.key,
    required this.orderId,
    required this.stationId,
    required this.onSuccess,
  });

  @override
  State<ManualCodeDialog> createState() => _ManualCodeDialogState();
}

class _ManualCodeDialogState extends State<ManualCodeDialog> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _error;
  bool _isVerifying = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyAndCollect() async {
    if (_isVerifying || _isDisposed) return;

    final code = _codeController.text.trim();
    if (code.length != 4 || !RegExp(r'^\d{4}$').hasMatch(code)) {
      setState(() => _error = 'Enter exactly 4 digits');
      return;
    }

    setState(() {
      _error = null;
      _isVerifying = true;
    });

    try {
      final result = await _processCollection(code);

      if (!mounted || _isDisposed) return;

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: result.hasWarning ? Colors.orange : Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        if (mounted) {
          Navigator.of(context).pop();
        }

        widget.onSuccess();
      } else {
        setState(() {
          _error = result.message;
          _isVerifying = false;
        });
      }
    } catch (e) {
      if (!mounted || _isDisposed) return;

      setState(() {
        _error = 'Error: ${e.toString().split('\n').first}';
        _isVerifying = false;
      });
    }
  }

  String _normalize(String? s) {
    if (s == null) return '';
    return s.trim().toUpperCase().replaceAll(RegExp(r'[\s\-_·|•]'), '');
  }

  Future<CollectionResult> _processCollection(String code) async {
    try {
      final row = await AppApi.preorder(widget.orderId);

      if (row == null) {
        return CollectionResult(
          success: false,
          message: 'Order #${widget.orderId} not found in active preorders',
        );
      }

      final fetchedId = (row['id']?.toString() ?? '').trim();
      if (fetchedId != widget.orderId) {
        return CollectionResult(
          success: false,
          message: 'Order ID mismatch (security validation failed)',
        );
      }

      final dbCode        = (row['confirmation_code']?.toString() ?? '').trim();
      final currentStatus = (row['status']?.toString() ?? '').toLowerCase().trim();
      final dbStationId   = _normalize(row['station_id']?.toString());

      if (dbCode.isEmpty) {
        return CollectionResult(success: false, message: 'No confirmation code is set for this order');
      }

      if (dbCode != code) {
        return CollectionResult(success: false, message: 'Incorrect confirmation code');
      }

      if (!['waiting', 'pending', 'confirmed'].contains(currentStatus)) {
        return CollectionResult(
          success: false,
          message: 'Cannot collect — order is already $currentStatus',
        );
      }

      final litersValue = row['liters'];
      final liters = switch (litersValue) {
        num n   => n.toDouble(),
        String s => double.tryParse(s) ?? 0.0,
        _       => 0.0,
      };

      final fuel = (row['fuel_type']?.toString() ?? 'Unknown').trim().toUpperCase();
      final litersStr = liters.toStringAsFixed(1);

      final stationMismatch = widget.stationId.isNotEmpty &&
          dbStationId.isNotEmpty &&
          widget.stationId != dbStationId;

      // Move the order to history on the backend (validates code + status).
      await AppApi.archivePreorder(widget.orderId, code);

      final msg = stationMismatch
          ? 'Collected (station mismatch warning) — $litersStr L $fuel'
          : 'Collected successfully — $litersStr L $fuel';

      return CollectionResult(
        success: true,
        message: msg,
        hasWarning: stationMismatch,
      );
    } on ApiException catch (e) {
      debugPrint('Collection error: $e');

      final friendly = e.isNotFound
          ? 'Order no longer available'
          : 'Failed to collect order';

      return CollectionResult(
        success: false,
        message: '$friendly\n${e.message}',
      );
    } catch (e, stack) {
      debugPrint('Collection error:\n$e\n$stack');

      return CollectionResult(
        success: false,
        message: 'Failed to collect order\n${e.toString().split('\n').first}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Confirmation Code', textAlign: TextAlign.center),
      content: SizedBox(
        width: 280,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '4-digit code from driver',
                style: TextStyle(fontSize: 13.5, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _codeController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 36, letterSpacing: 12, fontWeight: FontWeight.bold),
                maxLength: 4,
                enabled: !_isVerifying,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  errorText: _error,
                  errorStyle: const TextStyle(fontSize: 13),
                  hintText: '••••',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2.5),
                  ),
                ),
                onChanged: (value) {
                  if (value.length == 4 && !_isVerifying) {
                    _verifyAndCollect();
                  }
                },
              ),
              if (_isVerifying) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(strokeWidth: 2.8),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _isVerifying ? null : _verifyAndCollect,
          child: Text(_isVerifying ? 'Verifying…' : 'Verify & Collect'),
        ),
      ],
    );
  }
}

class CollectionResult {
  final bool success;
  final String message;
  final bool hasWarning;

  CollectionResult({
    required this.success,
    required this.message,
    this.hasWarning = false,
  });
}