import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../constants/app_enums.dart';
import '../../services/api_client.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';
import '../../widgets/phone_input.dart';

class StationProfilePage extends StatefulWidget {
  const StationProfilePage({super.key});

  @override
  State<StationProfilePage> createState() => _StationProfilePageState();
}

class _StationProfilePageState extends State<StationProfilePage> {
  bool _isLoading = true;

  String _email = '—';
  String _displayName = '—';
  String _stationName = '—';
  String _address = '—';
  String _phone = '—';
  String _fuelTypes = '—';
  String _capacityLiters = '—';
  DateTime _updatedAt = DateTime(2000);

  String? _stationId;

  @override
  void initState() {
    super.initState();
    _loadStationData();
  }

  Future<void> _loadStationData() async {
    setState(() => _isLoading = true);

    try {
      final user = AuthService.currentUser;
      if (user == null) {
        setState(() {
          _email = 'Not signed in';
          _displayName = 'Guest';
          _isLoading = false;
        });
        return;
      }

      final row = user.row;
      final stationKey = (row['auto_id'] ?? row['station_id'])?.toString();

      // Profile row (snake_case) from the backend
      final profileRes = await AppApi.myProfile();
      final profile = Map<String, dynamic>.from(
        (profileRes['user'] as Map?) ?? row,
      );

      // Station summary doc (camelCase) — 404 → null → defaults
      Map<String, dynamic>? stationDoc;
      if (stationKey != null && stationKey.isNotEmpty) {
        stationDoc = await AppApi.stationDoc(stationKey);
      }

      final fuels = (profile['fuel_types'] as List?) ??
          (stationDoc?['fuelTypes'] as List?) ??
          const [];
      final cap = profile['station_capacity'];
      final capNum = cap is num ? cap : num.tryParse(cap?.toString() ?? '');

      final emailRaw = (profile['email'] as String?)?.trim() ?? '';
      final email =
          emailRaw.isNotEmpty ? emailRaw : (user.email.isEmpty ? '—' : user.email);

      setState(() {
        _stationId = stationKey;
        _email = email;
        _displayName = (profile['display_name'] as String?)?.trim() ?? 'Station Owner';
        _stationName = (profile['station_name'] as String?)?.trim() ??
            (stationDoc?['stationName'] as String?)?.trim() ??
            'Unnamed Station';
        _address = (profile['address'] as String?)?.trim() ?? 'No address set';
        _phone = (profile['phone'] as String?)?.trim() ?? 'Not set';

        _fuelTypes = fuels.isNotEmpty
            ? fuels.map((e) => fuelTypeLabel(e.toString())).join(', ')
            : 'Not specified';

        _capacityLiters = capNum != null
            ? '${NumberFormat("#,###").format(capNum)} L'
            : '—';

        _updatedAt = DateTime.tryParse(profile['updated_at']?.toString() ?? '') ??
            DateTime.tryParse(stationDoc?['updatedAt']?.toString() ?? '') ??
            DateTime.now();

        _isLoading = false;
      });
    } on ApiException catch (e) {
      debugPrint('Error loading station profile: $e');
      setState(() {
        _email = 'Error';
        _stationName = 'Failed to load';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: ${e.message}')),
        );
      }
    } catch (e, stack) {
      debugPrint('Error loading station profile: $e\n$stack');
      setState(() {
        _email = 'Error';
        _stationName = 'Failed to load';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  Future<void> _detectAndUpdateLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable them.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions permanently denied. Please enable in settings.'),
            ),
          );
        }
        return;
      }

      setState(() => _isLoading = true);

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final lat = position.latitude;
      final lng = position.longitude;

      final user = AuthService.currentUser;
      final uid = user?.uid ?? '';

      // Persist coordinates on the user profile row (snake_case)
      final profileRes = await AppApi.updateProfile({
        'latitude': lat,
        'longitude': lng,
      });
      final updatedRow = profileRes['user'];
      if (updatedRow is Map<String, dynamic>) {
        AuthService.updateCachedUser(updatedRow);
      }

      // Keep the public locations doc in sync (merge upsert)
      if (_stationId != null && _stationId!.isNotEmpty) {
        await AppApi.upsertLocation(
          _stationId!,
          uid: uid,
          name: _stationName,
          address: _address,
          phone: _phone != 'Not set' && _phone != '—' ? _phone : null,
          fuelTypes: _fuelTypes != 'Not specified' && _fuelTypes != '—'
              ? _fuelTypes.split(', ').map((e) => e.trim()).toList()
              : [],
          capacityLiters: int.tryParse(
            _capacityLiters.replaceAll(RegExp(r'[^\d]'), ''),
          ),
          latitude: lat,
          longitude: lng,
          isActive: true,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location updated successfully!\nLat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on ApiException catch (e) {
      debugPrint('Location error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update location: ${e.message}')),
        );
      }
    } catch (e, stack) {
      debugPrint('Location error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStationInfo({
    required String stationName,
    required String address,
    required String phone,
    required List<String> fuelTypes,
    required int? capacity,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authenticated')),
        );
      }
      return;
    }

    try {
      final stationKey =
          (user.row['auto_id'] ?? user.row['station_id'])?.toString();
      final phoneValue = phone.trim();

      // 1) Update the user profile row (snake_case)
      final profileRes = await AppApi.updateProfile({
        'station_name': stationName.trim(),
        'display_name': stationName.trim(),
        'address': address.trim(),
        'phone': phoneValue,
        'phone_number': phoneValue,
        'fuel_types': fuelTypes.isNotEmpty ? fuelTypes : null,
        'station_capacity': capacity,
      });
      final updatedRow = profileRes['user'];
      if (updatedRow is Map<String, dynamic>) {
        AuthService.updateCachedUser(updatedRow);
      }

      // 2) Update the station summary doc (camelCase) — keep aggregates
      if (stationKey != null && stationKey.isNotEmpty) {
        final existing = await AppApi.stationDoc(stationKey);
        final docBody = <String, dynamic>{'id': stationKey};
        if (existing != null) {
          for (final key in [
            'autoID',
            'stationId',
            'ownerId',
            'pumpCount',
            'totalEarnings',
            'totalCustomers',
            'status',
          ]) {
            if (existing[key] != null) docBody[key] = existing[key];
          }
        }
        docBody['stationName'] = stationName.trim();
        docBody['fuelTypes'] = fuelTypes;
        await AppApi.saveStationDoc(docBody);
      }

      // 3) Keep the public locations doc in sync (merge upsert)
      if (stationKey != null && stationKey.isNotEmpty) {
        await AppApi.upsertLocation(
          stationKey,
          uid: user.uid,
          name: stationName.trim(),
          address: address.trim(),
          phone: phoneValue,
          fuelTypes: fuelTypes,
          capacityLiters: capacity,
          isActive: true,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Station profile updated successfully')),
        );
      }

      await _loadStationData();
    } on ApiException catch (e) {
      debugPrint('Update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: ${e.message}')),
        );
      }
    } catch (e, stack) {
      debugPrint('Update error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      
      body: RefreshIndicator(
        onRefresh: _loadStationData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              if (_updatedAt.isAfter(DateTime(2001)))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Icon(Icons.update, size: 16, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Last updated: ${DateFormat('EEE, MMM d • HH:mm').format(_updatedAt)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

              Text(
                'Station Information',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),

              _CompactInfoRow(Icons.business_rounded, 'Name', _stationName),
              _CompactInfoRow(Icons.email_rounded, 'Email', _email),
              _CompactInfoRow(Icons.location_on_rounded, 'Address', _address),
              _CompactInfoRow(Icons.phone_rounded, 'Phone', formatPhoneDisplay(_phone)),
              _CompactInfoRow(Icons.local_gas_station_rounded, 'Fuels', _fuelTypes),
              _CompactInfoRow(Icons.inventory_2_rounded, 'Capacity', _capacityLiters),

              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.my_location_rounded),
                      label: const Text('Detect Location'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.secondaryContainer,
                        foregroundColor: colorScheme.onSecondaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _detectAndUpdateLocation,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: const Text('Edit Details'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditStationDetailsPage(
                              initialName: _stationName,
                              initialAddress: _address,
                              initialPhone: _phone == 'Not set' || _phone == '—' ? '' : _phone,
                              initialFuels: _fuelTypes == 'Not specified' || _fuelTypes == '—' ? '' : _fuelTypes,
                              initialCapacity: _capacityLiters == '—' ? '' : _capacityLiters.replaceAll(' L', '').replaceAll(',', ''),
                              onSave: _updateStationInfo,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _CompactInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
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

class EditStationDetailsPage extends StatefulWidget {
  final String initialName;
  final String initialAddress;
  final String initialPhone;
  final String initialFuels;
  final String initialCapacity;
  final Future<void> Function({
    required String stationName,
    required String address,
    required String phone,
    required List<String> fuelTypes,
    required int? capacity,
  }) onSave;

  const EditStationDetailsPage({
    super.key,
    required this.initialName,
    required this.initialAddress,
    required this.initialPhone,
    required this.initialFuels,
    required this.initialCapacity,
    required this.onSave,
  });

  @override
  State<EditStationDetailsPage> createState() => _EditStationDetailsPageState();
}

class _EditStationDetailsPageState extends State<EditStationDetailsPage> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late PhoneController _phone;
  late TextEditingController _fuelsController;
  late TextEditingController _capacityController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _addressController = TextEditingController(text: widget.initialAddress);
    _phone = PhoneController(initial: widget.initialPhone);
    _fuelsController = TextEditingController(text: widget.initialFuels);
    _capacityController = TextEditingController(text: widget.initialCapacity);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phone.dispose();
    _fuelsController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phone.fullPhone;
    final fuelsText = _fuelsController.text.trim();
    final capacityText = _capacityController.text.trim().replaceAll(',', '');

    if (name.isEmpty || address.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Station name, address and phone are required')),
      );
      return;
    }

    List<String> fuelList = [];
    if (fuelsText.isNotEmpty) {
      fuelList = normalizeFuelTypes(
        fuelsText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      );
    }

    int? capacity;
    if (capacityText.isNotEmpty) {
      try {
        capacity = int.parse(capacityText);
        if (capacity <= 0) capacity = null;
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Capacity must be a valid number')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      await widget.onSave(
        stationName: name,
        address: address,
        phone: phone,
        fuelTypes: fuelList,
        capacity: capacity,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Station Details')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Station Name *', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address *', border: OutlineInputBorder()),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              PhoneField(
                controller: _phone,
                label: 'Phone Number *',
                hint: '9xx xxx xxx',
                borderRadius: 4,
                fillColor: Colors.white,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _fuelsController,
                decoration: const InputDecoration(
                  labelText: 'Fuel Types (comma separated)',
                  hintText: 'e.g. Diesel, Benzene 95, Benzene 91',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _capacityController,
                decoration: const InputDecoration(
                  labelText: 'Total Capacity (liters)',
                  hintText: 'e.g. 150000',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isSaving ? null : _handleSave,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}