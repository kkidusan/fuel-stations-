import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_enums.dart';
import '../../../services/api_client.dart';
import '../../../services/app_api.dart';
import '../order_detail_page.dart'; // ← adjust path if needed

class FuelQueueListPage extends StatefulWidget {
  final String userEmail;

  const FuelQueueListPage({
    super.key,
    required this.userEmail,
  });

  @override
  State<FuelQueueListPage> createState() => _FuelQueueListPageState();
}

class _FuelQueueListPageState extends State<FuelQueueListPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadWaitingOrders();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadWaitingOrders();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWaitingOrders() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now().toUtc();
      final todayStart = DateTime.utc(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final rows = await AppApi.preorders(
        driverEmail: widget.userEmail.trim().toLowerCase(),
        statuses: const ['waiting'],
        from: todayStart.toIso8601String(),
        to: todayEnd.toIso8601String(),
        order: 'asc',
      );

      if (mounted) {
        setState(() {
          _orders = rows;
          _isLoading = false;
        });
      }
    } on ApiException catch (e, stack) {
      debugPrint('Failed to load waiting orders: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Failed to load waiting orders: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load queue. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Fuel Queue - Today'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 64, color: Colors.red[400]),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 16, color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          onPressed: _loadWaitingOrders,
                        ),
                      ],
                    ),
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_gas_station_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No waiting orders today',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Your confirmed pre-orders for today will appear here once they are waiting at the station.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadWaitingOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          final orderId = order['id']?.toString() ?? '—';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildQueueCard(order, orderId, theme, colorScheme),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildQueueCard(
    Map<String, dynamic> data,
    String orderId,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final stationName = (data['station_name'] as String?)?.trim() ?? 'Unknown Station';
    final fuelType = fuelTypeLabel(data['fuel_type']?.toString());

    final liters = _safeToDouble(data['liters']);

    DateTime? createdAt;
    final createdRaw = data['created_at'];
    if (createdRaw is DateTime) {
      createdAt = createdRaw;
    } else if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw);
    }

    final createdStr = createdAt != null
        ? DateFormat('dd MMM • HH:mm').format(createdAt.toLocal())
        : '—';

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailPage(
                orderId: orderId,
                orderData: data,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.hourglass_bottom_rounded,
                      color: Colors.orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stationName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$fuelType • ${liters.toStringAsFixed(0)} L',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[700],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Ordered $createdStr',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Waiting',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}