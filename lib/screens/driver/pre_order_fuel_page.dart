// lib/screens/driver/pre_order_fuel_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PreOrderFuelPage extends StatefulWidget {
  final String stationId;
  final String stationName;

  const PreOrderFuelPage({
    super.key,
    required this.stationId,
    required this.stationName,
  });

  @override
  State<PreOrderFuelPage> createState() => _PreOrderFuelPageState();
}

class _PreOrderFuelPageState extends State<PreOrderFuelPage> {
  String? _fuelType;
  final _litersCtrl = TextEditingController(text: '100');
  bool _agree = false;
  bool _isSubmitting = false;

  final _fuelTypes = const ['Diesel', 'Benzene 93', 'Benzine 91'];

  String _driverName = 'Unknown Driver';
  String _driverPlate = '—';

  @override
  void dispose() {
    _litersCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPreorder() async {
    if (_fuelType == null) {
      _showSnackBar('Please select fuel type', Colors.orange);
      return;
    }

    final litersText = _litersCtrl.text.trim();
    final liters = double.tryParse(litersText) ?? 0;

    if (liters <= 0) {
      _showSnackBar('Enter valid liters amount (> 0)', Colors.orange);
      return;
    }

    if (!_agree) {
      _showSnackBar('You must accept the station rules', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null || user.email!.isEmpty) {
        throw Exception('Not signed in');
      }

      final email = user.email!.trim();

      // Try to load driver info
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userSnap.docs.isNotEmpty) {
        final data = userSnap.docs.first.data();
        _driverName = (data['driverName'] as String? ?? 'Unknown Driver').trim();
        _driverPlate = (data['plateNumber'] as String? ??
                data['targa'] as String? ??
                '—')
            .trim();
      }

      await FirebaseFirestore.instance.collection('preorders').add({
        'driverUid': user.uid,
        'driverEmail': email,
        'driverName': _driverName,
        'driverPlate': _driverPlate,
        'stationId': widget.stationId,
        'stationName': widget.stationName,
        'fuelType': _fuelType,
        'liters': liters,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
        'positionInQueue': null,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pre-order placed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Failed to place order: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bgColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Pre-order @ ${widget.stationName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fuel Type', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _fuelType,
              hint: const Text('Select fuel'),
              items: _fuelTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (value) => setState(() => _fuelType = value),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 28),
            Text('Amount', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _litersCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Liters',
                suffixText: 'L',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
            CheckboxListTile(
              value: _agree,
              onChanged: (v) => setState(() => _agree = v == true),
              title: const Text('I accept station rules & cancellation policy'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: (_fuelType != null && _agree && !_isSubmitting) ? _submitPreorder : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.8),
                    )
                  : const Text('Confirm Pre-order', style: TextStyle(fontSize: 16.5)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}