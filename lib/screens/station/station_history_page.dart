import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';
import 'daily_history_detail_page.dart';

class StationHistoryPage extends StatefulWidget {
  const StationHistoryPage({super.key});

  @override
  State<StationHistoryPage> createState() => _StationHistoryPageState();
}

class _StationHistoryPageState extends State<StationHistoryPage> {
  String? _stationUid;
  bool _isLoading = true;
  String? _errorMessage;

  Map<DateTime, List<Map<String, dynamic>>> _groupedOrders = {};
  List<DateTime> _sortedDates = [];

  @override
  void initState() {
    super.initState();
    _loadStationAndHistory();
  }

  Future<void> _loadStationAndHistory() async {
    final user = AuthService.currentUser;
    if (user == null || user.email.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please sign in';
        _isLoading = false;
      });
      return;
    }

    _stationUid = user.uid;
    if (_stationUid == null || _stationUid!.isEmpty) {
      setState(() {
        _errorMessage = 'No station profile found';
        _isLoading = false;
      });
      return;
    }

    try {
      await _fetchRecentHistory();
    } catch (e) {
      debugPrint('Error loading station: $e');
      setState(() {
        _errorMessage = 'Failed to load station profile';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRecentHistory() async {
    if (_stationUid == null) return;

    setState(() => _isLoading = true);

    try {
      final startDate = DateTime.now().subtract(const Duration(days: 9));
      final fromDate = DateTime(startDate.year, startDate.month, startDate.day);

      final results = await AppApi.history(
        stationId: _stationUid,
        from: fromDate.toUtc().toIso8601String(),
        order: 'completed_at desc',
      );

      final Map<DateTime, List<Map<String, dynamic>>> grouped = {};

      for (final row in results) {
        final completed = DateTime.tryParse(row['completed_at']?.toString() ?? '')?.toLocal();
        if (completed == null) continue;

        final dayKey = DateTime(completed.year, completed.month, completed.day);
        grouped.putIfAbsent(dayKey, () => []).add(row);
      }

      final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

      if (mounted) {
        setState(() {
          _groupedOrders = grouped;
          _sortedDates = sortedKeys;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e, stack) {
      debugPrint('History fetch failed: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load history';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.red.shade700),
            ),
          ),
        ),
      );
    }

    if (_sortedDates.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off_rounded, size: 88, color: Colors.grey[300]),
              const SizedBox(height: 24),
              const Text(
                'No completed orders in last 10 days',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'They will appear here once processed',
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchRecentHistory();
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _sortedDates.length,
          itemBuilder: (context, i) {
            final date = _sortedDates[i];
            final orders = _groupedOrders[date]!;
            final count = orders.length;
            final totalL = orders.fold<double>(
              0,
              (sum, o) => sum + (double.tryParse(o['liters']?.toString() ?? '0') ?? 0),
            );

            final isToday = _isToday(date);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DailyHistoryDetailPage(
                      date: date,
                      orders: orders,
                    ),
                  ),
                );
              },
              child: Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: isToday ? 3 : 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                color: isToday ? Colors.teal.shade50 : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), // slimmer vertical padding
                  child: Row(
                    children: [
                      // Left: Small date circle
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isToday ? Colors.teal.shade100 : Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          DateFormat('d').format(date),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isToday ? Colors.teal.shade800 : Colors.blueGrey.shade700,
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Right: All text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDateHeader(date),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                _chip('$count orders', Colors.blue),
                                _chip('${totalL.toStringAsFixed(1)} L', Colors.teal),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 26),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(date);
  }

  Widget _chip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade800,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}