import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'station_settings_page.dart';
import 'station_manage_page.dart';
import 'station_pumps_page.dart';

class StationHomePage extends StatefulWidget {
  final VoidCallback? onNavigateToPreorders;

  const StationHomePage({
    super.key,
    this.onNavigateToPreorders,
  });

  @override
  State<StationHomePage> createState() => _StationHomePageState();
}

class _StationHomePageState extends State<StationHomePage> {
  bool isStationOpen = true;
  String? _stationAutoId;

  @override
  void initState() {
    super.initState();
    _loadStationData();
  }

  Future<void> _loadStationData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No authenticated user');
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _stationAutoId = data['autoID'] as String?;
        });
      } else {
        debugPrint('No user document found for user: ${user.uid}');
      }
    } catch (e) {
      debugPrint('Error loading station data: $e');
    }
  }

  Stream<int> _pendingOrdersCountStream() {
    final autoId = _stationAutoId?.trim();
    if (autoId == null || autoId.isEmpty) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('preorders')
        .where('stationId', isEqualTo: autoId)
        .where('status', isEqualTo: 'waiting')
        .snapshots()
        .map((snap) => snap.size);
  }

  Stream<int> _availablePumpsCountStream() {
    final autoId = _stationAutoId?.trim();
    if (autoId == null || autoId.isEmpty) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('station_pumps')
        .doc(autoId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return 0;
      
      final data = snapshot.data() as Map<String, dynamic>;
      final pumps = List<Map<String, dynamic>>.from(data['pumps'] ?? []);
      
      return pumps.where((pump) {
        final status = pump['status']?.toString() ?? '';
        return status == 'available';
      }).length;
    });
  }

  Stream<int> _totalPumpsCountStream() {
    final autoId = _stationAutoId?.trim();
    if (autoId == null || autoId.isEmpty) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('station_pumps')
        .doc(autoId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return 0;
      
      final data = snapshot.data() as Map<String, dynamic>;
      final pumps = List<Map<String, dynamic>>.from(data['pumps'] ?? []);
      return pumps.length;
    });
  }

  Stream<double> _revenueStream() {
    final autoId = _stationAutoId?.trim();
    if (autoId == null || autoId.isEmpty) {
      return Stream.value(0.0);
    }

    return FirebaseFirestore.instance
        .collection('station_pumps')
        .doc(autoId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return 0.0;
      
      final data = snapshot.data() as Map<String, dynamic>;
      final pumps = List<Map<String, dynamic>>.from(data['pumps'] ?? []);
      
      double totalEarnings = 0.0;
      for (final pump in pumps) {
        final earnings = pump['totalEarnings'];
        if (earnings != null) {
          totalEarnings += (earnings is num) ? earnings.toDouble() : 0.0;
        }
      }
      return totalEarnings;
    });
  }

  Stream<int> _inUsePumpsCountStream() {
    final autoId = _stationAutoId?.trim();
    if (autoId == null || autoId.isEmpty) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('station_pumps')
        .doc(autoId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return 0;
      
      final data = snapshot.data() as Map<String, dynamic>;
      final pumps = List<Map<String, dynamic>>.from(data['pumps'] ?? []);
      
      return pumps.where((pump) {
        final status = pump['status']?.toString() ?? '';
        return status == 'in-use';
      }).length;
    });
  }

  Stream<int> _servedTodayStream() {
    final autoId = _stationAutoId?.trim();
    if (autoId == null || autoId.isEmpty) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('station_pumps')
        .doc(autoId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return 0;
      
      final data = snapshot.data() as Map<String, dynamic>;
      final pumps = List<Map<String, dynamic>>.from(data['pumps'] ?? []);
      
      int servedToday = 0;
      for (final pump in pumps) {
        final served = pump['servedToday'];
        if (served != null) {
          servedToday += (served is num) ? served.toInt() : 0;
        }
      }
      return servedToday;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            
           
            // Stats section - 3x2 grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35, // Adjusted for better text fit
                ),
                delegate: SliverChildListDelegate([
                  // Pending Orders Card
                  _MiniStatCard(
                    icon: Icons.shopping_cart_outlined,
                    title: "Pending Orders",
                    color: Colors.blue,
                    child: _stationAutoId == null
                        ? const Text("—", style: TextStyle(fontSize: 20))
                        : StreamBuilder<int>(
                            stream: _pendingOrdersCountStream(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _buildErrorWidget();
                              }
                              if (snapshot.connectionState == ConnectionState.waiting ||
                                  !snapshot.hasData) {
                                return _buildLoadingWidget();
                              }
                              return Text(
                                "${snapshot.data}",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              );
                            },
                          ),
                    onTap: widget.onNavigateToPreorders,
                  ),

                  // Total Pumps Card
                  _MiniStatCard(
                    icon: Icons.local_gas_station_outlined,
                    title: "Total Pumps",
                    color: Colors.teal,
                    child: _stationAutoId == null
                        ? const Text("—", style: TextStyle(fontSize: 20))
                        : StreamBuilder<int>(
                            stream: _totalPumpsCountStream(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _buildErrorWidget();
                              }
                              if (snapshot.connectionState == ConnectionState.waiting ||
                                  !snapshot.hasData) {
                                return _buildLoadingWidget();
                              }
                              return Text(
                                "${snapshot.data}",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              );
                            },
                          ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => StationPumpsPage(stationId: _stationAutoId),
                        ),
                      );
                    },
                  ),

                  // Available Pumps Card
                  _MiniStatCard(
                    icon: Icons.check_circle_outline,
                    title: "Available",
                    color: Colors.green,
                    child: _stationAutoId == null
                        ? const Text("—", style: TextStyle(fontSize: 20))
                        : StreamBuilder<int>(
                            stream: _availablePumpsCountStream(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _buildErrorWidget();
                              }
                              if (snapshot.connectionState == ConnectionState.waiting ||
                                  !snapshot.hasData) {
                                return _buildLoadingWidget();
                              }
                              return Text(
                                "${snapshot.data}",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              );
                            },
                          ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => StationPumpsPage(stationId: _stationAutoId),
                        ),
                      );
                    },
                  ),

                  // In-Use Pumps Card
                  _MiniStatCard(
                    icon: Icons.sync,
                    title: "In-Use",
                    color: Colors.orange,
                    child: _stationAutoId == null
                        ? const Text("—", style: TextStyle(fontSize: 20))
                        : StreamBuilder<int>(
                            stream: _inUsePumpsCountStream(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _buildErrorWidget();
                              }
                              if (snapshot.connectionState == ConnectionState.waiting ||
                                  !snapshot.hasData) {
                                return _buildLoadingWidget();
                              }
                              return Text(
                                "${snapshot.data}",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              );
                            },
                          ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => StationPumpsPage(stationId: _stationAutoId),
                        ),
                      );
                    },
                  ),

                  // Revenue Card
                  _MiniStatCard(
                    icon: Icons.attach_money_outlined,
                    title: "Revenue",
                    color: Colors.purple,
                    child: _stationAutoId == null
                        ? Text(
                            "₹0",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          )
                        : StreamBuilder<double>(
                            stream: _revenueStream(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _buildErrorWidget();
                              }
                              if (snapshot.connectionState == ConnectionState.waiting ||
                                  !snapshot.hasData) {
                                return _buildLoadingWidget();
                              }
                              return Text(
                                "₹${snapshot.data!.toStringAsFixed(0)}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              );
                            },
                          ),
                    onTap: () {
                      // Navigate to revenue reports page
                    },
                  ),

                  // Manage Station Card (NEW)
                  _MiniStatCard(
                    icon: Icons.business_outlined,
                    title: "Manage Station",
                    color: Colors.blue[700]!,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.settings,
                          size: 32,
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Settings",
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const StationManagePage(),
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),

            // Quick Actions title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  'Quick Actions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),

            // Quick Actions list
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _CompactActionTile(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Pending Orders',
                    subtitle: 'View waiting orders',
                    color: Colors.blue,
                    onTap: widget.onNavigateToPreorders,
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.local_gas_station_outlined,
                    title: 'Add New Pump',
                    subtitle: 'Add a fuel pump',
                    color: Colors.green,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => StationPumpsPage(stationId: _stationAutoId),
                        ),
                      ).then((_) {
                        _loadStationData();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.analytics_outlined,
                    title: 'Station Reports',
                    subtitle: 'Sales & performance',
                    color: Colors.indigo,
                    onTap: () {
                      // Navigate to reports page
                    },
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.business_outlined,
                    title: 'Station Details',
                    subtitle: 'Manage station info',
                    color: Colors.blue[700]!,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const StationManagePage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.local_gas_station,
                    title: 'All Pumps',
                    subtitle: 'View all pumps',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => StationPumpsPage(stationId: _stationAutoId),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Station configuration',
                    color: Colors.grey[700]!,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const StationSettingsPage(),
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StationPumpsPage(stationId: _stationAutoId),
            ),
          ).then((_) {
            _loadStationData();
          });
        },
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const SizedBox(
      height: 24,
      width: 24,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    );
  }

  Widget _buildErrorWidget() {
    return const Text(
      "Error",
      style: TextStyle(
        color: Colors.red,
        fontSize: 16,
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Updated Stat card with dark mode support
// ────────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color color;
  final VoidCallback? onTap;

  const _MiniStatCard({
    required this.icon,
    required this.title,
    required this.child,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      elevation: isDark ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark 
          ? BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))
          : BorderSide.none,
      ),
      color: isDark 
        ? theme.colorScheme.surfaceVariant.withOpacity(0.5)
        : theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: child,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Updated Compact action tile with dark mode support
// ────────────────────────────────────────────────
class _CompactActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _CompactActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      elevation: isDark ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark 
          ? BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))
          : BorderSide.none,
      ),
      color: isDark 
        ? theme.colorScheme.surfaceVariant.withOpacity(0.5)
        : theme.colorScheme.surface,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          minLeadingWidth: 40,
          leading: Icon(
            icon,
            size: 22,
            color: color,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            size: 18,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}