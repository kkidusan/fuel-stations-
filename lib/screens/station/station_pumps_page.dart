import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StationPumpsPage extends StatefulWidget {
  const StationPumpsPage({super.key, String? stationId});

  @override
  State<StationPumpsPage> createState() => _StationPumpsPageState();
}

class _StationPumpsPageState extends State<StationPumpsPage> {
  final _pumpNumberController = TextEditingController();
  final _pumpNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxOrderController = TextEditingController();
  
  bool _isLoading = false;
  bool _isAddingNew = false;
  bool _isEditing = false;
  String? _selectedFuelType;
  String? _stationAutoId; // Changed to _stationAutoId
  String? _editingPumpId;
  
  // Available fuel types from station
  List<String> _availableFuelTypes = [];
  
  // Common fuel types for dropdown
  final List<String> _commonFuelTypes = [
    'Diesel',
    'Petrol (Regular)',
    'Petrol (Premium)',
    'CNG',
    'LPG',
    'Electric',
    'Bio-Diesel',
  ];

  // Scroll controller for auto-scroll
  final ScrollController _scrollController = ScrollController();
  final FocusNode _priceFocusNode = FocusNode();
  final FocusNode _maxOrderFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadStationData();
    
    // Listen to focus changes to auto-scroll
    _priceFocusNode.addListener(_onFocusChange);
    _maxOrderFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _pumpNumberController.dispose();
    _pumpNameController.dispose();
    _priceController.dispose();
    _maxOrderController.dispose();
    _scrollController.dispose();
    _priceFocusNode.dispose();
    _maxOrderFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_priceFocusNode.hasFocus || _maxOrderFocusNode.hasFocus) {
      // Delay to let keyboard appear, then scroll
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _loadStationData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user document to fetch autoID
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _stationAutoId = data['autoID']?.toString(); // Get autoID
          _availableFuelTypes = List<String>.from(data['fuelTypes'] ?? []);
        });
        
        // If autoID doesn't exist, create it using autoID format
        if (_stationAutoId == null || _stationAutoId!.isEmpty) {
          await _createStationAutoId(user.uid);
        } else {
          // Ensure station_pumps document exists
          await _ensureStationPumpsDocument();
        }
      } else {
        // Create new station with autoID
        await _createStationAutoId(user.uid);
      }
    } catch (e) {
      debugPrint('Error loading station data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createStationAutoId(String userId) async {
    try {
      // Generate autoID: FS_WLD_XXXX (where XXXX is random number)
      final randomNum = DateTime.now().millisecondsSinceEpoch % 10000;
      final newAutoId = 'FS_WLD_${randomNum.toString().padLeft(4, '0')}';
      
      // Create stations collection document with autoID as document ID
      await FirebaseFirestore.instance
          .collection('stations')
          .doc(newAutoId) // Use autoID as document ID
          .set({
            'autoID': newAutoId, // Store as field
            'stationId': newAutoId, // Also store as stationId for compatibility
            'ownerId': userId,
            'stationName': 'Fuel Station ${newAutoId.substring(7)}',
            'fuelTypes': [],
            'pumpCount': 0,
            'totalEarnings': 0.0,
            'totalCustomers': 0,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // Update user document with autoID
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
            'autoID': newAutoId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // Create station_pumps document with autoID as document ID
      await FirebaseFirestore.instance
          .collection('station_pumps')
          .doc(newAutoId) // Use autoID as document ID
          .set({
            'autoID': newAutoId, // Store as field
            'stationId': newAutoId, // Also store as stationId for compatibility
            'pumps': [],
            'totalPumps': 0,
            'activePumps': 0,
            'maintenancePumps': 0,
            'offlinePumps': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      setState(() {
        _stationAutoId = newAutoId;
      });
      
      debugPrint('Created new station with autoID: $newAutoId');
    } catch (e) {
      debugPrint('Error creating station autoID: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating station: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _ensureStationPumpsDocument() async {
    if (_stationAutoId == null) return;
    
    try {
      // Check if station_pumps document exists
      final pumpsDoc = await FirebaseFirestore.instance
          .collection('station_pumps')
          .doc(_stationAutoId!) // Check using autoID
          .get();
      
      if (!pumpsDoc.exists) {
        // Create station_pumps document with autoID
        await FirebaseFirestore.instance
            .collection('station_pumps')
            .doc(_stationAutoId!) // Use autoID as document ID
            .set({
              'autoID': _stationAutoId, // Store as field
              'stationId': _stationAutoId, // Also store as stationId for compatibility
              'pumps': [],
              'totalPumps': 0,
              'activePumps': 0,
              'maintenancePumps': 0,
              'offlinePumps': 0,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      debugPrint('Error ensuring station pumps document: $e');
    }
  }

  Future<void> _savePump() async {
    if (_stationAutoId == null || _stationAutoId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Station Auto ID not found. Please try again.')),
        );
      }
      return;
    }

    // Validation
    if (_pumpNumberController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter pump number')),
        );
      }
      return;
    }

    if (_selectedFuelType == null || _selectedFuelType!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select fuel type')),
        );
      }
      return;
    }

    if (_priceController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter price per liter')),
        );
      }
      return;
    }

    if (_maxOrderController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter maximum order limit')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pumpNumber = _pumpNumberController.text.trim();
      final pumpName = _pumpNameController.text.trim();
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final maxOrder = double.tryParse(_maxOrderController.text.trim()) ?? 0.0;
      final timestamp = DateTime.now();
      
      // Generate autoID for pump
      final pumpId = 'PUMP_${DateTime.now().millisecondsSinceEpoch}';
      
      // Get current pumps array from station_pumps collection using autoID
      final doc = await FirebaseFirestore.instance
          .collection('station_pumps')
          .doc(_stationAutoId!) // Fetch using autoID
          .get();
      
      if (!doc.exists) {
        // Create document if it doesn't exist
        await _ensureStationPumpsDocument();
      }
      
      final data = doc.data() as Map<String, dynamic>? ?? {};
      List<Map<String, dynamic>> pumps = List<Map<String, dynamic>>.from(data['pumps'] ?? []);
      
      if (_isEditing && _editingPumpId != null) {
        // EDIT MODE: Update existing pump
        final pumpIndex = pumps.indexWhere((pump) => pump['id'] == _editingPumpId);
        
        if (pumpIndex != -1) {
          // Update the existing pump
          pumps[pumpIndex] = {
            ...pumps[pumpIndex], // Keep existing fields
            'pumpNumber': pumpNumber,
            'pumpName': pumpName.isNotEmpty ? pumpName : 'Pump $pumpNumber',
            'fuelType': _selectedFuelType,
            'pricePerLiter': price,
            'maxOrderLimit': maxOrder,
            'updatedAt': timestamp.toIso8601String(),
            'stationId': _stationAutoId, // Include station autoID
            'autoID': _stationAutoId, // Also include autoID field
          };
          
          // Update station_pumps document using autoID
          await FirebaseFirestore.instance
              .collection('station_pumps')
              .doc(_stationAutoId!) // Update using autoID
              .update({
                'pumps': pumps,
                'updatedAt': FieldValue.serverTimestamp(),
              });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pump updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        // ADD MODE: Add new pump with autoID
        // Create new pump object
        final newPump = {
          'id': pumpId, // Using generated autoID
          'pumpNumber': pumpNumber,
          'pumpName': pumpName.isNotEmpty ? pumpName : 'Pump $pumpNumber',
          'fuelType': _selectedFuelType,
          'pricePerLiter': price,
          'maxOrderLimit': maxOrder,
          'currentFuelLevel': 100.0, // Start with full tank
          'status': 'available',
          'isActive': true,
          'currentQueue': 0,
          'servedToday': 0,
          'totalEarnings': 0.0,
          'createdAt': timestamp.toIso8601String(),
          'updatedAt': timestamp.toIso8601String(),
          'stationId': _stationAutoId, // Link to station autoID
          'autoID': _stationAutoId, // Also include autoID field
        };
        
        // Add the new pump to the array
        pumps.add(newPump);
        
        // Update station_pumps document using autoID
        await FirebaseFirestore.instance
            .collection('station_pumps')
            .doc(_stationAutoId!) // Update using autoID
            .update({
              'pumps': pumps,
              'updatedAt': FieldValue.serverTimestamp(),
              'totalPumps': FieldValue.increment(1),
              'activePumps': FieldValue.increment(1),
            });
        
        // Also update the station document using autoID
        await FirebaseFirestore.instance
            .collection('stations')
            .doc(_stationAutoId!) // Update using autoID
            .update({
              'updatedAt': FieldValue.serverTimestamp(),
              'pumpCount': FieldValue.increment(1),
            });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pump added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Clear form and reset state
      _resetForm();
      
    } catch (e) {
      debugPrint('Error saving pump: $e');
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updatePumpStatus(String pumpId, String newStatus) async {
    if (_stationAutoId == null) return;
    
    try {
      // Get current pumps array using station autoID
      final doc = await FirebaseFirestore.instance
          .collection('station_pumps')
          .doc(_stationAutoId!) // Fetch using autoID
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final pumps = List<Map<String, dynamic>>.from(data['pumps'] ?? []);
        String? oldStatus;
        
        // Find and update the pump
        for (int i = 0; i < pumps.length; i++) {
          if (pumps[i]['id'] == pumpId) {
            oldStatus = pumps[i]['status']?.toString();
            pumps[i]['status'] = newStatus;
            pumps[i]['updatedAt'] = DateTime.now().toIso8601String();
            
            // Update isActive based on status
            pumps[i]['isActive'] = (newStatus == 'available' || newStatus == 'in-use');
            break;
          }
        }
        
        // Update the document using station autoID
        await FirebaseFirestore.instance
            .collection('station_pumps')
            .doc(_stationAutoId!) // Update using autoID
            .update({
              'pumps': pumps,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        
        // Update pump counters based on status change
        if (oldStatus != null && oldStatus != newStatus) {
          await _updatePumpCounters(oldStatus, newStatus);
        }
      }
    } catch (e) {
      debugPrint('Error updating pump status: $e');
    }
  }

  Future<void> _updatePumpCounters(String oldStatus, String newStatus) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Decrement old status counter
      if (oldStatus == 'available') {
        updateData['activePumps'] = FieldValue.increment(-1);
      } else if (oldStatus == 'maintenance') {
        updateData['maintenancePumps'] = FieldValue.increment(-1);
      } else if (oldStatus == 'offline') {
        updateData['offlinePumps'] = FieldValue.increment(-1);
      }
      
      // Increment new status counter
      if (newStatus == 'available') {
        updateData['activePumps'] = FieldValue.increment(1);
      } else if (newStatus == 'maintenance') {
        updateData['maintenancePumps'] = FieldValue.increment(1);
      } else if (newStatus == 'offline') {
        updateData['offlinePumps'] = FieldValue.increment(1);
      }
      
      // Update station_pumps document using autoID
      await FirebaseFirestore.instance
          .collection('station_pumps')
          .doc(_stationAutoId!) // Update using autoID
          .update(updateData);
    } catch (e) {
      debugPrint('Error updating pump counters: $e');
    }
  }

  Future<void> _deletePump(String pumpId) async {
    if (_stationAutoId == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pump'),
        content: const Text('Are you sure you want to delete this pump?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Get current pumps array using station autoID
        final doc = await FirebaseFirestore.instance
            .collection('station_pumps')
            .doc(_stationAutoId!) // Fetch using autoID
            .get();
        
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final pumps = List<Map<String, dynamic>>.from(data['pumps'] ?? []);
          String? pumpStatus;
          
          // Find and remove the pump
          final pumpIndex = pumps.indexWhere((pump) => pump['id'] == pumpId);
          if (pumpIndex != -1) {
            pumpStatus = pumps[pumpIndex]['status']?.toString();
            pumps.removeAt(pumpIndex);
          }
          
          // Update station_pumps document using autoID
          await FirebaseFirestore.instance
              .collection('station_pumps')
              .doc(_stationAutoId!) // Update using autoID
              .update({
                'pumps': pumps,
                'totalPumps': FieldValue.increment(-1),
                'updatedAt': FieldValue.serverTimestamp(),
              });
          
          // Update pump counters based on status
          if (pumpStatus != null) {
            final counterUpdate = <String, dynamic>{
              'updatedAt': FieldValue.serverTimestamp(),
            };
            
            if (pumpStatus == 'available') {
              counterUpdate['activePumps'] = FieldValue.increment(-1);
            } else if (pumpStatus == 'maintenance') {
              counterUpdate['maintenancePumps'] = FieldValue.increment(-1);
            } else if (pumpStatus == 'offline') {
              counterUpdate['offlinePumps'] = FieldValue.increment(-1);
            }
            
            await FirebaseFirestore.instance
                .collection('station_pumps')
                .doc(_stationAutoId!)
                .update(counterUpdate);
          }
          
          // Update station document using autoID
          await FirebaseFirestore.instance
              .collection('stations')
              .doc(_stationAutoId!) // Update using autoID
              .update({
                'pumpCount': FieldValue.increment(-1),
                'updatedAt': FieldValue.serverTimestamp(),
              });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pump deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error deleting pump: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _editPump(Map<String, dynamic> pump) {
    _editingPumpId = pump['id']?.toString();
    _pumpNumberController.text = pump['pumpNumber']?.toString() ?? '';
    _pumpNameController.text = pump['pumpName']?.toString() ?? '';
    _selectedFuelType = pump['fuelType']?.toString();
    _priceController.text = pump['pricePerLiter']?.toString() ?? '';
    _maxOrderController.text = pump['maxOrderLimit']?.toString() ?? '';
    
    setState(() {
      _isAddingNew = true;
      _isEditing = true;
    });
    
    // Scroll to form when editing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _resetForm() {
    _pumpNumberController.clear();
    _pumpNameController.clear();
    _priceController.clear();
    _maxOrderController.clear();
    setState(() {
      _selectedFuelType = null;
      _isAddingNew = false;
      _isEditing = false;
      _editingPumpId = null;
    });
  }

  void _cancelEdit() {
    _resetForm();
  }

  Widget _buildPumpCard(Map<String, dynamic> pump) {
    final pumpNumber = pump['pumpNumber']?.toString() ?? 'N/A';
    final pumpName = pump['pumpName']?.toString() ?? 'Unnamed Pump';
    final fuelType = pump['fuelType']?.toString() ?? 'Unknown';
    final price = pump['pricePerLiter']?.toDouble() ?? 0.0;
    final maxOrder = pump['maxOrderLimit']?.toDouble() ?? 0.0;
    final fuelLevel = pump['currentFuelLevel']?.toDouble() ?? 0.0;
    final status = pump['status']?.toString() ?? 'available';
    final servedToday = pump['servedToday']?.toInt() ?? 0;
    final totalEarnings = pump['totalEarnings']?.toDouble() ?? 0.0;

    Color statusColor;
    switch (status) {
      case 'available':
        statusColor = Colors.green;
        break;
      case 'in-use':
        statusColor = Colors.orange;
        break;
      case 'maintenance':
        statusColor = Colors.red;
        break;
      case 'offline':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with pump info and actions
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
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_gas_station,
                            size: 20,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pumpName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Pump #$pumpNumber',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      itemBuilder: (BuildContext context) {
                        return <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'available',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 18),
                                SizedBox(width: 8),
                                Text('Mark as Available'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'in-use',
                            child: Row(
                              children: [
                                Icon(Icons.sync, color: Colors.orange, size: 18),
                                SizedBox(width: 8),
                                Text('Mark as In Use'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'maintenance',
                            child: Row(
                              children: [
                                Icon(Icons.build, color: Colors.red, size: 18),
                                SizedBox(width: 8),
                                Text('Mark as Maintenance'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'offline',
                            child: Row(
                              children: [
                                Icon(Icons.power_off, color: Colors.grey, size: 18),
                                SizedBox(width: 8),
                                Text('Mark as Offline'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.blue[700], size: 18),
                                const SizedBox(width: 8),
                                const Text('Edit Pump'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete, color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                const Text('Delete Pump', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ];
                      },
                      onSelected: (String value) {
                        if (value == 'edit') {
                          _editPump(pump);
                        } else if (value == 'delete') {
                          _deletePump(pump['id']);
                        } else {
                          _updatePumpStatus(pump['id'], value);
                        }
                      },
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
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

            // Max Order Limit and Fuel Level
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
                          '${maxOrder.toStringAsFixed(1)}L',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Max Order',
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
                        Row(
                          children: [
                            Text(
                              '${fuelLevel.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: fuelLevel > 20 ? Colors.green : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: fuelLevel / 100,
                                backgroundColor: Colors.grey[200],
                                color: fuelLevel > 20 ? Colors.green : Colors.red,
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

            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          servedToday.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Served Today',
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
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${totalEarnings.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Total Earnings',
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
          ],
        ),
      ),
    );
  }

  Widget _buildPumpForm() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Edit Pump' : 'Add New Pump',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _cancelEdit,
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Text(
                _isEditing 
                  ? 'Update the pump details below.'
                  : 'Fill in the pump details below. All fields are required.',
                style: const TextStyle(color: Colors.grey),
              ),
              
              const SizedBox(height: 20),

              // Pump Number
              TextField(
                controller: _pumpNumberController,
                decoration: const InputDecoration(
                  labelText: 'Pump Number *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 01, 02, A1, B2',
                  prefixIcon: Icon(Icons.numbers),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.text,
              ),
              
              const SizedBox(height: 16),

              // Pump Name (Optional)
              TextField(
                controller: _pumpNameController,
                decoration: const InputDecoration(
                  labelText: 'Pump Name (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Main Pump, Fast Lane, Diesel Only',
                  prefixIcon: Icon(Icons.local_gas_station),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              
              const SizedBox(height: 16),

              // Fuel Type Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFuelType,
                    hint: const Text('Select Fuel Type *'),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    items: [
                      // First show available fuel types from station
                      if (_availableFuelTypes.isNotEmpty) ...[
                        const DropdownMenuItem<String>(
                          value: '',
                          enabled: false,
                          child: Text(
                            '-- Available in Station --',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                        ..._availableFuelTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }),
                        const DropdownMenuItem<String>(
                          value: 'divider',
                          enabled: false,
                          child: Divider(),
                        ),
                      ],
                      // Then show common fuel types
                      const DropdownMenuItem<String>(
                        value: '',
                        enabled: false,
                        child: Text(
                          '-- Other Fuel Types --',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                      ..._commonFuelTypes.where((type) => !_availableFuelTypes.contains(type)).map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }),
                    ],
                    onChanged: (String? value) {
                      if (value != null && value.isNotEmpty && value != 'divider') {
                        setState(() => _selectedFuelType = value);
                      }
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 16),

              // Price per liter
              TextField(
                controller: _priceController,
                focusNode: _priceFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Price per Liter (₹) *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 98.50',
                  prefixIcon: Icon(Icons.attach_money),
                  suffixText: '₹/L',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              
              const SizedBox(height: 16),

              // Maximum order limit
              TextField(
                controller: _maxOrderController,
                focusNode: _maxOrderFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Maximum Order Limit (Liters) *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 50.0',
                  prefixIcon: Icon(Icons.format_list_numbered),
                  suffixText: 'L',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              
              const SizedBox(height: 24),

              // Save/Update Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePump,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditing ? Colors.orange[700] : Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isEditing ? Icons.save : Icons.add, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _isEditing ? 'Update Pump' : 'Add Pump',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                '* Required fields',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              
              // Add extra padding at bottom for keyboard
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Pumps'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!_isAddingNew)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() => _isAddingNew = true);
                // Scroll to top when opening form
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              },
              tooltip: 'Add New Pump',
            ),
        ],
      ),
      body: _isLoading && !_isAddingNew
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
          : _stationAutoId == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Station Auto ID not found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please complete station setup first',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Station Auto ID Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Station Auto ID',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  _stationAutoId!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.content_copy, size: 18),
                            onPressed: () {
                              // Copy to clipboard functionality
                              // You need to add clipboard package for this
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied to clipboard')),
                              );
                            },
                            tooltip: 'Copy Station Auto ID',
                          ),
                        ],
                      ),
                    ),

                    // Add/Edit Pump Form or Pumps List
                    Expanded(
                      child: _isAddingNew 
                          ? _buildPumpForm()
                          : StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('station_pumps')
                                  .doc(_stationAutoId!) // Stream using autoID
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return Center(child: Text('Error: ${snapshot.error}'));
                                }

                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                if (!snapshot.hasData || !snapshot.data!.exists) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.local_gas_station,
                                          size: 80,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'No Pumps Yet',
                                          style: TextStyle(
                                            fontSize: 20,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Add your first pump to start serving customers',
                                          style: TextStyle(color: Colors.grey),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.add, size: 20),
                                          label: const Text('Add First Pump'),
                                          onPressed: () {
                                            setState(() => _isAddingNew = true);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final data = snapshot.data!.data() as Map<String, dynamic>;
                                final pumps = List<Map<String, dynamic>>.from(data['pumps'] ?? []);
                                
                                if (pumps.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.local_gas_station,
                                          size: 80,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'No Pumps Yet',
                                          style: TextStyle(
                                            fontSize: 20,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Add your first pump to start serving customers',
                                          style: TextStyle(color: Colors.grey),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.add, size: 20),
                                          label: const Text('Add First Pump'),
                                          onPressed: () {
                                            setState(() => _isAddingNew = true);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: pumps.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: _buildPumpCard(pumps[index]),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}