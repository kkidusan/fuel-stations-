import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'pre_order_fuel_page.dart';

class StationQueuePage extends StatelessWidget {
  final String stationId;
  final String stationName;
  final String dieselPrice;
  final String benzenePrice;

  const StationQueuePage({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.dieselPrice,
    required this.benzenePrice,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> _getTodayQueueStream() {
    final todayStart = _todayStart();
    final todayEnd = todayStart.add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('preorders')
        .where('stationId', isEqualTo: stationId)
        .where('status', whereIn: const ['waiting', 'preparing', 'ready'])
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('createdAt', isLessThan: Timestamp.fromDate(todayEnd))
        .orderBy('createdAt')
        .snapshots()
        .handleError((error) {
      if (error.toString().contains('index is currently building')) {
        throw Exception('Index is still building. Please wait a few minutes.');
      }
      throw error;
    });
  }

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Stream<bool> _hasPreorderForThisPlateTodayStream(String? driverPlate) {
    if (driverPlate == null || driverPlate.trim().isEmpty) {
      return Stream.value(false);
    }

    final todayStart = _todayStart();
    final todayEnd = todayStart.add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('preorders')
        .where('driverPlate', isEqualTo: driverPlate.trim())
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('createdAt', isLessThan: Timestamp.fromDate(todayEnd))
        .limit(1)
        .snapshots()
        .map((snap) => snap.size > 0);
  }

  Stream<String?> _getCurrentUserPlateStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;

      return data['plateNumber'] as String? ??
          data['driverPlate'] as String? ??
          data['plate'] as String? ??
          data['vehiclePlate'] as String?;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(stationName)),
        body: const Center(child: Text('Please sign in to view this station')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(stationName),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Compact & modern header ────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.green.shade200, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stationName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Diesel: $dieselPrice ETB/L  •  Benzene: $benzenePrice ETB/L',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Today’s Queue – ${DateFormat('EEE, MMM d').format(DateTime.now())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // ── Compact queue list ─────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _getTodayQueueStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final errorMsg = snapshot.error.toString();
                  if (errorMsg.contains('index is currently building') ||
                      errorMsg.contains('FAILED_PRECONDITION')) {
                    return _buildIndexBuildingView();
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 72),
                          const SizedBox(height: 24),
                          const Text('Failed to load queue', style: TextStyle(fontSize: 20)),
                          const SizedBox(height: 16),
                          Text(
                            errorMsg.length > 220 ? '${errorMsg.substring(0, 220)}...' : errorMsg,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.queue, size: 72, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No pre-orders today', style: TextStyle(fontSize: 20, color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('Be the first to join the queue!'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final driverUid = data['driverUid'] as String?;
                    final isCurrentUser = driverUid == user.uid;
                    final position = index + 1;
                    final plateOrName = data['driverPlate'] as String? ?? data['driverName'] as String? ?? '—';
                    final fuel = data['fuelType'] as String? ?? '—';
                    final liters = (data['liters'] ?? '?').toString();
                    final status = (data['status'] as String? ?? 'unknown').toUpperCase();

                    Color statusColor = Colors.grey;
                    if (status == 'READY') statusColor = Colors.green;
                    if (status == 'PREPARING') statusColor = Colors.orange;

                    return Card(
                      color: isCurrentUser ? Colors.green.shade50 : null,
                      elevation: isCurrentUser ? 3 : 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        minLeadingWidth: 36,
                        minVerticalPadding: 8,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: isCurrentUser ? Colors.green : Colors.grey.shade600,
                          radius: 16,
                          child: Text(
                            '$position',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        title: Text(
                          plateOrName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$fuel • $liters L',
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: statusColor, width: 1),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: isCurrentUser
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── Bottom action button section ───────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: StreamBuilder<String?>(
                stream: _getCurrentUserPlateStream(user.uid),
                builder: (context, plateSnapshot) {
                  if (plateSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final driverPlate = plateSnapshot.data?.trim();

                  // No plate in profile
                  if (driverPlate == null || driverPlate.isEmpty) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No vehicle plate number found in your profile.\nPlease update your profile first.',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Join Queue / Pre-order Fuel'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            backgroundColor: Colors.grey.shade400,
                          ),
                          onPressed: null,
                        ),
                      ],
                    );
                  }

                  // Has plate → check if already ordered today
                  return StreamBuilder<bool>(
                    stream: _hasPreorderForThisPlateTodayStream(driverPlate),
                    builder: (context, hasOrderSnapshot) {
                      if (hasOrderSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: SizedBox(
                            height: 56,
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final hasOrder = hasOrderSnapshot.data ?? false;

                      return FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(
                          hasOrder ? 'Already Ordered Today' : 'Join Queue / Pre-order Fuel',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: hasOrder ? Colors.grey.shade400 : null,
                          foregroundColor: hasOrder ? Colors.grey.shade800 : null,
                        ),
                        onPressed: hasOrder
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PreOrderFuelPage(
                                      stationId: stationId,
                                      stationName: stationName,
                                    ),
                                  ),
                                );
                              },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexBuildingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build_circle_outlined, size: 72, color: Colors.orange),
            const SizedBox(height: 24),
            const Text('Queue System Initializing', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Database index is being created.\nUsually takes 2–5 minutes.', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}