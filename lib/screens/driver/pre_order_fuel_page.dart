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
  String? _selectedPumpId;
  String? _selectedFuelType;
  double? _customLiters;
  final _litersCtrl = TextEditingController(text: '100');
  bool _agree = false;
  bool _isSubmitting = false;
  bool _isLoadingPumps = true;
  bool _useCustomAmount = false;

  String _driverName = 'Unknown Driver';
  String _driverPlate = '—';

  List<Map<String, dynamic>> _availablePumps = [];

  @override
  void initState() {
    super.initState();
    _loadAvailablePumps();
    _loadDriverInfo();
  }

  @override
  void dispose() {
    _litersCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDriverInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null || user.email!.isEmpty) return;

      final email = user.email!.trim();

      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userSnap.docs.isNotEmpty) {
        final data = userSnap.docs.first.data();
        setState(() {
          _driverName = (data['driverName'] as String? ?? 'Unknown Driver').trim();
          _driverPlate = (data['plateNumber'] as String? ??
                  data['targa'] as String? ??
                  '—')
              .trim();
        });
      }
    } catch (e) {
      debugPrint('Error loading driver info: $e');
    }
  }

  Future<void> _loadAvailablePumps() async {
    setState(() => _isLoadingPumps = true);
    try {
      final pumpsDoc = await FirebaseFirestore.instance
          .collection('station_pumps')
          .doc(widget.stationId)
          .get();

      if (pumpsDoc.exists) {
        final data = pumpsDoc.data() as Map<String, dynamic>;
        final allPumps = List<Map<String, dynamic>>.from(data['pumps'] ?? []);
        
        // Show all pumps but mark unavailable ones
        setState(() {
          _availablePumps = allPumps;
        });
      }
    } catch (e) {
      debugPrint('Error loading pumps: $e');
      _showSnackBar('Failed to load pumps: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoadingPumps = false);
      }
    }
  }

  bool _isPumpAvailable(Map<String, dynamic> pump) {
    final status = pump['status']?.toString() ?? '';
    final isActive = pump['isActive'] ?? true;
    return status == 'available' && isActive == true;
  }

  String _getStatusText(Map<String, dynamic> pump) {
    final status = pump['status']?.toString() ?? 'unknown';
    switch (status) {
      case 'available':
        return 'Available';
      case 'in-use':
        return 'In Use';
      case 'maintenance':
        return 'Under Maintenance';
      case 'offline':
        return 'Offline';
      default:
        return 'Unknown Status';
    }
  }

  Color _getStatusColor(Map<String, dynamic> pump) {
    final status = pump['status']?.toString() ?? 'unknown';
    switch (status) {
      case 'available':
        return Colors.green;
      case 'in-use':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      case 'offline':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Helper method to get liters for calculation
  double _getLitersForCalculation(Map<String, dynamic> pump) {
    if (_useCustomAmount && _selectedPumpId == pump['id']) {
      final customLiters = double.tryParse(_litersCtrl.text.trim()) ?? 0;
      return customLiters > 0 ? customLiters : 0;
    } else if (_selectedPumpId == pump['id']) {
      return pump['maxOrderLimit']?.toDouble() ?? 100.0;
    }
    return 0;
  }

  // Helper method to get order amount text
  String _getOrderAmountText(Map<String, dynamic> pump) {
    if (_useCustomAmount && _selectedPumpId == pump['id']) {
      final customLiters = double.tryParse(_litersCtrl.text.trim()) ?? 0;
      return customLiters > 0 ? '${customLiters.toStringAsFixed(1)}L' : 'Custom Amount';
    } else if (_selectedPumpId == pump['id']) {
      final maxOrder = pump['maxOrderLimit']?.toDouble() ?? 100.0;
      return '${maxOrder.toStringAsFixed(1)}L';
    }
    final maxOrder = pump['maxOrderLimit']?.toDouble() ?? 100.0;
    return '${maxOrder.toStringAsFixed(1)}L';
  }

  Future<void> _submitPreorder() async {
    if (_selectedPumpId == null) {
      _showSnackBar('Please select a pump', Colors.orange);
      return;
    }

    final selectedPump = _availablePumps.firstWhere(
      (pump) => pump['id'] == _selectedPumpId,
      orElse: () => {},
    );

    if (selectedPump.isEmpty) {
      _showSnackBar('Selected pump not found', Colors.red);
      return;
    }

    // Check if pump is available
    if (!_isPumpAvailable(selectedPump)) {
      final status = _getStatusText(selectedPump);
      _showSnackBar('Cannot select pump: $status', Colors.red);
      return;
    }

    double liters;
    if (_useCustomAmount) {
      final litersText = _litersCtrl.text.trim();
      liters = double.tryParse(litersText) ?? 0;
      if (liters <= 0) {
        _showSnackBar('Enter valid liters amount (> 0)', Colors.orange);
        return;
      }
      
      // Check if custom amount exceeds pump's max order limit
      final maxOrder = selectedPump['maxOrderLimit']?.toDouble() ?? 100.0;
      if (liters > maxOrder) {
        _showSnackBar('Amount exceeds pump limit (max: ${maxOrder}L)', Colors.orange);
        return;
      }
    } else {
      // Use pump's default max order limit
      liters = selectedPump['maxOrderLimit']?.toDouble() ?? 100.0;
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

      await FirebaseFirestore.instance.collection('preorders').add({
        'driverUid': user.uid,
        'driverEmail': email,
        'driverName': _driverName,
        'driverPlate': _driverPlate,
        'stationId': widget.stationId,
        'stationName': widget.stationName,
        'pumpId': _selectedPumpId,
        'pumpNumber': selectedPump['pumpNumber'] ?? 'N/A',
        'pumpName': selectedPump['pumpName'] ?? 'Unnamed Pump',
        'fuelType': selectedPump['fuelType'] ?? 'Unknown',
        'pricePerLiter': selectedPump['pricePerLiter']?.toDouble() ?? 0.0,
        'liters': liters,
        'totalAmount': liters * (selectedPump['pricePerLiter']?.toDouble() ?? 0.0),
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
        'positionInQueue': null,
        'isCustomAmount': _useCustomAmount,
        'maxOrderLimit': selectedPump['maxOrderLimit']?.toDouble() ?? 100.0,
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

  void _showUnavailableMessage(Map<String, dynamic> pump) {
    final status = _getStatusText(pump);
    _showSnackBar('Sorry, pump is currently $status', Colors.red);
  }

  Widget _buildPumpCard(Map<String, dynamic> pump) {
    final isAvailable = _isPumpAvailable(pump);
    final isSelected = _selectedPumpId == pump['id'];
    final pumpNumber = pump['pumpNumber']?.toString() ?? 'N/A';
    final pumpName = pump['pumpName']?.toString() ?? 'Unnamed Pump';
    final fuelType = pump['fuelType']?.toString() ?? 'Unknown';
    final price = pump['pricePerLiter']?.toDouble() ?? 0.0;
    final maxOrder = pump['maxOrderLimit']?.toDouble() ?? 100.0;
    final fuelLevel = pump['currentFuelLevel']?.toDouble() ?? 0.0;
    final status = pump['status']?.toString() ?? 'unknown';

    // Calculate order amount based on selection
    final orderAmount = _getLitersForCalculation(pump);
    final orderAmountText = _getOrderAmountText(pump);

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue : 
                 isAvailable ? Colors.grey[300]! : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isAvailable ? null : Colors.grey[50],
      child: InkWell(
        onTap: isAvailable ? () {
          setState(() {
            _selectedPumpId = pump['id'];
            _selectedFuelType = fuelType;
            // Set default liters to pump's max order limit
            if (!_useCustomAmount) {
              _litersCtrl.text = maxOrder.toStringAsFixed(1);
            } else {
              // Initialize custom amount to half of max order
              _litersCtrl.text = (maxOrder / 2).toStringAsFixed(1);
            }
          });
        } : () => _showUnavailableMessage(pump),
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isAvailable ? 1.0 : 0.7,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isAvailable ? Colors.blue[100] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.local_gas_station,
                                size: 20,
                                color: isAvailable ? Colors.blue : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pumpName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isAvailable ? Colors.black : Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  'Pump #$pumpNumber',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isAvailable ? Colors.grey : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        if (isSelected && isAvailable)
                          const Icon(Icons.check_circle, color: Colors.green, size: 24),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(pump).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _getStatusColor(pump)),
                          ),
                          child: Text(
                            _getStatusText(pump).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(pump),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),

                // Fuel Type and Price
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fuelType,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isAvailable ? Colors.black : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Fuel Type',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isAvailable ? Colors.green : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Price/Liter',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Order Amount and Fuel Level
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              orderAmountText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isAvailable ? Colors.black : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isSelected && _useCustomAmount ? 'Custom Amount' : 'Max Order',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${fuelLevel.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: fuelLevel > 20 ? 
                                          (isAvailable ? Colors.green : Colors.grey[600]) : 
                                          Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: fuelLevel / 100,
                                    backgroundColor: Colors.grey[200],
                                    color: fuelLevel > 20 ? 
                                          (isAvailable ? Colors.green : Colors.grey[400]) : 
                                          Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Fuel Level',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Show estimated total if selected
                if (isSelected && orderAmount > 0)
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Estimated Total:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              '₹${(price * orderAmount).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isAvailable ? () {
                      setState(() {
                        _selectedPumpId = pump['id'];
                        _selectedFuelType = fuelType;
                        if (!_useCustomAmount) {
                          _litersCtrl.text = maxOrder.toStringAsFixed(1);
                        } else {
                          _litersCtrl.text = (maxOrder / 2).toStringAsFixed(1);
                        }
                      });
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAvailable 
                          ? (isSelected ? Colors.blue[700] : Colors.grey[200])
                          : Colors.grey[100],
                      foregroundColor: isAvailable 
                          ? (isSelected ? Colors.white : Colors.grey[700])
                          : Colors.grey[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isAvailable 
                          ? (isSelected ? 'Selected' : 'Select This Pump')
                          : 'Currently ${_getStatusText(pump)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
            // Driver Info
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 20, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Name',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _driverName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.directions_car, size: 20, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Plate Number',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _driverPlate,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Available Pumps Section
            Text(
              'Station Pumps',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only pumps with "Available" status can be selected',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 16),

            // Status Legend
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Legend',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildStatusLegendItem('Available', Colors.green),
                        _buildStatusLegendItem('In Use', Colors.orange),
                        _buildStatusLegendItem('Maintenance', Colors.red),
                        _buildStatusLegendItem('Offline', Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_isLoadingPumps)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading pumps...'),
                    ],
                  ),
                ),
              )
            else if (_availablePumps.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_gas_station,
                      size: 60,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Pumps Found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This station has no pumps configured',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      onPressed: _loadAvailablePumps,
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _availablePumps.map((pump) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildPumpCard(pump),
                  );
                }).toList(),
              ),

            // Show message if no available pumps
            if (!_isLoadingPumps && _availablePumps.isNotEmpty)
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Stream.value(_availablePumps),
                builder: (context, snapshot) {
                  final availableCount = _availablePumps.where((pump) => _isPumpAvailable(pump)).length;
                  if (availableCount == 0) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No pumps are currently available. Check back later.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),

            const SizedBox(height: 24),

            // Custom Amount Toggle (only shown if there's at least one available pump)
            if (!_isLoadingPumps && _availablePumps.any((pump) => _isPumpAvailable(pump)))
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Custom Amount',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Switch(
                            value: _useCustomAmount,
                            onChanged: _selectedPumpId != null ? (value) {
                              setState(() => _useCustomAmount = value);
                              if (value && _selectedPumpId != null) {
                                final pump = _availablePumps.firstWhere(
                                  (p) => p['id'] == _selectedPumpId,
                                  orElse: () => {},
                                );
                                if (pump.isNotEmpty) {
                                  final maxOrder = pump['maxOrderLimit']?.toDouble() ?? 100.0;
                                  _litersCtrl.text = (maxOrder / 2).toStringAsFixed(1);
                                }
                              } else if (!value && _selectedPumpId != null) {
                                final pump = _availablePumps.firstWhere(
                                  (p) => p['id'] == _selectedPumpId,
                                  orElse: () => {},
                                );
                                if (pump.isNotEmpty) {
                                  final maxOrder = pump['maxOrderLimit']?.toDouble() ?? 100.0;
                                  _litersCtrl.text = maxOrder.toStringAsFixed(1);
                                }
                              }
                            } : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _useCustomAmount
                            ? 'Enter custom liters amount (replaces max order limit)'
                            : 'Using pump\'s maximum order limit',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_useCustomAmount) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _litersCtrl,
                          enabled: _selectedPumpId != null,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            // Update UI when custom amount changes
                            if (_selectedPumpId != null) {
                              setState(() {});
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Custom Liters',
                            hintText: 'Enter amount in liters',
                            suffixText: 'L',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                        if (_selectedPumpId != null)
                          StreamBuilder<Map<String, dynamic>?>(
                            stream: Stream.value(_availablePumps.firstWhere(
                              (p) => p['id'] == _selectedPumpId,
                              orElse: () => {},
                            )),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                final pump = snapshot.data!;
                                final maxOrder = pump['maxOrderLimit']?.toDouble() ?? 100.0;
                                final customLiters = double.tryParse(_litersCtrl.text.trim()) ?? 0;
                                final price = pump['pricePerLiter']?.toDouble() ?? 0.0;
                                final estimatedTotal = customLiters * price;

                                return Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Maximum allowed: ${maxOrder.toStringAsFixed(1)}L',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        if (customLiters > 0)
                                          Text(
                                            'Estimated: ₹${estimatedTotal.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (customLiters > maxOrder)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '⚠ Amount exceeds maximum limit',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Terms and Conditions
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Terms & Conditions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Fuel prices may change without prior notice\n'
                      '• Orders can be cancelled before pump assignment\n'
                      '• Station reserves right to modify order limits\n'
                      '• Queue position is determined automatically',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _agree,
                      onChanged: (v) => setState(() => _agree = v == true),
                      title: const Text('I accept the terms & conditions'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      tileColor: Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Order Summary
            if (_selectedPumpId != null && _availablePumps.any((pump) => pump['id'] == _selectedPumpId && _isPumpAvailable(pump)))
              StreamBuilder<Map<String, dynamic>?>(
                stream: Stream.value(_availablePumps.firstWhere(
                  (p) => p['id'] == _selectedPumpId,
                  orElse: () => {},
                )),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    final pump = snapshot.data!;
                    final price = pump['pricePerLiter']?.toDouble() ?? 0.0;
                    double liters;
                    if (_useCustomAmount) {
                      liters = double.tryParse(_litersCtrl.text.trim()) ?? 0;
                    } else {
                      liters = pump['maxOrderLimit']?.toDouble() ?? 100.0;
                    }
                    final total = price * liters;

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Order Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Pump:', style: TextStyle(color: Colors.grey)),
                                Text(
                                  pump['pumpName']?.toString() ?? 'Unnamed Pump',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Fuel Type:', style: TextStyle(color: Colors.grey)),
                                Text(
                                  pump['fuelType']?.toString() ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Price per Liter:', style: TextStyle(color: Colors.grey)),
                                Text(
                                  '₹${price.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _useCustomAmount ? 'Custom Amount:' : 'Max Order Amount:',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  '${liters.toStringAsFixed(1)}L',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            if (_useCustomAmount) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Max Order Limit:', style: TextStyle(color: Colors.grey)),
                                  Text(
                                    '${pump['maxOrderLimit']?.toStringAsFixed(1) ?? '100.0'}L',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '₹${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),

            const SizedBox(height: 24),

            // Confirm Order Button
            FilledButton(
              onPressed: (_selectedPumpId != null && 
                         _availablePumps.any((pump) => pump['id'] == _selectedPumpId && _isPumpAvailable(pump)) && 
                         _agree && 
                         !_isSubmitting) 
                  ? _submitPreorder 
                  : null,
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
                  : const Text(
                      'Confirm Pre-order',
                      style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}