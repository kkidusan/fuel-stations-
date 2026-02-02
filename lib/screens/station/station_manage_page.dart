import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StationManagePage extends StatefulWidget {
  const StationManagePage({super.key});

  @override
  State<StationManagePage> createState() => _StationManagePageState();
}

class _StationManagePageState extends State<StationManagePage> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _newFuelTypeController = TextEditingController();
  final _announcementController = TextEditingController();
  final _reportController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSavingStationInfo = false;
  bool _isStationOpen = true;
  String? _stationAutoId; // Changed from _stationId to _stationAutoId
  
  // Button loading states
  bool _isAddingFuelType = false;
  bool _isPostingAnnouncement = false;
  bool _isSubmittingReport = false;
  bool _isRefillingFuel = false;
  
  // Collapsible sections
  bool _fuelSectionExpanded = true;
  bool _announcementSectionExpanded = false;
  bool _reportSectionExpanded = false;
  bool _stationInfoExpanded = true;
  bool _advancedSettingsExpanded = false;
  
  List<String> _availableFuelTypes = [];
  Map<String, dynamic>? _fuelInventoryData;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _reports = [];
  
  // Common fuel types for dropdown
  final List<String> _commonFuelTypes = [
    'Diesel',
    'Petrol (Regular)',
    'Petrol (Premium)',
    'CNG',
    'LPG',
    'Electric',
    'Bio-Diesel',
    'Kerosene',
    'Aviation Fuel',
  ];

  @override
  void initState() {
    super.initState();
    _loadStationData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _newFuelTypeController.dispose();
    _announcementController.dispose();
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _loadStationData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _stationAutoId = data['autoID']?.toString(); // Get autoID
          _nameController.text = data['name']?.toString() ?? '';
          _addressController.text = data['address']?.toString() ?? '';
          _phoneController.text = data['phone']?.toString() ?? '';
          _descriptionController.text = data['description']?.toString() ?? '';
          _isStationOpen = data['isOpen'] ?? true;
          _availableFuelTypes = List<String>.from(data['fuelTypes'] ?? []);
        });
        
        if (_stationAutoId != null) {
          await _loadFuelInventory();
          await _loadAnnouncements();
          await _loadReports();
        }
      }
    } catch (e) {
      debugPrint('Error loading station data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFuelInventory() async {
    if (_stationAutoId == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('fuel_inventory')
          .doc(_stationAutoId!) // Use autoID as document ID
          .get();
      
      if (doc.exists) {
        setState(() {
          _fuelInventoryData = doc.data();
        });
      }
    } catch (e) {
      debugPrint('Error loading fuel inventory: $e');
    }
  }

  Future<void> _loadAnnouncements() async {
    if (_stationAutoId == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('announcements')
          .doc(_stationAutoId!) // Use autoID as document ID
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _announcements = List<Map<String, dynamic>>.from(data['announcements'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading announcements: $e');
    }
  }

  Future<void> _loadReports() async {
    if (_stationAutoId == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('reports')
          .doc(_stationAutoId!) // Use autoID as document ID
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _reports = List<Map<String, dynamic>>.from(data['reports'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
    }
  }

  // Save Station Information ONLY - Saves to current user document
  Future<void> _saveStationInfo() async {
    if (_stationAutoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Station Auto ID not found')),
      );
      return;
    }
    
    setState(() => _isSavingStationInfo = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final updateData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'description': _descriptionController.text.trim(),
        'isOpen': _isStationOpen,
        'fuelTypes': _availableFuelTypes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to current user's document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      // Update fuel inventory in separate collection using autoID
      await _updateFuelInventoryWithTypes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Station information saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving station info: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingStationInfo = false);
      }
    }
  }

  Future<void> _updateFuelInventoryWithTypes() async {
    if (_stationAutoId == null) return;
    
    try {
      Map<String, dynamic> fuels = {};
      if (_fuelInventoryData != null && _fuelInventoryData!['fuels'] != null) {
        fuels = Map<String, dynamic>.from(_fuelInventoryData!['fuels']);
      }
      
      // Add new fuel types to inventory
      for (final fuelType in _availableFuelTypes) {
        if (!fuels.containsKey(fuelType)) {
          fuels[fuelType] = {
            'currentStock': 0.0,
            'maxCapacity': 10000.0,
            'pricePerLiter': 0.0,
            'status': 'available',
            'lastRefill': DateTime.now().toIso8601String(),
          };
        }
      }
      
      // Remove deleted fuel types
      final fuelTypesToRemove = fuels.keys.where((key) => !_availableFuelTypes.contains(key)).toList();
      for (final fuelType in fuelTypesToRemove) {
        fuels.remove(fuelType);
      }
      
      // Update fuel inventory in separate collection using autoID
      await FirebaseFirestore.instance
          .collection('fuel_inventory')
          .doc(_stationAutoId!) // Use autoID
          .set({
            'stationId': _stationAutoId, // Store autoID as stationId field
            'autoID': _stationAutoId, // Also store as autoID field
            'fuels': fuels,
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
      
      await _loadFuelInventory();
    } catch (e) {
      debugPrint('Error updating fuel inventory: $e');
    }
  }

  void _showAddFuelTypeDialog() {
    String? selectedFuelType;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Fuel Type'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedFuelType,
                  decoration: const InputDecoration(
                    labelText: 'Select Fuel Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_gas_station),
                  ),
                  items: _commonFuelTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedFuelType = value);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'OR',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newFuelTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Fuel Type',
                    border: OutlineInputBorder(),
                    hintText: 'Enter custom fuel type',
                  ),
                  onChanged: (value) {
                    selectedFuelType = value;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isAddingFuelType ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isAddingFuelType ? null : () async {
                  final fuelType = _newFuelTypeController.text.trim().isNotEmpty
                      ? _newFuelTypeController.text.trim()
                      : selectedFuelType;
                  
                  if (fuelType != null && fuelType.isNotEmpty) {
                    setState(() => _isAddingFuelType = true);
                    try {
                      await _addFuelType(fuelType);
                      if (mounted) Navigator.pop(context);
                    } finally {
                      if (mounted) {
                        setState(() => _isAddingFuelType = false);
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter or select a fuel type')),
                    );
                  }
                },
                child: _isAddingFuelType
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addFuelType(String fuelType) async {
    if (!_availableFuelTypes.contains(fuelType)) {
      setState(() {
        _availableFuelTypes.add(fuelType);
      });
      _newFuelTypeController.clear();
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update fuel types in user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'fuelTypes': _availableFuelTypes,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        
        // Add to fuel inventory in separate collection using autoID
        await _addToFuelInventory(fuelType);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fuelType added to available fuels'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _addToFuelInventory(String fuelType) async {
    if (_stationAutoId == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('fuel_inventory')
          .doc(_stationAutoId!) // Use autoID
          .set({
            'fuels.$fuelType': {
              'currentStock': 0.0,
              'maxCapacity': 10000.0,
              'pricePerLiter': 0.0,
              'status': 'available',
              'lastRefill': DateTime.now().toIso8601String(),
            },
            'stationId': _stationAutoId, // Store autoID as stationId
            'autoID': _stationAutoId, // Also store as autoID
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
      
      await _loadFuelInventory();
    } catch (e) {
      debugPrint('Error adding to fuel inventory: $e');
    }
  }

  Future<void> _removeFuelType(String fuelType) async {
    setState(() {
      _availableFuelTypes.remove(fuelType);
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update fuel types in user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'fuelTypes': _availableFuelTypes,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        
        // Remove from fuel inventory in separate collection using autoID
        await FirebaseFirestore.instance
            .collection('fuel_inventory')
            .doc(_stationAutoId!) // Use autoID
            .update({
              'fuels.$fuelType': FieldValue.delete(),
              'updatedAt': DateTime.now().toIso8601String(),
            });
        
        await _loadFuelInventory();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fuelType removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error removing fuel type: $e');
    }
  }

  Future<void> _showRefillDialog(String fuelType, double currentStock) async {
    if (_isRefillingFuel) return;
    
    final result = await showDialog<double>(
      context: context,
      builder: (context) => RefillDialog(
        fuelType: fuelType,
        isRefilling: _isRefillingFuel,
      ),
    );
    
    if (result != null && result > 0) {
      setState(() => _isRefillingFuel = true);
      try {
        await _updateFuelStock(fuelType, currentStock + result);
        await _announceNewFuelArrival(fuelType, result);
      } finally {
        if (mounted) {
          setState(() => _isRefillingFuel = false);
        }
      }
    }
  }

  Future<void> _updateFuelStock(String fuelType, double newStock) async {
    if (_stationAutoId == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('fuel_inventory')
          .doc(_stationAutoId!) // Use autoID
          .update({
            'fuels.$fuelType.currentStock': newStock,
            'fuels.$fuelType.lastRefill': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
      
      await _loadFuelInventory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fuelType stock updated to ${newStock.toStringAsFixed(1)}L'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating fuel stock: $e');
    }
  }

  Future<void> _createAnnouncement() async {
    final message = _announcementController.text.trim();
    if (message.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter announcement message')),
        );
      }
      return;
    }
    if (_stationAutoId == null) return;
    
    setState(() => _isPostingAnnouncement = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newAnnouncement = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': 'New Announcement',
        'message': message,
        'type': 'general',
        'stationId': _stationAutoId, // Store autoID as stationId
        'autoID': _stationAutoId, // Also store as autoID
        'userId': user.uid,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Add announcement to array in announcements collection using autoID
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(_stationAutoId!) // Use autoID as document ID
          .set({
            'announcements': FieldValue.arrayUnion([newAnnouncement]),
            'stationId': _stationAutoId, // Store autoID as stationId
            'autoID': _stationAutoId, // Also store as autoID
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
      
      _announcementController.clear();
      await _loadAnnouncements();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating announcement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPostingAnnouncement = false);
      }
    }
  }

  Future<void> _createReport() async {
    final description = _reportController.text.trim();
    if (description.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter report description')),
        );
      }
      return;
    }
    if (_stationAutoId == null) return;
    
    setState(() => _isSubmittingReport = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newReport = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': 'Station Report',
        'description': description,
        'type': 'issue',
        'stationId': _stationAutoId, // Store autoID as stationId
        'autoID': _stationAutoId, // Also store as autoID
        'userId': user.uid,
        'status': 'pending',
        'priority': 'medium',
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Add report to array in reports collection using autoID
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(_stationAutoId!) // Use autoID as document ID
          .set({
            'reports': FieldValue.arrayUnion([newReport]),
            'stationId': _stationAutoId, // Store autoID as stationId
            'autoID': _stationAutoId, // Also store as autoID
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
      
      _reportController.clear();
      await _loadReports();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted to union successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReport = false);
      }
    }
  }

  Future<void> _announceNewFuelArrival(String fuelType, double quantity) async {
    if (_stationAutoId == null) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newAnnouncement = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': 'New Fuel Arrival! 🎉',
        'message': '$fuelType has just arrived (${quantity.toStringAsFixed(0)}L). Fresh stock available now!',
        'type': 'new_fuel',
        'stationId': _stationAutoId, // Store autoID as stationId
        'autoID': _stationAutoId, // Also store as autoID
        'userId': user.uid,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(_stationAutoId!) // Use autoID
          .set({
            'announcements': FieldValue.arrayUnion([newAnnouncement]),
            'stationId': _stationAutoId, // Store autoID as stationId
            'autoID': _stationAutoId, // Also store as autoID
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
      
      await _loadAnnouncements();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Announced new $fuelType arrival!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error announcing new fuel: $e');
    }
  }

  Map<String, dynamic>? _getFuelData(String fuelType) {
    if (_fuelInventoryData == null || _fuelInventoryData!['fuels'] == null) {
      return null;
    }
    final fuels = _fuelInventoryData!['fuels'] as Map<String, dynamic>;
    return fuels[fuelType] as Map<String, dynamic>?;
  }

  Widget _buildFuelTypeChips() {
    if (_availableFuelTypes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Column(
          children: [
            Icon(Icons.local_gas_station, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No fuel types added',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableFuelTypes.map((fuelType) {
        return Chip(
          label: Text(fuelType),
          backgroundColor: Colors.blue[50],
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () => _removeFuelType(fuelType),
        );
      }).toList(),
    );
  }

  Widget _buildFuelInventoryCard() {
    return _buildSectionCard(
      title: 'Fuel Management',
      icon: Icons.local_gas_station,
      isExpanded: _fuelSectionExpanded,
      onToggle: () => setState(() => _fuelSectionExpanded = !_fuelSectionExpanded),
      children: [
        // Add Fuel Type Button
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          child: ElevatedButton.icon(
            icon: _isAddingFuelType
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add, size: 20),
            label: _isAddingFuelType 
                ? const Text('Adding...')
                : const Text('Add Fuel Type'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.blue[50],
              foregroundColor: Colors.blue[700],
            ),
            onPressed: _isAddingFuelType ? null : _showAddFuelTypeDialog,
          ),
        ),
        
        // Fuel Types Chips
        _buildFuelTypeChips(),
        
        const SizedBox(height: 20),
        
        // Fuel Inventory
        if (_availableFuelTypes.isNotEmpty && _fuelInventoryData != null) ...[
          const Text(
            'Current Inventory',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ..._availableFuelTypes.map((fuelType) {
            final fuelData = _getFuelData(fuelType);
            if (fuelData == null) return const SizedBox.shrink();
            
            final currentStock = fuelData['currentStock']?.toDouble() ?? 0.0;
            final maxCapacity = fuelData['maxCapacity']?.toDouble() ?? 1000.0;
            final percentage = (currentStock / maxCapacity) * 100;
            final status = fuelData['status'] as String? ?? 'available';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.local_gas_station, size: 20, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fuelType,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${currentStock.toStringAsFixed(1)}L / ${maxCapacity.toStringAsFixed(0)}L',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getStatusColor(status)),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: currentStock / maxCapacity,
                    backgroundColor: Colors.grey[200],
                    color: percentage > 30 ? Colors.green : 
                           percentage > 10 ? Colors.orange : Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: percentage > 20 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton.icon(
                        icon: _isRefillingFuel
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add, size: 16),
                        label: _isRefillingFuel 
                            ? const Text('Refilling...')
                            : const Text('Refill'),
                        onPressed: _isRefillingFuel 
                            ? null 
                            : () => _showRefillDialog(fuelType, currentStock),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).where((widget) => widget != const SizedBox.shrink()),
        ],
      ],
    );
  }

  Widget _buildAnnouncementsCard() {
    return _buildSectionCard(
      title: 'Announcements',
      icon: Icons.announcement,
      isExpanded: _announcementSectionExpanded,
      onToggle: () => setState(() => _announcementSectionExpanded = !_announcementSectionExpanded),
      children: [
        // New announcement input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              TextField(
                controller: _announcementController,
                decoration: const InputDecoration(
                  hintText: 'Type your announcement here...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: _isPostingAnnouncement
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, size: 16),
                  label: _isPostingAnnouncement
                      ? const Text('Posting...')
                      : const Text('Post Announcement'),
                  onPressed: _isPostingAnnouncement ? null : _createAnnouncement,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Recent announcements
        if (_announcements.isNotEmpty) ...[
          const Text(
            'Recent Announcements',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ..._announcements.take(3).map((announcement) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _getAnnouncementIcon(announcement['type'] as String),
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          announcement['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          announcement['message'] as String,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(announcement['createdAt']),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildReportsCard() {
    return _buildSectionCard(
      title: 'Union Reports',
      icon: Icons.report_problem,
      isExpanded: _reportSectionExpanded,
      onToggle: () => setState(() => _reportSectionExpanded = !_reportSectionExpanded),
      children: [
        // New report input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              TextField(
                controller: _reportController,
                decoration: const InputDecoration(
                  hintText: 'Describe your issue or suggestion...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: _isSubmittingReport
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.report, size: 16),
                  label: _isSubmittingReport
                      ? const Text('Submitting...')
                      : const Text('Submit Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                  ),
                  onPressed: _isSubmittingReport ? null : _createReport,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Recent reports
        if (_reports.isNotEmpty) ...[
          const Text(
            'Recent Reports',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ..._reports.take(3).map((report) {
            final priority = report['priority'] as String;
            final status = report['status'] as String;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(priority),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      priority[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _getStatusColor(status)),
                              ),
                              child: Text(
                                status.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDate(report['createdAt']),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Row(
            children: [
              Icon(icon, color: Colors.blue, size: 22),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          trailing: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.grey[600],
          ),
          onExpansionChanged: (expanded) => onToggle(),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationInfoCard() {
    return _buildSectionCard(
      title: 'Station Information',
      icon: Icons.business,
      isExpanded: _stationInfoExpanded,
      onToggle: () => setState(() => _stationInfoExpanded = !_stationInfoExpanded),
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Station Name',
            prefixIcon: Icon(Icons.business),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description (Optional)',
            prefixIcon: Icon(Icons.description),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildAdvancedSettingsCard() {
    return _buildSectionCard(
      title: 'Advanced Settings',
      icon: Icons.settings,
      isExpanded: _advancedSettingsExpanded,
      onToggle: () => setState(() => _advancedSettingsExpanded = !_advancedSettingsExpanded),
      children: [
        // Station Auto ID
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Station Auto ID',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        _stationAutoId ?? 'Not available',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.content_copy),
                    tooltip: 'Copy to clipboard',
                    onPressed: _stationAutoId == null 
                        ? null 
                        : () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Auto ID copied to clipboard')),
                          );
                        },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'This is your unique station identifier (Auto ID)',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Station Status
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.circle,
                color: _isStationOpen ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isStationOpen ? 'Station is OPEN' : 'Station is CLOSED',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isStationOpen ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isStationOpen 
                          ? 'Customers can place orders'
                          : 'No new orders will be accepted',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isStationOpen,
                onChanged: (value) {
                  setState(() => _isStationOpen = value);
                },
                activeThumbColor: Colors.green,
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getAnnouncementIcon(String type) {
    switch (type) {
      case 'new_fuel':
        return Icons.local_gas_station;
      case 'price_change':
        return Icons.attach_money;
      case 'maintenance':
        return Icons.build;
      default:
        return Icons.announcement;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
      case 'resolved':
        return Colors.green;
      case 'in-use':
      case 'pending':
      case 'in_progress':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Station'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isSavingStationInfo
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isSavingStationInfo ? null : _saveStationInfo,
            tooltip: 'Save Station Information',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading station data...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStationInfoCard(),
                  const SizedBox(height: 16),
                  _buildFuelInventoryCard(),
                  const SizedBox(height: 16),
                  _buildAnnouncementsCard(),
                  const SizedBox(height: 16),
                  _buildReportsCard(),
                  const SizedBox(height: 16),
                  _buildAdvancedSettingsCard(),
                  
                  const SizedBox(height: 24),
                  
                  // Save Button - Saves everything
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: _isSavingStationInfo
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save, size: 20),
                      label: _isSavingStationInfo
                          ? const Text('Saving...')
                          : const Text(
                              'Save All Changes',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                      onPressed: _isSavingStationInfo ? null : _saveStationInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

class RefillDialog extends StatefulWidget {
  final String fuelType;
  final bool isRefilling;

  const RefillDialog({super.key, required this.fuelType, this.isRefilling = false});

  @override
  State<RefillDialog> createState() => _RefillDialogState();
}

class _RefillDialogState extends State<RefillDialog> {
  final _quantityController = TextEditingController();
  bool _announceArrival = true;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.local_gas_station, color: Colors.blue),
          const SizedBox(width: 8),
          Text('Refill ${widget.fuelType}'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Quantity (Liters)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.opacity),
              suffixText: 'L',
              filled: true,
              fillColor: Colors.grey[50],
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _announceArrival,
                  onChanged: widget.isRefilling ? null : (value) {
                    setState(() => _announceArrival = value ?? true);
                  },
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Announce New Arrival',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Notify customers about fresh stock',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.isRefilling ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: widget.isRefilling ? null : () {
            final quantity = double.tryParse(_quantityController.text) ?? 0;
            if (quantity > 0) {
              Navigator.pop(context, quantity);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a valid quantity')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
          ),
          child: widget.isRefilling
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Add Stock'),
        ),
      ],
    );
  }
}