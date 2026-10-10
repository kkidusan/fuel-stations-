import 'package:flutter/material.dart';

import '../../constants/app_enums.dart';
import '../../services/api_client.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';

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

  // Pump list loaded from the station_pumps document (replaces the
  // old realtime stream — reloaded after every mutation).
  List<Map<String, dynamic>> _pumps = [];
  
  // Common fuel types for dropdown (canonical values — see app_enums.dart)
  final List<String> _commonFuelTypes = kFuelTypes;

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
      final user = AuthService.currentUser;
      if (user == null) return;

      // User profile row (snake_case) holds the FS_WLD code + fuel types.
      final row = user.row;
      final autoId = row['auto_id']?.toString();
      final stationId = row['station_id']?.toString();

      setState(() {
        _stationAutoId =
            (autoId != null && autoId.isNotEmpty) ? autoId : stationId;
        _availableFuelTypes = List<String>.from(row['fuel_types'] ?? []);
      });

      // If autoID doesn't exist, create it via the backend bootstrap.
      if (_stationAutoId == null || _stationAutoId!.isEmpty) {
        await _createStationAutoId();
      } else {
        // Ensure station_pumps document exists, then load its pumps.
        await _ensureStationPumpsDocument();
        await _loadPumps();
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

  Future<void> _createStationAutoId() async {
    try {
      // POST /api/stations/bootstrap generates FS_WLD_XXXX, stores it on the
      // user row and creates the station docs.
      final key = await AppApi.bootstrapStation();

      // Refresh the cached user so auto_id / station_id are visible app-wide.
      final res = await AppApi.myProfile();
      final updatedUser = Map<String, dynamic>.from(res['user'] as Map? ?? {});
      AuthService.updateCachedUser(updatedUser);

      if (mounted) {
        setState(() {
          _stationAutoId = key;
          _availableFuelTypes =
              List<String>.from(updatedUser['fuel_types'] ?? []);
        });
      }

      await _loadPumps();
      debugPrint('Created new station with autoID: $key');
    } on ApiException catch (e) {
      debugPrint('Error creating station autoID: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating station: ${e.message}')),
        );
      }
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
      // GET /api/stations/pumps → null when the document doesn't exist yet.
      final doc = await AppApi.pumpsDoc(_stationAutoId!);
      if (doc == null) {
        await AppApi.savePumpsDoc({
          'station_key': _stationAutoId,
          'station_id': _stationAutoId,
          'pumps': <dynamic>[],
          'totalPumps': 0,
          'activePumps': 0,
          'maintenancePumps': 0,
          'offlinePumps': 0,
        });
      }
    } catch (e) {
      debugPrint('Error ensuring station pumps document: $e');
    }
  }

  /// One-shot load of the pumps array (replaces the old realtime stream).
  Future<void> _loadPumps() async {
    if (_stationAutoId == null) return;
    try {
      final doc = await AppApi.pumpsDoc(_stationAutoId!);
      if (mounted) {
        setState(() {
          _pumps = doc == null
              ? <Map<String, dynamic>>[]
              : List<Map<String, dynamic>>.from(
                  (doc['pumps'] as List?) ?? const []);
        });
      }
    } catch (e) {
      debugPrint('Error loading pumps: $e');
    }
  }

  /// Writes the full pumps array + counters (put = merge upsert), keeps the
  /// station summary doc's pump count in sync, then reloads.
  Future<void> _persistPumps(List<Map<String, dynamic>> pumps) async {
    if (_stationAutoId == null) return;

    await AppApi.savePumpsDoc({
      'station_key': _stationAutoId,
      'station_id': _stationAutoId,
      'pumps': pumps,
      'totalPumps': pumps.length,
      'activePumps': pumps.where((p) => p['status'] == 'available').length,
      'maintenancePumps': pumps.where((p) => p['status'] == 'maintenance').length,
      'offlinePumps': pumps.where((p) => p['status'] == 'offline').length,
    });

    await AppApi.saveStationDoc({'id': _stationAutoId, 'pumpCount': pumps.length});
    await _loadPumps();
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
      final pumpId = 'PUMP_${DateTime.now().millisecondsSinceEpoch}';

      // Read-modify-write: _pumps holds the latest document state.
      final pumps = List<Map<String, dynamic>>.from(_pumps);

      if (_isEditing && _editingPumpId != null) {
        // EDIT MODE: Update existing pump
        final pumpIndex =
            pumps.indexWhere((pump) => pump['id'] == _editingPumpId);

        if (pumpIndex != -1) {
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

          await _persistPumps(pumps);

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
        // ADD MODE: Add new pump
        final newPump = {
          'id': pumpId,
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

        pumps.add(newPump);
        await _persistPumps(pumps);

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
      // Read-modify-write on the in-memory pumps list. Counters are recomputed
      // from the list inside _persistPumps (replaces the old increment
      // increment logic).
      final pumps = List<Map<String, dynamic>>.from(_pumps);
      for (final pump in pumps) {
        if (pump['id'] == pumpId) {
          pump['status'] = newStatus;
          pump['updatedAt'] = DateTime.now().toIso8601String();
          pump['isActive'] =
              (newStatus == 'available' || newStatus == 'in-use');
          break;
        }
      }

      await _persistPumps(pumps);
    } catch (e) {
      debugPrint('Error updating pump status: $e');
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
        // Read-modify-write: remove the pump and persist counters + summary.
        final pumps = List<Map<String, dynamic>>.from(_pumps);
        pumps.removeWhere((pump) => pump['id'] == pumpId);

        await _persistPumps(pumps);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pump deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
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
    _selectedFuelType = normalizeFuelType(pump['fuelType']?.toString()) ??
        pump['fuelType']?.toString();
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
    final fuelType = fuelTypeLabel(pump['fuelType']?.toString());
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
                            child: Text(fuelTypeLabel(type)),
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
                          child: Text(fuelTypeLabel(type)),
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
                          : _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _pumps.isEmpty
                                  ? Center(
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
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _pumps.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: _buildPumpCard(_pumps[index]),
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
    );
  }
}