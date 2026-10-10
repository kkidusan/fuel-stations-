import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_enums.dart';
import '../../services/app_api.dart';

class StationQueuesPage extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String address;
  final bool isOpen;

  const StationQueuesPage({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.address,
    required this.isOpen,
  });

  @override
  State<StationQueuesPage> createState() => _StationQueuesPageState();
}

class _StationQueuesPageState extends State<StationQueuesPage> {
  final _formKey = GlobalKey<FormState>();

  String? _driverName;
  String? _vehiclePlate;
  String? _fuelType;
  String? _vehicleType;

  final List<String> _fuelTypes = kQueueFuelTypes;
  final List<String> _vehicleTypes = kVehicleTypes;

  bool _isJoining = false;
  bool _hasSubmitted = false;

  Timer? _refreshTimer;
  List<Map<String, dynamic>> _waitingQueue = [];
  bool _isLoadingQueue = true;

  @override
  void initState() {
    super.initState();
    _loadWaitingQueue();

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadWaitingQueue();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWaitingQueue() async {
    try {
      final rows = await AppApi.queues(widget.stationId);

      if (mounted) {
        setState(() {
          _waitingQueue = rows;
          _isLoadingQueue = false;
        });
      }
    } catch (e, st) {
      debugPrint("Queue load failed: $e\n$st");
      if (mounted) setState(() => _isLoadingQueue = false);
    }
  }

  Future<void> _joinQueue() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isJoining = true);

    try {
      await AppApi.joinQueue(
        stationId: widget.stationId,
        driverName: _driverName!.trim(),
        vehiclePlate: _vehiclePlate!.trim().toUpperCase(),
        fuelType: _fuelType!,
        vehicleType: _vehicleType!,
      );

      if (!mounted) return;

      setState(() {
        _isJoining = false;
        _hasSubmitted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully joined the queue!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context); // close bottom sheet
      _loadWaitingQueue();
    } catch (e, st) {
      debugPrint("Join failed: $e\n$st");
      if (!mounted) return;

      setState(() => _isJoining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showJoinBottomSheet() {
    if (_hasSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already joined the queue today.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.58,
        minChildSize: 0.50,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),

                  // Title & subtitle
                  const Text(
                    'Join the Queue',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your details to join',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildModernTextField(
                          label: 'Full Name',
                          icon: Icons.person_outline,
                          validator: (v) => v?.trim().isEmpty ?? true ? 'Please enter your name' : null,
                          onSaved: (v) => _driverName = v?.trim(),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 20),

                        _buildModernTextField(
                          label: 'Vehicle Plate',
                          icon: Icons.directions_car_outlined,
                          validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                          onSaved: (v) => _vehiclePlate = v?.trim()?.toUpperCase(),
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 20),

                        _buildModernDropdown(
                          label: 'Fuel Type',
                          icon: Icons.local_gas_station_outlined,
                          items: _fuelTypes,
                          value: _fuelType,
                          labelBuilder: fuelTypeLabel,
                          onChanged: (v) => setState(() => _fuelType = v),
                          validator: (v) => v == null ? 'Select fuel type' : null,
                        ),
                        const SizedBox(height: 20),

                        _buildModernDropdown(
                          label: 'Vehicle Type',
                          icon: Icons.commute_outlined,
                          items: _vehicleTypes,
                          value: _vehicleType,
                          labelBuilder: vehicleTypeLabel,
                          onChanged: (v) => setState(() => _vehicleType = v),
                          validator: (v) => v == null ? 'Select vehicle type' : null,
                        ),
                        const SizedBox(height: 36),

                        // Join Button
                        SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isJoining ? null : _joinQueue,
                            icon: _isJoining
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.8,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward, size: 20),
                            label: Text(
                              _isJoining ? 'Joining...' : 'Join Queue',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: Colors.blue.withOpacity(0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Modern Text Field ──
  Widget _buildModernTextField({
    required String label,
    required IconData icon,
    required FormFieldValidator<String> validator,
    required FormFieldSetter<String> onSaved,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      textCapitalization: textCapitalization,
      validator: validator,
      onSaved: onSaved,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 22),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 13),
      ),
    );
  }

  // ── Modern Dropdown ──
  Widget _buildModernDropdown({
    required String label,
    required IconData icon,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
    required FormFieldValidator<String> validator,
    String Function(String)? labelBuilder,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      validator: validator,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 22),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 13),
      ),
      items: items.map((e) {
        return DropdownMenuItem(
          value: e,
          child: Text(
            labelBuilder?.call(e) ?? e,
            style: const TextStyle(fontSize: 16),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stationName),
      ),
      body: _isLoadingQueue
          ? const Center(child: CircularProgressIndicator())
          : _waitingQueue.isEmpty
              ? const Center(
                  child: Text(
                    'Queue is empty',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                  itemCount: _waitingQueue.length,
                  itemBuilder: (context, i) {
                    final row = _waitingQueue[i];
                    final pos = i + 1;
                    final joinedAt =
                        DateTime.tryParse(row['joined_at']?.toString() ?? '')?.toLocal();
                    final time = joinedAt == null
                        ? '—'
                        : DateFormat('HH:mm').format(joinedAt);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[800],
                          radius: 26,
                          child: Text(
                            '$pos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          row['driver_name'] as String? ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('${row['vehicle_plate']} • ${fuelTypeLabel(row['fuel_type']?.toString())} • $time'),
                      ),
                    );
                  },
                ),
      floatingActionButton: _hasSubmitted
          ? null
          : FloatingActionButton.extended(
              onPressed: _showJoinBottomSheet,
              backgroundColor: Colors.blue[700],
              icon: const Icon(Icons.add),
              label: const Text('Join Queue'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}