import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StationProfilePage extends StatefulWidget {
  const StationProfilePage({super.key});

  @override
  State<StationProfilePage> createState() => _StationProfilePageState();
}

class _StationProfilePageState extends State<StationProfilePage> {
  String _email = 'Loading...';
  String _displayName = 'Station Owner';
  String _stationName = 'Addis Fuel Station';
  String _address = 'Bole Road, Addis Ababa';
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startClock();
  }

  void _startClock() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _currentTime = DateTime.now());
      _startClock();
    });
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _email = 'Not signed in';
          _displayName = 'Guest';
          _stationName = 'N/A';
          _address = 'N/A';
        });
        return;
      }

      setState(() {
        _email = user.email ?? 'No email available';
        _displayName = user.displayName ?? 'Station Owner';
      });

      // Load custom station data from Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email!)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        setState(() {
          _stationName = data['name'] as String? ?? 'Addis Fuel Station';
          _address = data['address'] as String? ?? 'Bole Road, Addis Ababa';
        });
      }
    } catch (e) {
      setState(() {
        _email = 'Error loading data';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  Future<void> _updateStationInfo(String newName, String newAddress) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No authenticated user found')),
        );
      }
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email!)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No profile document found')),
          );
        }
        return;
      }

      final docRef = querySnapshot.docs.first.reference;

      await docRef.update({
        'name': newName.trim(),
        'address': newAddress.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Station details updated successfully')),
        );
      }

      // Refresh displayed data
      await _loadUserData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  String _formatEAT(DateTime dt) {
    // Note: .toLocal() assumes device is in EAT or close enough
    // For production → consider proper timezone handling (e.g. timezone package)
    return DateFormat('EEE, MMM d • HH:mm:ss').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Live time card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 20, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Current Time (EAT)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _formatEAT(_currentTime),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Station Information
              Text(
                'Station Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              _CompactInfoRow(Icons.business_rounded, 'Name', _stationName),
              _CompactInfoRow(Icons.email_rounded, 'Email', _email),
              _CompactInfoRow(Icons.location_on_rounded, 'Address', _address),
              _CompactInfoRow(Icons.phone_rounded, 'Phone', '+251 911 234 567'),
              _CompactInfoRow(Icons.local_gas_station_rounded, 'Fuels', '91 • 95 • Diesel'),
              _CompactInfoRow(Icons.inventory_2_rounded, 'Stock', '~5,240 L'),

              const SizedBox(height: 32),

              // Action buttons
              FilledButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('Edit Details'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditStationDetailsPage(
                        initialName: _stationName,
                        initialAddress: _address,
                        onSave: _updateStationInfo,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                },
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
          Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
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

// ────────────────────────────────────────────────
//               Edit Screen
// ────────────────────────────────────────────────
class EditStationDetailsPage extends StatefulWidget {
  final String initialName;
  final String initialAddress;
  final Future<void> Function(String name, String address) onSave;

  const EditStationDetailsPage({
    super.key,
    required this.initialName,
    required this.initialAddress,
    required this.onSave,
  });

  @override
  State<EditStationDetailsPage> createState() => _EditStationDetailsPageState();
}

class _EditStationDetailsPageState extends State<EditStationDetailsPage> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _addressController = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.onSave(name, address);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Station Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Station Name *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address *',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const Spacer(),
            FilledButton(
              onPressed: _isSaving ? null : _handleSave,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
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
    );
  }
}