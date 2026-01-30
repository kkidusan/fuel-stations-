// ================================================
// station_preorders_page.dart
// ================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'station_preorder_detail_page.dart'; // Make sure this file exists

class StationPreordersPage extends StatefulWidget {
  const StationPreordersPage({super.key});

  @override
  State<StationPreordersPage> createState() => _StationPreordersPageState();
}

class _StationPreordersPageState extends State<StationPreordersPage> {
  String? _currentUserEmail;
  String? _stationAutoId;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserAndStationId();
  }

  Future<void> _loadUserAndStationId() async {
    final authUser = FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      setState(() {
        _currentUserEmail = 'Not signed in';
        _stationAutoId = null;
        _isLoadingUser = false;
      });
      return;
    }

    setState(() {
      _currentUserEmail = authUser.email ?? 'No email';
      _isLoadingUser = true;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: authUser.email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final userData = query.docs.first.data();
        final autoId = userData['autoID'] as String?;

        setState(() {
          _stationAutoId = autoId?.trim().isNotEmpty == true ? autoId : null;
          _isLoadingUser = false;
        });
      } else {
        setState(() {
          _stationAutoId = null;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading station ID: $e');
      setState(() {
        _stationAutoId = null;
        _isLoadingUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUserEmail == 'Not signed in') {
      return Scaffold(
        body: Center(
          child: Text(
            'Please sign in to view pre-orders',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
        ),
      );
    }

    if (_stationAutoId == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Station ID not found\nCannot load pre-orders',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-orders'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('preorders')
            .where('stationId', isEqualTo: _stationAutoId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading orders:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty_rounded, size: 90, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  Text(
                    'No pre-orders yet',
                    style: TextStyle(fontSize: 22, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => await Future.delayed(const Duration(milliseconds: 1200)),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;

                final orderId = doc.id;
                final shortId = '#${orderId.substring(0, 8)}';

                final driverName = data['driverName']?.toString() ?? '—';
                final plate = (data['driverPlate'] as String?)?.toUpperCase() ?? '—';
                final fuel = data['fuelType']?.toString() ?? '—';
                final liters = (data['liters'] as num?)?.toInt() ?? 0;
                final status = (data['status'] as String?)?.toLowerCase() ?? 'waiting';

                final statusInfo = _getStatusInfo(status);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StationPreorderDetailPage(
                            orderId: orderId,
                            orderData: data,
                          ),
                        ),
                      );
                    },
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      leading: const Icon(Icons.local_shipping_rounded, size: 42, color: Colors.blueGrey),
                      title: Text(
                        '$shortId  •  $driverName',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$fuel  •  $liters L'),
                            const SizedBox(height: 4),
                            Text('Plate: $plate', style: TextStyle(fontSize: 13.5, color: Colors.grey[700])),
                          ],
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusInfo.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusInfo.label.toUpperCase(),
                          style: TextStyle(
                            color: statusInfo.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  ({String label, Color color}) _getStatusInfo(String status) {
    switch (status) {
      case 'waiting':
      case 'pending':
        return (label: 'Waiting', color: Colors.orange);
      case 'confirmed':
        return (label: 'Confirmed', color: Colors.teal);
      case 'completed':
        return (label: 'Completed', color: Colors.green.shade700);
      case 'cancelled':
      case 'rejected':
        return (label: 'Cancelled', color: Colors.red.shade700);
      default:
        return (label: 'Unknown', color: Colors.blueGrey);
    }
  }
}