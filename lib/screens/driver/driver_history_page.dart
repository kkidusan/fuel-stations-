// File: driver_history_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_enums.dart';
import '../../services/api_client.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';
import 'driver_fuel_detail_page.dart'; // ← import the detail page

class DriverHistoryPage extends StatefulWidget {
  const DriverHistoryPage({super.key});

  @override
  State<DriverHistoryPage> createState() => _DriverHistoryPageState();
}

class _DriverHistoryPageState extends State<DriverHistoryPage> {
  bool _isLoading = true;
  String _errorMessage = '';

  List<Map<String, dynamic>> _historyItems = [];
  double _totalLiters = 0.0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _loadDriverDataAndHistory();
  }

  Future<void> _loadDriverDataAndHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _historyItems = [];
      _totalLiters = 0.0;
      _count = 0;
    });

    try {
      final user = AuthService.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // 1. Get driver's license plate
      final plateRaw = user.plate;
      final plate = (plateRaw?.trim().isNotEmpty == true)
          ? plateRaw!.trim().toUpperCase()
          : null;

      if (plate == null || plate.isEmpty) {
        throw Exception('License plate not set');
      }

      // 2. Fetch last 10 days of completed preorders
      final startDate = DateTime.now().subtract(const Duration(days: 10));
      final fromDate = DateTime(startDate.year, startDate.month, startDate.day).toUtc();

      final results = await AppApi.history(
        driverPlate: plate,
        from: fromDate.toIso8601String(),
        limit: 50,
        order: 'desc',
      );

      final List<Map<String, dynamic>> items = [];
      double totalLiters = 0.0;

      for (final row in results) {
        final litersRaw = row['liters']?.toString() ?? '0';
        final liters = double.tryParse(litersRaw) ?? 0.0;

        final completedRaw = row['completed_at'] ?? row['created_at'];
        final dateStr = _formatHistoryDate(completedRaw);

        items.add({
          'id': row['id']?.toString() ?? '',
          'date': dateStr,
          'fuel_type': fuelTypeLabel(row['fuel_type']?.toString()),
          'liters': liters,
          'station': '—',
          'status': (row['status'] as String?)?.toLowerCase() ?? 'completed',
          'notes': (row['notes'] as String?)?.trim() ?? '',
          // Pass raw timestamp for better detail page formatting
          'completed_at': completedRaw,
        });

        totalLiters += liters;
      }

      if (mounted) {
        setState(() {
          _historyItems = items;
          _totalLiters = totalLiters;
          _count = items.length;
          _isLoading = false;
        });
      }
    } on ApiException catch (e, stack) {
      debugPrint('Driver history failed: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load history: ${e.message}';
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Driver history failed: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load history: ${e.toString().split('\n').first}';
          _isLoading = false;
        });
      }
    }
  }

  String _formatHistoryDate(dynamic dateRaw) {
    final raw = dateRaw?.toString();
    final parsed = (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw);
    if (parsed == null) return '—';
    final dt = parsed.toLocal();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDriverDataAndHistory,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        'Last 10 days • $_count fills • ${_totalLiters.toStringAsFixed(1)} L',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red, fontSize: 15),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (_historyItems.isEmpty && _errorMessage.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_toggle_off_rounded,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No fuel history in last 10 days',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Completed fuel pickups will appear here',
                          style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _historyItems[index];
                        return _buildHistoryTile(context, item);
                      },
                      childCount: _historyItems.length,
                    ),
                  ),
                ),

              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Export History (CSV)'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Export coming soon...'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTile(BuildContext context, Map<String, dynamic> item) {
    final liters = item['liters'] as double;
    final isCompleted = (item['status'] as String).contains('complete');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DriverFuelDetailPage(order: item),
            ),
          );
        },
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_gas_station_rounded,
              color: Colors.teal.shade700,
              size: 28,
            ),
          ),
          title: Text(
            item['fuel_type'],
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['date'],
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                'Station: ${item['station']}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${liters.toStringAsFixed(1)} L',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCompleted ? 'Completed' : 'Other',
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}