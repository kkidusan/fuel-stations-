import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'station_queue_page.dart';
import 'order_detail_page.dart';

// ────────────────────────────────────────────────────────────────
//   SHARED COMPACT ORDER CARD WIDGET
// ────────────────────────────────────────────────────────────────
Widget buildCompactOrderCard(
  Map<String, dynamic> data,
  String orderId,
  ThemeData theme,
  ColorScheme colorScheme,
  BuildContext context,
) {
  final stationName = data['stationName'] as String? ?? 'Unknown Station';
  final fuelType = data['fuelType'] as String? ?? '—';
  final liters = (data['liters'] as num?)?.toDouble() ?? 0.0;
  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
  final createdStr = createdAt != null ? DateFormat('dd MMM • HH:mm').format(createdAt) : '—';
  final position = data['positionInQueue'] as int? ?? 4;

  final estReady = _getEstimatedReadyText(position);

  return Card(
    elevation: 1.2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    margin: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailPage(orderId: orderId, orderData: data),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.hourglass_bottom_rounded,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stationName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$fuelType • ${liters.toStringAsFixed(0)} L',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.people_alt_rounded, size: 15, color: Colors.grey[700]),
                      const SizedBox(width: 5),
                      Text(
                        '$position ahead • $estReady',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12.5,
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (createdStr.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Ordered $createdStr',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Colors.grey[500],
                        height: 1.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    ),
  );
}

String _getEstimatedReadyText(int ahead) {
  if (ahead <= 0) return 'Ready now';
  return '~${ahead * 2} min';
}

// ────────────────────────────────────────────────────────────────
//   HELPER - Get today's date range (server-compatible)
// ────────────────────────────────────────────────────────────────
Query<Map<String, dynamic>> _todayWaitingQuery(String fieldEqualValue, String fieldName) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  return FirebaseFirestore.instance
      .collection('preorders')
      .where(fieldName, isEqualTo: fieldEqualValue)
      .where('status', isEqualTo: 'waiting')
      .where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
      )
      .where(
        'createdAt',
        isLessThan: Timestamp.fromDate(todayEnd),
      );
}

// ────────────────────────────────────────────────────────────────
//   FULL QUEUE LIST PAGE - only today's waiting orders
// ────────────────────────────────────────────────────────────────
class FuelQueueListPage extends StatelessWidget {
  final String userEmail;

  const FuelQueueListPage({
    super.key,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final todayQuery = _todayWaitingQuery(userEmail, 'driverEmail')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Fuel Queue - Today'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: todayQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
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
                  Icon(Icons.local_gas_station_outlined, size: 72, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No waiting orders today', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  Text(
                    'Your active pre-orders for today will appear here',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final orderId = doc.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: buildCompactOrderCard(data, orderId, theme, colorScheme, context),
              );
            },
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//   MAIN DRIVER HOME PAGE
// ────────────────────────────────────────────────────────────────
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

  String? _userEmail;
  late Future<List<Map<String, dynamic>>> _stationsFuture;
  
  // Cache for station status
  final Map<String, bool> _stationStatusCache = {};

  final List<Map<String, String>> _promotions = [
    {'title': 'Fuel & Win Big!', 'subtitle': 'Refuel 50L+ this week → chance to win 5,000 ETB', 'color': '0xFF1976D2'},
    {'title': 'Refer & Get Fuel', 'subtitle': 'Invite friends • Both receive 150 ETB fuel credit', 'color': '0xFF4CAF50'},
    {'title': 'Night Fuel Offer', 'subtitle': '8 ETB/L discount on Diesel 10 PM – 6 AM', 'color': '0xFFFF5722'},
    {'title': 'Partner Bonus', 'subtitle': 'Extra 3% cashback at Total & NOC stations', 'color': '0xFF9C27B0'},
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _userEmail = user?.email?.trim().toLowerCase();
    _stationsFuture = _fetchNearbyStations();
  }

  Future<List<Map<String, dynamic>>> _fetchNearbyStations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'station')
          .limit(15)
          .get();

      final stations = <Map<String, dynamic>>[];
      
      // Fetch status for each station
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? 'Unnamed Station';
        final address = data['address'] as String? ?? 'No address available';
        final autoID = data['autoID'] as String? ?? 'no-autoID';
        final isOpen = data['isOpen'] as bool? ?? true; // Default to open if not specified
        
        // Cache the status
        final stationId = autoID != null && autoID != 'no-autoID' && autoID.trim().isNotEmpty 
            ? autoID.trim() 
            : doc.id;
        _stationStatusCache[stationId] = isOpen;
        
        stations.add({
          'name': name,
          'address': address,
          'autoID': autoID,
          'stationDocId': doc.id,
          'distance': address, 
          'price': 'Diesel 65.50 ETB/L', 
          'isOpen': isOpen,
          'isRecommended': name.toLowerCase().contains('total') ||
              name.toLowerCase().contains('noc') ||
              name.toLowerCase().contains('mis'),
        });
      }
      
      return stations;
    } catch (e) {
      debugPrint("Error fetching stations: $e");
      return [];
    }
  }
  
  // Helper method to get station status
  bool _isStationOpen(Map<String, dynamic> station) {
    final stationId = _getStationId(station);
    return _stationStatusCache[stationId] ?? true; // Default to open if not cached
  }

  @override
  void dispose() {
    _currentPromoIndex.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    setState(() {
      _stationsFuture = _fetchNearbyStations();
    });
    await Future.delayed(const Duration(milliseconds: 1200));
  }

  String _getStationId(Map<String, dynamic> station) {
    final autoID = station['autoID'] as String?;
    if (autoID != null && autoID != 'no-autoID' && (autoID.trim().isNotEmpty)) {
      return autoID.trim();
    }
    return station['stationDocId'] as String;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          notificationPredicate: (notification) => notification.depth == 0,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Promotion Carousel (unchanged)
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
                        enlargeFactor: 0.15,
                        autoPlay: true,
                        autoPlayInterval: const Duration(seconds: 5),
                        autoPlayAnimationDuration: const Duration(milliseconds: 900),
                        autoPlayCurve: Curves.fastOutSlowIn,
                        pauseAutoPlayOnTouch: true,
                        scrollPhysics: const BouncingScrollPhysics(),
                        onPageChanged: (index, reason) => _currentPromoIndex.value = index,
                      ),
                      itemBuilder: (context, index, realIndex) {
                        final promo = _promotions[index];
                        final color = Color(int.parse(promo['color']!));

                        return GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Opening: ${promo['title']}')),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: ShapeDecoration(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: const Alignment(0.8, 1.0),
                                colors: [
                                  color.withAlpha(242),
                                  color.withAlpha(209),
                                  color.withAlpha(166),
                                ],
                              ),
                              shadows: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(41),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    promo['title']!,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    promo['subtitle']!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11.8,
                                      height: 1.20,
                                      color: Colors.white.withAlpha(240),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Claim Offer →',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<int>(
                      valueListenable: _currentPromoIndex,
                      builder: (context, activeIndex, child) {
                        return AnimatedSmoothIndicator(
                          activeIndex: activeIndex,
                          count: _promotions.length,
                          effect: WormEffect(
                            dotHeight: 8,
                            dotWidth: 8,
                            spacing: 10,
                            activeDotColor: colorScheme.primary,
                            dotColor: Colors.grey[300]!,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),

              // Stats Row (unchanged)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 116,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      final items = [
                        _StatItem(Icons.attach_money_rounded, "Today's Earnings", _stats['todayEarnings']!, Colors.green[700]!),
                        _StatItem(Icons.check_circle_outline_rounded, 'Completed', _stats['completedToday']!, Colors.blue[700]!),
                        _StatItem(Icons.star_rounded, 'Rating', _stats['rating']!, Colors.amber[700]!),
                        _StatItem(Icons.timer_rounded, 'Active Hours', _stats['activeHours']!, Colors.purple[700]!),
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildCompactStatCard(items[index], theme),
                      );
                    },
                  ),
                ),
              ),

              // My Fuel Queue Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'My Fuel Queue - Today',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              if (_userEmail == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.login_rounded, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Please sign in to view your orders',
                            style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                StreamBuilder<QuerySnapshot>(
                  stream: _todayWaitingQuery(_userEmail!, 'driverEmail').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red))),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.local_gas_station_outlined, size: 72, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text('No waiting orders today', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700])),
                                const SizedBox(height: 8),
                                Text('Your active pre-orders for today will appear here', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500])),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    const maxVisible = 2;
                    final showMore = docs.length > maxVisible;

                    return SliverList(
                      delegate: SliverChildListDelegate([
                        ...docs.take(maxVisible).map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final orderId = doc.id;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: buildCompactOrderCard(data, orderId, theme, colorScheme, context),
                          );
                        }),

                        if (showMore)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FuelQueueListPage(userEmail: _userEmail!),
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Show more (${docs.length - maxVisible})',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 20,
                                    color: colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ]),
                    );
                  },
                ),

              // Nearby Stations Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Nearby Stations',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Very Compact Stations List - only count today's waiting
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 114,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _stationsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No stations found', style: TextStyle(color: Colors.grey)));
                      }
                      final stations = snapshot.data!;
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: stations.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _buildLiveStationCard(stations[index], theme, colorScheme),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStationCard(
    Map<String, dynamic> station,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final recommended = station['isRecommended'] == true;
    final isOpen = _isStationOpen(station);
    final stationId = _getStationId(station);

    // Only count today's waiting orders
    final waitingStream = _todayWaitingQuery(stationId, 'stationId').snapshots();

    return SizedBox(
      width: 258,
      child: GestureDetector(
        onTap: isOpen ? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StationQueuePage(
                stationId: stationId,
                stationName: station['name'],
                dieselPrice: station['price'],
                benzenePrice: station['price'],
              ),
            ),
          );
        } : null,
        child: Card(
          elevation: recommended ? 2.5 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: isOpen 
              ? (recommended ? colorScheme.primaryContainer.withAlpha(46) : null)
              : Colors.grey[100], // Grey background for closed stations
          margin: EdgeInsets.zero,
          child: Opacity(
            opacity: isOpen ? 1.0 : 0.7, // Dim closed stations
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_gas_station_rounded,
                        color: isOpen ? Colors.green[700] : Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              station['name'],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                                color: isOpen ? null : Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOpen ? Colors.green[50] : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isOpen ? Colors.green : Colors.grey,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isOpen ? Icons.check_circle : Icons.cancel,
                                        size: 10,
                                        color: isOpen ? Colors.green : Colors.red,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isOpen ? 'OPEN' : 'CLOSED',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isOpen ? Colors.green[800] : Colors.red[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (recommended && isOpen)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: const Icon(
                                      Icons.recommend_rounded,
                                      color: Colors.blue,
                                      size: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              station['price'],
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 13.8,
                                fontWeight: FontWeight.w800,
                                color: isOpen ? Colors.green[800] : Colors.grey[600],
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '≈ ${station['distance']}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10.8,
                                color: isOpen ? Colors.grey[700] : Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (isOpen)
                        StreamBuilder<QuerySnapshot>(
                          stream: waitingStream,
                          builder: (context, snapshot) {
                            final count = snapshot.hasData ? snapshot.data!.size : 0;
                            final isLow = count <= 4;
                            final est = count == 0 ? 'No wait' : '~${count * 2} min';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isLow ? Colors.green[100] : Colors.orange[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count waiting',
                                    style: TextStyle(
                                      fontSize: 11.8,
                                      fontWeight: FontWeight.w700,
                                      color: isLow ? Colors.green[800] : Colors.orange[900],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  est,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10.5,
                                    color: isLow ? Colors.green[700] : Colors.orange[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Closed',
                                style: TextStyle(
                                  fontSize: 11.8,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Check hours',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10.5,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatCard(_StatItem item, ThemeData theme) {
    return SizedBox(
      width: 118,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 26, color: item.color),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey[700], height: 1.1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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