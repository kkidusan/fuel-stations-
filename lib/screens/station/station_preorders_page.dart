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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserAndStation();
  }

  Future<void> _loadUserAndStation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _currentUserEmail = null);
      return;
    }

    _currentUserEmail = user.email;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final autoId = snap.docs.first['autoID'] as String?;
        setState(() {
          _stationAutoId = (autoId?.trim().isNotEmpty == true) ? autoId : null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching station ID: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUserEmail == null) {
      return _centeredMessage('Please sign in to view pre-orders');
    }

    if (_stationAutoId == null) {
      return _centeredMessage('Station ID not found\nCannot show pre-orders');
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('preorders')
            .where('stationId', isEqualTo: _stationAutoId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _centeredMessage(
              'Error loading pre-orders\n${snapshot.error}',
              color: Colors.redAccent,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.hourglass_empty_rounded, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No pre-orders yet',
                    style: TextStyle(fontSize: 17, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => await Future.delayed(const Duration(milliseconds: 800)),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;

                final orderId = doc.id;
                final driver = (data['driverName'] as String?)?.trim() ?? '—';
                final plate = (data['driverPlate'] as String?)?.toUpperCase() ?? '—';
                final fuel = data['fuelType']?.toString() ?? '—';
                final liters = (data['liters'] as num?)?.toInt() ?? 0;
                final status = (data['status'] as String?)?.toLowerCase() ?? 'waiting';

                final statusInfo = _getStatusInfo(status);

                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  elevation: 0.8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_shipping_outlined,
                            size: 26,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 10),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  driver,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '$fuel  •  $liters L',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                Text(
                                  plate,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusInfo.color.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusInfo.label,
                              style: TextStyle(
                                color: statusInfo.color,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
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

  Widget _centeredMessage(String message, {Color color = Colors.grey}) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: color),
          ),
        ),
      ),
    );
  }

  ({String label, Color color}) _getStatusInfo(String status) {
    switch (status) {
      case 'waiting':
      case 'pending':
        return (label: 'WAITING', color: Colors.orange);
      case 'confirmed':
        return (label: 'CONFIRMED', color: Colors.teal);
      case 'completed':
        return (label: 'DONE', color: Colors.green.shade700);
      case 'cancelled':
      case 'rejected':
        return (label: 'CANCELLED', color: Colors.red.shade700);
      default:
        return (label: 'UNKNOWN', color: Colors.blueGrey);
    }
  }
}