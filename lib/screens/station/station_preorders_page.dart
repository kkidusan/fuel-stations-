import 'package:flutter/material.dart';

import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';
import 'station_preorder_detail_page.dart';

class StationPreordersPage extends StatefulWidget {
  const StationPreordersPage({super.key});

  @override
  State<StationPreordersPage> createState() => _StationPreordersPageState();
}

class _StationPreordersPageState extends State<StationPreordersPage> {
  String? _currentUserEmail;
  String? _stationUid;
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _orders = [];
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentStation();
  }

  Future<void> _loadCurrentStation() async {
    final user = AuthService.currentUser;
    if (user == null || user.email.trim().isEmpty) {
      setState(() {
        _currentUserEmail = null;
        _isLoading = false;
      });
      return;
    }

    _currentUserEmail = user.email.trim();
    _stationUid = user.uid;

    if (_stationUid != null && _stationUid!.isNotEmpty) {
      await _fetchOrders();
    } else {
      _errorMessage = 'No station profile found for this account';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchOrders() async {
    if (_stationUid == null || _stationUid!.isEmpty) return;

    try {
      List<Map<String, dynamic>> results;

      if (_showHistory) {
        // History: today's completed orders
        results = await AppApi.history(
          stationId: _stationUid,
          today: true,
          order: 'completed_at desc',
          limit: 150,
        );
      } else {
        // Active orders
        results = await AppApi.preorders(
          stationId: _stationUid,
          order: 'created_at desc',
        );
      }

      if (mounted) {
        setState(() {
          _orders = results;
          _errorMessage = null;
        });
      }
    } catch (e, stack) {
      debugPrint('Failed to fetch orders: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load orders';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUserEmail == null) {
      return _centeredMessage('Please sign in to view orders');
    }

    if (_stationUid == null || _stationUid!.isEmpty) {
      return _centeredMessage(
        _errorMessage ?? 'Station profile not found',
        color: Colors.orange.shade800,
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchOrders();
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Active'),
                    selected: !_showHistory,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _showHistory = false);
                        _fetchOrders();
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text("Today's History"),
                    selected: _showHistory,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _showHistory = true);
                        _fetchOrders();
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showHistory ? Icons.history : Icons.hourglass_empty_rounded,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _showHistory ? 'No completed orders today' : 'No active pre-orders yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final data = _orders[index];

                        final orderId = data['id']?.toString();
                        final driver = (data['driver_name'] as String?)?.trim() ?? 'Unknown';
                        final plate = (data['driver_plate'] as String?)?.trim().toUpperCase() ?? '—';
                        final fuel = (data['fuel_type'] as String?)?.trim() ?? '—';
                        final liters = double.tryParse(data['liters']?.toString() ?? '0') ?? 0.0;

                        final statusRaw = (data['status'] as String?)?.trim().toLowerCase() ?? 'waiting';
                        final statusInfo = _getStatusInfo(statusRaw);

                        final isHistory = _showHistory;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: orderId != null
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StationPreorderDetailPage(
                                          orderId: orderId,
                                          orderData: data,
                                          isFromHistory: isHistory,
                                        ),
                                      ),
                                    ).then((value) {
                                      if (value == true && mounted && !_showHistory) {
                                        _fetchOrders(); // refresh active list after collect
                                      }
                                    });
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.local_shipping_outlined,
                                      size: 28,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          driver,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$fuel • ${liters.toStringAsFixed(1)} L',
                                          style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          plate,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: statusInfo.color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      statusInfo.label,
                                      style: TextStyle(
                                        color: statusInfo.color,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _centeredMessage(String message, {Color color = Colors.grey}) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({String label, Color color}) _getStatusInfo(String status) {
    final s = status.toLowerCase().trim();
    return switch (s) {
      'waiting' || 'pending'   => (label: 'WAITING', color: Colors.orange.shade800),
      'confirmed'              => (label: 'CONFIRMED', color: Colors.blue.shade700),
      'ready'                  => (label: 'READY', color: Colors.teal.shade700),
      'completed' || 'done'    => (label: 'COMPLETED', color: Colors.green.shade700),
      'cancelled' || 'rejected' => (label: 'CANCELLED', color: Colors.red.shade700),
      _                        => (label: s.toUpperCase(), color: Colors.blueGrey.shade700),
    };
  }
}