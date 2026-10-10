import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';

class PreOrderFuelPage extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String dieselPrice;
  final String benzenePrice; // still using this name from parent widget
  final VoidCallback? onOrderSuccess;

  const PreOrderFuelPage({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.dieselPrice,
    required this.benzenePrice,
    this.onOrderSuccess,
  });

  @override
  State<PreOrderFuelPage> createState() => _PreOrderFuelPageState();
}

class _PreOrderFuelPageState extends State<PreOrderFuelPage> {
  String? selectedFuelType; // will be 'diesel' or 'petrol'
  bool useCustomAmount = false;
  final litersController = TextEditingController(text: '50.0');
  bool acceptTerms = true;
  bool isSubmitting = false;
  bool isLoadingDriver = true;

  String driverName = 'Loading...';
  String driverPlate = '—';

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
  }

  @override
  void dispose() {
    litersController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverInfo() async {
    setState(() => isLoadingDriver = true);

    final user = AuthService.currentUser;
    final displayName = user?.displayName?.trim();
    final plate = user?.plate?.trim().toUpperCase();

    if (mounted) {
      setState(() {
        driverName = (displayName == null || displayName.isEmpty)
            ? 'Unknown Driver'
            : displayName;
        driverPlate = (plate == null || plate.isEmpty) ? '—' : plate;
        isLoadingDriver = false;
      });
    }
  }

  double get currentLiters {
    final text = litersController.text.trim();
    if (text.isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }

  double get pricePerLiter {
    if (selectedFuelType == null) return 0.0;
    
    // Map internal type → price field from widget
    final priceStr = selectedFuelType == 'diesel' 
        ? widget.dieselPrice 
        : widget.benzenePrice;
    
    return double.tryParse(priceStr.trim()) ?? 0.0;
  }

  double get estimatedTotal => currentLiters * pricePerLiter;

  bool get canSubmit =>
      selectedFuelType != null &&
      currentLiters > 0 &&
      acceptTerms &&
      !isSubmitting &&
      pricePerLiter > 0;

  String _generateConfirmationCode() {
    return (1000 + _random.nextInt(9000)).toString();
  }

  // Maps what user sees → what goes to database
  String _getDatabaseFuelType(String? uiType) {
    if (uiType == null) return 'unknown';
    if (uiType == 'diesel') return 'diesel';
    if (uiType == 'petrol') return 'petrol';
    return 'unknown';
  }

  String _getDisplayFuelType(String? dbType) {
    if (dbType == 'diesel') return 'Diesel';
    if (dbType == 'petrol') return 'Benzene';
    return '—';
  }

  Future<void> _submitOrder() async {
    if (!canSubmit) return;

    setState(() => isSubmitting = true);

    String? confirmationCode;

    try {
      final user = AuthService.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      confirmationCode = _generateConfirmationCode();

      final dbFuelType = _getDatabaseFuelType(selectedFuelType);

      // POST /api/preorders → creates the order and returns the saved row
      // (including its confirmation_code).
      await AppApi.createPreorder({
        'driver_uid': user.uid,
        'driver_email': user.email.trim(),
        'driver_name': driverName.trim(),
        'driver_plate': driverPlate.trim(),
        'station_id': widget.stationId.trim(),
        'station_name': widget.stationName.trim(),
        'fuel_type': dbFuelType,
        'price_per_liter': pricePerLiter,
        'liters': currentLiters,
        'total_amount': estimatedTotal,
        'is_custom_amount': useCustomAmount,
        'confirmation_code': confirmationCode,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pre-order placed! Code: $confirmationCode'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      await _showConfirmationDialog(confirmationCode!);

      widget.onOrderSuccess?.call();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order:\n${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order:\n$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> _showConfirmationDialog(String code) async {
    final displayFuel = _getDisplayFuelType(selectedFuelType);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 22),
            SizedBox(width: 10),
            Text('Confirmed', style: TextStyle(fontSize: 18.5)),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Show this code to the attendant',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.shade300, width: 1.8),
              ),
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: Colors.blueGrey.shade800,
                ),
              ),
            ),

            const SizedBox(height: 18),

            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _summaryRow('Fuel', displayFuel, fontSize: 13),
                    _summaryRow('Amount', '${currentLiters.toStringAsFixed(1)} L', fontSize: 13),
                    const Divider(height: 12, thickness: 1),
                    _summaryRow(
                      'Total',
                      'ETB ${estimatedTotal.toStringAsFixed(0)}',
                      isTotal: true,
                      fontSize: 14.5,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(fontSize: 13.5)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.stationName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 1),
            Text(
              isLoadingDriver
                  ? 'Loading driver...'
                  : '$driverName • $driverPlate   |   ID: ${widget.stationId}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (isLoadingDriver)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Select Fuel Type',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _fuelOption('Diesel', Colors.blueGrey, Icons.local_gas_station)),
                  const SizedBox(width: 12),
                  Expanded(child: _fuelOption('Benzene', Colors.amber, Icons.local_gas_station)),
                ],
              ),
              const SizedBox(height: 24),
              if (selectedFuelType != null)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Custom amount',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            Switch(
                              value: useCustomAmount,
                              activeColor: Colors.blue,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (v) {
                                setState(() {
                                  useCustomAmount = v;
                                  if (!v) litersController.text = '50.0';
                                });
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        if (useCustomAmount)
                          TextField(
                            controller: litersController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Liters',
                              suffixText: 'L',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            style: const TextStyle(fontSize: 15),
                            onChanged: (_) => setState(() {}),
                          )
                        else
                          const Text('Default: 50 L', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: acceptTerms,
                onChanged: (v) => setState(() => acceptTerms = v == true),
                title: const Text('I accept station rules & terms', style: TextStyle(fontSize: 13)),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              if (selectedFuelType != null)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _summaryRow('Fuel', _getDisplayFuelType(selectedFuelType), fontSize: 13.5),
                        _summaryRow('Amount', '${currentLiters.toStringAsFixed(1)} L', fontSize: 13.5),
                        const Divider(height: 16),
                        _summaryRow('Total', 'ETB ${estimatedTotal.toStringAsFixed(0)}',
                            isTotal: true, fontSize: 15.5),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Icon(Icons.local_gas_station, size: 20),
                label: Text(isSubmitting ? 'Placing...' : 'Confirm Pre-order',
                    style: const TextStyle(fontSize: 15)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: canSubmit ? _submitOrder : null,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fuelOption(String label, Color color, IconData icon) {
    // 'diesel' or 'petrol' internally
    final internalType = label.toLowerCase() == 'benzene' ? 'petrol' : label.toLowerCase();
    final selected = selectedFuelType == internalType;

    return GestureDetector(
      onTap: () => setState(() => selectedFuelType = internalType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize - 1, color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Colors.green[800] : null,
            ),
          ),
        ],
      ),
    );
  }
}