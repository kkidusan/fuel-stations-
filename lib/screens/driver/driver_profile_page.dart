import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_user_service.dart';
import 'driver_edit_profile_page.dart';
import 'union_application_screen.dart';
import 'report_problem_screen.dart';

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
  String _unionStatus = 'Not Applied';
  int _totalTrips = 0;
  double _rating = 0.0;
  bool _isLoading = true;
  bool _isUnionMember = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        if (mounted) {
          setState(() {
            _email = user.email ?? 'Not set';
            _role = data['role']?.toString() ?? 'driver';
            _driverName = data['driverName']?.toString() ?? 'Not set';
            _phoneNumber = data['phoneNumber']?.toString() ?? 'Not set';
            _plateNumber = data['plateNumber']?.toString() ?? 'Not set';
            _unionStatus = data['unionStatus']?.toString() ?? 'Not Applied';
            _totalTrips = (data['totalTrips'] as int?) ?? 0;
            _rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
            _isUnionMember = data['isUnionMember'] as bool? ?? false;
            _isLoading = false;
          });
        }
      }

      await _loadUnionStatus();
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUnionStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final unionQuery = await FirebaseFirestore.instance
          .collection('union_applications')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (unionQuery.docs.isNotEmpty) {
        final appData = unionQuery.docs.first.data();
        if (mounted) {
          setState(() {
            _unionStatus = appData['status']?.toString() ?? 'Pending';
            _isUnionMember = appData['isUnionMember'] as bool? ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading union status: $e');
    }
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showEmergencyContacts() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Emergency Contacts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildEmergencyContactRow(
              'Police Emergency',
              '911',
              Icons.local_police,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildEmergencyContactRow(
              'Fire Department',
              '912',
              Icons.fire_truck,
              Colors.red,
            ),
            const SizedBox(height: 12),
            _buildEmergencyContactRow(
              'Ambulance',
              '913',
              Icons.medical_services,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildEmergencyContactRow(
              'Road Assistance',
              '0966 123456',
              Icons.car_repair,
              Colors.orange,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactRow(
      String title, String number, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _launchPhoneCall(number),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    number,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.phone_outlined, color: color),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadUserData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with profile icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade400,
                                      Colors.blue.shade600,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _driverName,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'ID: $_plateNumber',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.refresh,
                                      size: 22, color: Colors.blue),
                                ),
                                onPressed: _loadUserData,
                                tooltip: 'Refresh',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Driver Stats Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade50,
                                Colors.blue.shade100.withOpacity(0.5),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.blue.shade200.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn(
                                  Icons.directions_car_filled, 'Trips', '$_totalTrips'),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.blue.shade200.withOpacity(0.5),
                              ),
                              _buildStatColumn(Icons.star_rate_rounded, 'Rating',
                                  _rating.toStringAsFixed(1)),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.blue.shade200.withOpacity(0.5),
                              ),
                              _buildStatColumn(Icons.verified_rounded, 'Status',
                                  _unionStatus),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Personal Information Section
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isUnionMember
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isUnionMember
                                      ? Colors.green.shade200
                                      : Colors.orange.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _isUnionMember ? 'Union Member' : 'Not a Member',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _isUnionMember
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildInfoRow('Email', _email, Icons.email_outlined),
                        const SizedBox(height: 12),
                        _buildInfoRow('Phone', _phoneNumber, Icons.phone_iphone),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                            'License Plate', _plateNumber, Icons.confirmation_number_outlined),

                        const SizedBox(height: 28),

                        // Quick Actions Section - Fixed Grid
                        Row(
                          children: [
                            const Icon(Icons.bolt_outlined,
                                color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Quick Actions',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Using Wrap instead of GridView for better overflow handling
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.start,
                          children: [
                            _buildActionButton(
                              'Apply for Union',
                              Icons.group_add_outlined,
                              Colors.blue,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const UnionApplicationScreen(),
                                  ),
                                ).then((_) => _loadUserData());
                              },
                              context,
                            ),
                            _buildActionButton(
                              'Report Problem',
                              Icons.report_gmailerrorred_outlined,
                              Colors.orange,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ReportProblemScreen(),
                                  ),
                                );
                              },
                              context,
                            ),
                            _buildActionButton(
                              'Emergency Contacts',
                              Icons.emergency_outlined,
                              Colors.red,
                              _showEmergencyContacts,
                              context,
                            ),
                            _buildActionButton(
                              'Fuel History',
                              Icons.history_outlined,
                              Colors.green,
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Fuel history feature coming soon!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              context,
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Documents Section
                        Row(
                          children: [
                            const Icon(Icons.description_outlined,
                                color: Colors.purple, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Documents',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildDocumentRow(
                            'Driver License', Icons.badge_outlined, _isUnionMember),
                        const SizedBox(height: 10),
                        _buildDocumentRow('Vehicle Registration',
                            Icons.description_outlined, _isUnionMember),
                        const SizedBox(height: 10),
                        _buildDocumentRow('Insurance Certificate',
                            Icons.verified_user_outlined, _isUnionMember),

                        const SizedBox(height: 32),

                        // Edit Profile Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            label: const Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                              shadowColor: Colors.blue.withOpacity(0.3),
                            ),
                            onPressed: () async {
                              final bool? updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const DriverEditProfilePage(),
                                ),
                              );
                              if (updated == true) {
                                _loadUserData();
                              }
                            },
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Version info at bottom
                        const Center(
                          child: Text(
                            'Driver App v1.0.0',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.blue.shade600, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Colors.blue.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (label == 'Phone' && value != 'Not set')
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_outlined,
                    size: 18, color: Colors.green),
              ),
              onPressed: () => _launchPhoneCall(value),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String text, IconData icon, Color color, VoidCallback onTap, BuildContext context) {
    // Calculate button width based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = (screenWidth - 56) / 2; // 56 = padding(40) + spacing(16)
    
    return SizedBox(
      width: buttonWidth,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.08), color.withOpacity(0.04)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentRow(String document, IconData icon, bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isVerified
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 20,
                color: isVerified ? Colors.green : Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              document,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isVerified
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isVerified
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isVerified ? Icons.check_circle : Icons.pending,
                  size: 14,
                  color: isVerified ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  isVerified ? 'Verified' : 'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isVerified ? Colors.green : Colors.orange,
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