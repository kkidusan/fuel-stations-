import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_enums.dart';
import '../../services/api_client.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';
import '../../widgets/phone_input.dart';
import 'driver_edit_profile_page.dart';
import 'union_application_screen.dart';
import 'report_problem_screen.dart';

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  String _email = '…';
  String _driverName = '…';
  String _phoneNumber = '…';
  String _licensePlate = '…';
  String _status = '…';
  String _brand = '—';
  String _model = '—';
  String _vehicleType = '—';
  String _year = '—';
  String _color = '—';
  String _fuelType = '—';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthService.currentUser;
      if (user == null) throw Exception('No user');

      final res = await AppApi.myProfile();
      final data = Map<String, dynamic>.from(res['user'] as Map? ?? {});

      if (mounted) {
        setState(() {
          _email       = (data['email']       as String?)?.trim() ?? user.email;
          _driverName  = (data['display_name'] as String?)?.trim() ?? 'Not found';
          _phoneNumber = ((data['phone'] ?? data['phone_number']) as String?)?.trim() ?? '—';
          _licensePlate= (data['license_plate'] as String?)?.trim() ?? '—';
          _status      = (data['status']      as String?)?.trim() ?? 'active';
          _brand       = (data['brand']       as String?)?.trim() ?? '—';
          _model       = (data['model']       as String?)?.trim() ?? '—';
          _vehicleType = vehicleTypeLabel(data['vehicle_type']?.toString());
          _year        = data['year']?.toString() ?? '—';
          _color       = (data['color']       as String?)?.trim() ?? '—';
          _fuelType    = fuelTypeLabel(data['fuel_type']?.toString());
          _isLoading   = false;
        });
      }
    } on ApiException catch (e) {
      debugPrint('Failed to load driver profile: ${e.message}');
      if (mounted) {
        setState(() {
          _driverName = 'Error';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load driver profile: $e');
      if (mounted) {
        setState(() {
          _driverName = 'Error';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]', ), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showEmergencyContacts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 4, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('Emergency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildEmg('Police', '911', Icons.local_police, Colors.blue),
            const SizedBox(height: 12),
            _buildEmg('Fire', '912', Icons.fire_truck, Colors.red),
            const SizedBox(height: 12),
            _buildEmg('Ambulance', '913', Icons.medical_services, Colors.green),
            const SizedBox(height: 12),
            _buildEmg('Road Assist', '0966 123456', Icons.car_repair, Colors.orange),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmg(String title, String num, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _launchPhoneCall(num),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
                Text(num, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Personal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              _buildCompactRow('Name', _driverName, Icons.person_outline),
              _buildCompactRow('Email', _email, Icons.email_outlined),
              _buildCompactRow('Phone', formatPhoneDisplay(_phoneNumber), Icons.phone, isPhone: true),
              _buildCompactRow('Plate', _licensePlate, Icons.confirmation_number_outlined),
              _buildCompactRow('Status', _status.toUpperCase(), Icons.info_outline),

              const SizedBox(height: 20),
              const Text('Vehicle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              _buildCompactRow('Brand/Model', '$_brand $_model', Icons.directions_car),
              _buildCompactRow('Type', _vehicleType, Icons.category_outlined),
              _buildCompactRow('Year/Color', '$_year • $_color', Icons.palette_outlined),
              _buildCompactRow('Fuel', _fuelType, Icons.local_gas_station_outlined),

              const SizedBox(height: 24),
              const Text('Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMiniIcon(Icons.group_add, Colors.blue, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const UnionApplicationScreen()))
                        .then((_) => _loadUserData());
                  }),
                  _buildMiniIcon(Icons.report, Colors.orange, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportProblemScreen()));
                  }),
                  _buildMiniIcon(Icons.emergency, Colors.red, _showEmergencyContacts),
                  _buildMiniIcon(Icons.edit, Colors.green, () async {
                    final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverEditProfilePage()));
                    if (updated == true) _loadUserData();
                  }),
                ],
              ),

              const Spacer(),

              Center(
                child: Text(
                  'v1.0 • $_status',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Profile'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildCompactRow(String label, String value, IconData icon, {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey[700]),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (isPhone && value != '—' && value != 'Not set')
            IconButton(
              icon: const Icon(Icons.call, size: 18, color: Colors.green),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _launchPhoneCall(value),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 32, color: color),
      ),
    );
  }
}