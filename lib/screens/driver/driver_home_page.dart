import 'dart:async';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../constants/app_enums.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';
import 'station_queue_page.dart';
import 'order_detail_page.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  final _currentPromoIndex = ValueNotifier<int>(0);

  final Map<String, dynamic> _stats = {
    'todayEarnings': '4,820 ETB',
    'completedToday': '12',
    'rating': '4.9',
    'activeHours': '6h 45m',
  };

  String? _userUid;
  late Future<List<Map<String, dynamic>>> _stationsFuture;
  List<Map<String, dynamic>> _homeOrders = [];
  bool _ordersLoading = true;
  String? _ordersError;
  Timer? _ordersTimer;

  final List<Map<String, String>> _promotions = [
    {'title': 'Fuel & Win Big!', 'subtitle': 'Refuel 50L+ this week → chance to win 5,000 ETB', 'color': '0xFF1976D2'},
    {'title': 'Refer & Get Fuel', 'subtitle': 'Invite friends • Both receive 150 ETB fuel credit', 'color': '0xFF4CAF50'},
    {'title': 'Night Fuel Offer', 'subtitle': '8 ETB/L discount on Diesel 10 PM – 6 AM', 'color': '0xFFFF5722'},
    {'title': 'Partner Bonus', 'subtitle': 'Extra 3% cashback at Total & NOC stations', 'color': '0xFF9C27B0'},
  ];

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    _userUid = user?.uid;
    if (_userUid != null) {
      _stationsFuture = _fetchNearbyStations();
      _loadHomeOrders();
      _ordersTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadHomeOrders());
    }
  }

  @override
  void dispose() {
    _currentPromoIndex.dispose();
    _ordersTimer?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchNearbyStations() async {
    try {
      final rows = await AppApi.stations(
        order: 'created_at desc',
        limit: 15,
        withWaiting: true,
      );

      return rows.map((row) {
        final name = (row['name'] ?? row['display_name'] ?? 'Unnamed Station').toString();
        final address = row['address'] as String? ?? 'No address available';
        final city = (row['city'] ?? row['station_city'] ?? '').toString();
        final statusStr = (row['status'] as String?)?.toLowerCase() ?? 'active';
        final isOpen = statusStr == 'active' || statusStr == 'open';
        final waitingOrders = (row['waiting_orders'] as num?)?.toInt() ?? 0;

        return {
          'name': name,
          'address': address.isNotEmpty ? '$address, $city' : 'No address',
          'stationId': (row['station_id'] ?? row['uid'] ?? '').toString(),
          'isOpen': isOpen,
          'isRecommended': name.toLowerCase().contains('total') ||
              name.toLowerCase().contains('noc') ||
              name.toLowerCase().contains('mis'),
          'waiting_orders': waitingOrders,
          'is_24_hours': row['is_24_hours'] as bool? ?? false,
        };
      }).toList();
    } catch (e, stack) {
      debugPrint("Stations fetch error: $e\n$stack");
      return [];
    }
  }

  Future<void> _loadHomeOrders() async {
    if (_userUid == null || !mounted) return;
    setState(() {
      _ordersLoading = true;
      _ordersError = null;
    });
    try {
      final rows = await AppApi.preorders(
        driverUid: _userUid,
        statuses: const ['waiting'],
        today: true,
        order: 'created_at desc',
        limit: 4,
      );
      if (mounted) {
        setState(() {
          _homeOrders = rows;
          _ordersLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Home orders query failed: $e');
      if (mounted) {
        setState(() {
          _ordersError = 'Failed to load recent orders';
          _ordersLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _stationsFuture = _fetchNearbyStations();
              _loadHomeOrders();
            });
            await Future.delayed(const Duration(milliseconds: 1200));
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Promotions Carousel
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    CarouselSlider.builder(
                      itemCount: _promotions.length,
                      options: CarouselOptions(
                        height: 100,
                        viewportFraction: 0.92,
                        enlargeCenterPage: true,
                        enlargeFactor: 0.14,
                        autoPlay: true,
                        autoPlayInterval: const Duration(seconds: 5),
                        onPageChanged: (index, _) => _currentPromoIndex.value = index,
                      ),
                      itemBuilder: (context, index, _) {
                        final promo = _promotions[index];
                        final color = Color(int.parse(promo['color']!));
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: const Alignment(0.8, 1.0),
                              colors: [color.withOpacity(0.95), color.withOpacity(0.8)],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  promo['title']!,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  promo['subtitle']!,
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<int>(
                      valueListenable: _currentPromoIndex,
                      builder: (context, activeIndex, _) {
                        return AnimatedSmoothIndicator(
                          activeIndex: activeIndex,
                          count: _promotions.length,
                          effect: WormEffect(
                            dotHeight: 7,
                            dotWidth: 7,
                            spacing: 8,
                            activeDotColor: colorScheme.primary,
                            dotColor: Colors.grey[300]!,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Compact Stats
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 78,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildUltraCompactStatCard(
                          _StatItem(Icons.attach_money_rounded, "Today's Earnings", _stats['todayEarnings']!, Colors.green[700]!),
                          theme,
                        ),
                        _buildUltraCompactStatCard(
                          _StatItem(Icons.check_circle_outline_rounded, 'Completed', _stats['completedToday']!, Colors.blue[700]!),
                          theme,
                        ),
                        _buildUltraCompactStatCard(
                          _StatItem(Icons.star_rounded, 'Rating', _stats['rating']!, Colors.amber[700]!),
                          theme,
                        ),
                        _buildUltraCompactStatCard(
                          _StatItem(Icons.timer_rounded, 'Active Hours', _stats['activeHours']!, Colors.purple[700]!),
                          theme,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // My Fuel Queue Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                  child: Text(
                    'My Fuel Queue - Today',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Orders
              if (_userUid == null)
                SliverToBoxAdapter(child: _buildSignInPrompt(theme))
              else if (_ordersLoading)
                const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(60), child: CircularProgressIndicator())))
              else if (_ordersError != null)
                SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(_ordersError!, style: const TextStyle(color: Colors.red)))))
              else if (_homeOrders.isEmpty)
                SliverToBoxAdapter(child: _buildNoOrdersMessage(theme))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final order = _homeOrders[index];
                      final orderId = order['id']?.toString() ?? '—';
                      return buildCompactOrderCard(order, orderId, theme, colorScheme, context);
                    },
                    childCount: _homeOrders.length,
                  ),
                ),

              // Nearby Fuel Stations Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Nearby Fuel Stations',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Stations list
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 138, // adjusted for taller modern card
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _stationsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No stations available', style: TextStyle(color: Colors.grey)));
                      }
                      final stations = snapshot.data!;
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: stations.length,
                        itemBuilder: (context, index) => _buildLiveStationCard(stations[index], theme, colorScheme),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // Modern attractive station card
  // ────────────────────────────────────────────────
  Widget _buildLiveStationCard(Map<String, dynamic> station, ThemeData theme, ColorScheme colorScheme) {
    final isOpen = station['isOpen'] == true;
    final recommended = station['isRecommended'] == true;
    final waiting = station['waiting_orders'] as int? ?? 0;
    final has24h = station['is_24_hours'] == true;

    final statusColor = isOpen ? Colors.green : Colors.red;
    final statusText = isOpen ? 'OPEN' : 'CLOSED';

    final queueColor = waiting > 10
        ? Colors.red.shade700
        : waiting > 4
            ? Colors.orange.shade800
            : Colors.green.shade700;

    return Container(
      width: 264,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: recommended
            ? Border.all(color: colorScheme.primary.withOpacity(0.5), width: 1.5)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isOpen
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StationQueuePage(
                          stationId: station['stationId'],
                          stationName: station['name'],
                          dieselPrice: '65.50',
                          benzenePrice: '70.00',
                        ),
                      ),
                    )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name + status + 24h
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          station['name'] ?? 'Station',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: recommended ? colorScheme.primary : Colors.black87,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (has24h) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.nights_stay_rounded, size: 18, color: Colors.indigo.shade600),
                      ],
                    ],
                  ),
                ),

                // Queue + fuel tags
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: queueColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people, size: 16, color: queueColor),
                            const SizedBox(width: 6),
                            Text(
                              '$waiting',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: queueColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Simple fuel availability tags (example)
                      _buildFuelTag('P', Colors.blue, true),
                      const SizedBox(width: 6),
                      _buildFuelTag('D', Colors.green, true),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Address
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          station['address'] ?? 'No address',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFuelTag(String label, Color color, bool available) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: available ? color.withOpacity(0.15) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: available ? color : Colors.grey.shade400,
          width: 1.2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: available ? color : Colors.grey.shade600,
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // Compact order card (unchanged from previous modern version)
  // ────────────────────────────────────────────────
  Widget buildCompactOrderCard(
    Map<String, dynamic> data,
    String orderId,
    ThemeData theme,
    ColorScheme colorScheme,
    BuildContext context,
  ) {
    final stationName = (data['station_name'] as String?)?.trim() ?? 'Unknown Station';
    final fuelType = fuelTypeLabel(data['fuel_type']?.toString());
    final liters = double.tryParse(data['liters']?.toString() ?? '0') ?? 0.0;

    DateTime? createdAt;
    final createdRaw = data['created_at'];
    if (createdRaw is DateTime) {
      createdAt = createdRaw;
    } else if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw);
    }
    final timeStr = createdAt != null ? DateFormat('HH:mm').format(createdAt.toLocal()) : '—';

    final statusColor = Colors.orange.shade700;
    final statusBg = Colors.orange.withOpacity(0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailPage(orderId: orderId, orderData: data),
            ),
          );
        },
        child: Container(
          height: 68,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stationName,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: -0.1),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          'Waiting • $timeStr',
                          style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fuelType,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${liters.toStringAsFixed(1)} L',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUltraCompactStatCard(_StatItem item, ThemeData theme) {
    return SizedBox(
      width: 76,
      child: Card(
        elevation: 0.8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 18, color: item.color),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.value,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.05),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 8.2, color: Colors.grey[700], height: 1.05),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInPrompt(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.login_rounded, size: 70, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Please sign in to view your orders',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoOrdersMessage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.local_gas_station_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No waiting orders today', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(
              'Your active pre-orders will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  _StatItem(this.icon, this.title, this.value, this.color);
}