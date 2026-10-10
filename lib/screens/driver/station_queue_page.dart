import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_enums.dart';
import '../../services/api_client.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';
import 'pre_order_fuel_page.dart';

class StationQueuePage extends StatefulWidget {
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

  @override
  State<StationQueuePage> createState() => _StationQueuePageState();
}

class _StationQueuePageState extends State<StationQueuePage> {
  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {});
  }

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<List<Map<String, dynamic>>> _fetchTodayQueue() async {
    final todayStart = _todayStart();
    final todayEnd = todayStart.add(const Duration(days: 1));

    try {
      final rows = await AppApi.preorders(
        stationId: widget.stationId,
        statuses: const ['waiting', 'preparing', 'ready'],
        from: todayStart.toUtc().toIso8601String(),
        to: todayEnd.toUtc().toIso8601String(),
        order: 'asc',
      );
      return rows;
    } catch (e) {
      debugPrint('Queue fetch error: $e');
      return [];
    }
  }

  Future<bool> _hasPreorderForThisPlateToday(String? plate) async {
    if (plate == null || plate.trim().isEmpty) {
      return false;
    }

    final todayStart = _todayStart();
    final todayEnd = todayStart.add(const Duration(days: 1));

    // Normalize plate consistently (match your other normalization logic)
    final cleanPlate = plate.trim().toUpperCase()
        .replaceAll(RegExp(r'[\s\-_·|•]'), '');

    try {
      final count = await AppApi.driverDayOrderCount(
        driverPlate: cleanPlate,
        from: todayStart.toUtc().toIso8601String(),
        to: todayEnd.toUtc().toIso8601String(),
      );
      return count > 0;
    } on ApiException catch (e, stack) {
      debugPrint('Duplicate check failed (preorders + history): $e\n$stack');
      // Fail open → better to allow than to block everyone on DB error
      return false;
    } catch (e, stack) {
      debugPrint('Duplicate check failed (preorders + history): $e\n$stack');
      // Fail open → better to allow than to block everyone on DB error
      return false;
    }
  }

  Future<String?> _getCurrentUserPlate(String uid) async {
    return AuthService.currentUser?.plate?.trim();
  }

  String _estimateWaitTime(int position) {
    final minutes = position * 4; // rough estimate — adjust as needed
    if (minutes < 10) return '<10 min';
    if (minutes < 30) return '~${minutes} min';
    if (minutes < 60) return '~1 h';
    return '${(minutes / 60).floor()} h+';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.stationName)),
        body: const Center(child: Text('Please sign in to view the queue')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stationName),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle(
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withOpacity(0.85),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text('Diesel: ${widget.dieselPrice} ETB/L',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text('Benzene: ${widget.benzenePrice} ETB/L',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(DateFormat('EEE, MMM d').format(DateTime.now())),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchTodayQueue(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error loading queue\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  final queue = snapshot.data ?? [];

                  if (queue.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_empty,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('Queue is empty today',
                              style: TextStyle(fontSize: 18)),
                          const SizedBox(height: 6),
                          const Text('Be the first to pre-order!',
                              style: TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    itemCount: queue.length,
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      final isCurrentUser = (item['driver_uid'] as String?) == user.uid;

                      final pos = index + 1;
                      final plate = (item['driver_plate'] as String?)?.trim() ?? '—';
                      final name = (item['driver_name'] as String?)?.trim() ?? '—';
                      final display = plate != '—' ? plate : name;
                      final fuel = fuelTypeLabel(item['fuel_type']?.toString());

                      final litersRaw = item['liters'];
                      final liters = (litersRaw is num
                              ? litersRaw.toDouble()
                              : double.tryParse(litersRaw?.toString() ?? '0')) ??
                          0.0;

                      final status = (item['status'] as String? ?? 'waiting').toUpperCase();

                      Color statusColor = Colors.grey.shade700;
                      if (status == 'READY') statusColor = Colors.green.shade700;
                      if (status == 'PREPARING') statusColor = Colors.orange.shade800;

                      return Card(
                        color: isCurrentUser ? Colors.green.shade50 : null,
                        elevation: isCurrentUser ? 3 : 1,
                        margin: const EdgeInsets.symmetric(vertical: 3.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
                          minLeadingWidth: 32,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: isCurrentUser ? Colors.green.shade700 : Colors.blueGrey.shade600,
                            child: Text(
                              '$pos',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            display,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w600,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '$fuel • ${liters.toStringAsFixed(1)} L',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: statusColor, width: 1),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: SizedBox(
                            width: 68,
                            height: 38,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (isCurrentUser)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 2),
                                    child: Icon(Icons.check_circle,
                                        color: Colors.green, size: 18),
                                  ),
                                Text(
                                  _estimateWaitTime(pos),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isCurrentUser
                                        ? Colors.green.shade800
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                    height: 1.0,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // ────────────────────────────────────────────────
          //           BOTTOM ACTION AREA
          // ────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: FutureBuilder<String?>(
                future: _getCurrentUserPlate(user.uid),
                builder: (context, plateSnap) {
                  if (plateSnap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 52,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                    );
                  }

                  final plate = plateSnap.data?.trim();

                  if (plate == null || plate.isEmpty) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.red, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No vehicle plate found in your profile.\nPlease update your profile first.',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Pre-order Fuel', style: TextStyle(fontSize: 15)),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Colors.grey.shade400,
                          ),
                          onPressed: null,
                        ),
                      ],
                    );
                  }

                  return FutureBuilder<bool>(
                    future: _hasPreorderForThisPlateToday(plate),
                    builder: (context, hasOrderSnap) {
                      if (hasOrderSnap.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 52,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                        );
                      }

                      final alreadyHasOrder = hasOrderSnap.data ?? false;

                      if (alreadyHasOrder) {
                        return OutlinedButton.icon(
                          icon: const Icon(Icons.info_outline, size: 20),
                          label: Text(
                            'Already ordered today (plate: $plate)',
                            style: const TextStyle(fontSize: 15),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: Colors.orange, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Only one pre-order per vehicle per day is allowed.\nPlate: $plate',
                                ),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                        );
                      }

                      return FilledButton.icon(
                        icon: const Icon(Icons.local_gas_station, size: 20),
                        label: const Text('Pre-order Fuel', style: TextStyle(fontSize: 15)),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final success = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PreOrderFuelPage(
                                stationId: widget.stationId,
                                stationName: widget.stationName,
                                dieselPrice: widget.dieselPrice,
                                benzenePrice: widget.benzenePrice,
                                onOrderSuccess: _refresh,
                              ),
                            ),
                          );

                          if (success == true && mounted) {
                            await _refresh();
                          }
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
}