import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_user_service.dart';
import 'driver_edit_profile_page.dart';

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  String _email = 'Loading...';
  String _role = 'Loading...';
  String _driverName = 'Loading...';
  String _phoneNumber = 'Loading...';
  String _plateNumber = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final email = await AuthService.getCurrentEmail();
      if (email == null || email.isEmpty) throw Exception('No email found');

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        if (mounted) {
          setState(() {
            _email = email;
            _role = data['role']?.toString() ?? 'unknown';
            _driverName = data['driverName']?.toString() ?? 'Not set';
            _phoneNumber = data['phoneNumber']?.toString() ?? 'Not set';
            _plateNumber = data['plateNumber']?.toString() ?? 'Not set';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _email = email;
            _role = 'Not registered';
            _driverName = 'Not set';
            _phoneNumber = 'Not set';
            _plateNumber = 'Not set';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _email = 'Error';
          _role = 'Error';
          _driverName = 'Error';
          _phoneNumber = 'Error';
          _plateNumber = 'Error';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                   
                    const SizedBox(height: 24),

                    _buildCompactRow('Email', _email),
                    const SizedBox(height: 12),
                    _buildCompactRow('Role', _role.toUpperCase()),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 20),

                    _buildCompactRow('Name', _driverName),
                    const SizedBox(height: 12),
                    _buildCompactRow('Phone', _phoneNumber),
                    const SizedBox(height: 12),
                    _buildCompactRow('Plate', _plateNumber),
                    const SizedBox(height: 12),
                    _buildCompactRow('Rating', '4.8 ★ (142 trips)'),

                    const Spacer(),

                    FilledButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Profile', style: TextStyle(fontSize: 14)),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final bool? updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DriverEditProfilePage(),
                          ),
                        );
                        if (updated == true) {
                          _loadUserData();
                        }
                      },
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCompactRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}