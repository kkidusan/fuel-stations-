import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
    _loadStationAutoId();
  }

  Future<void> _loadStationAutoId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No authenticated user');
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        setState(() {
          _stationAutoId = data['autoID'] as String?;
        });
      } else {
        debugPrint('No user document found for email: ${user.email}');
      }
    } catch (e) {
      debugPrint('Error loading station autoID: $e');
    }
  }

  Stream<int> _pendingOrdersCountStream() {
    final stationId = _stationAutoId?.trim();
    if (stationId == null || stationId.isEmpty) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('preorders')
        .where('stationId', isEqualTo: stationId)
        .where('status', isEqualTo: 'waiting')
        .snapshots()
        .map((snap) => snap.size);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Stats section
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                ),
                delegate: SliverChildListDelegate([
                  // Tappable Orders card with ripple
                  InkWell(
                    onTap: widget.onNavigateToPreorders,
                    borderRadius: BorderRadius.circular(12),
                    child: _MiniStatCard(
                      icon: Icons.local_gas_station,
                      title: "Orders",
                      child: _stationAutoId == null
                          ? const Text("—", style: TextStyle(fontSize: 22))
                          : StreamBuilder<int>(
                              stream: _pendingOrdersCountStream(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  debugPrint('Orders stream error: ${snapshot.error}');
                                  return const Text(
                                    "Error",
                                    style: TextStyle(color: Colors.red, fontSize: 18),
                                  );
                                }
                                if (snapshot.connectionState == ConnectionState.waiting ||
                                    !snapshot.hasData) {
                                  return const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  );
                                }
                                return Text(
                                  "${snapshot.data}",
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                      color: colorScheme.primary,
                    ),
                  ),

                  const _MiniStatCard(
                    icon: Icons.attach_money,
                    title: "Revenue",
                    value: "48.9k",
                    color: Colors.teal,
                  ),
                  const _MiniStatCard(
                    icon: Icons.inventory,
                    title: "Stock",
                    value: "78%",
                    color: Colors.orange,
                  ),
                  const _MiniStatCard(
                    icon: Icons.people,
                    title: "Customers",
                    value: "142",
                    color: Colors.purple,
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
                    icon: Icons.notifications_active_outlined,
                    title: 'Pending Orders',
                    subtitle: 'Tap to view',
                    color: Colors.blue,
                    // You can also connect this to the same callback:
                    // onTap: widget.onNavigateToPreorders,
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.price_change_outlined,
                    title: 'Update Prices',
                    subtitle: 'Last: 2h ago',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.analytics_outlined,
                    title: 'Reports',
                    subtitle: 'Sales & trends',
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Station config',
                    color: Colors.grey.shade700,
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
        child: const Icon(Icons.add),
        onPressed: () {
          // TODO: Quick sale / new action
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Stat card
// ────────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? child;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.title,
    this.value,
    this.child,
    required this.color,
  }) : assert(value != null || child != null, 'Provide value or child');

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: color),
            const Spacer(),
            child ??
                Text(
                  value!,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Compact action tile
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
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          minLeadingWidth: 40,
          leading: Icon(icon, size: 22, color: color),
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, size: 18),
        ),
      ),
    );
  }
}