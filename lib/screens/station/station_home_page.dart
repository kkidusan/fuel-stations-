import 'dart:async';
import 'package:flutter/material.dart';
import 'station_settings_page.dart';
import 'station_manage_page.dart';
import '../../services/api_client.dart';
import '../../services/app_api.dart';
import '../../services/auth_user_service.dart';

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
  /// Legacy user UID (JWT `auth.sub`) — used as the station key for stats.
  String? _stationUid;

  Timer? _refreshTimer;

  bool _statsLoading = true;
  bool _statsError = false;

  int _pendingCount = 0;
  int _todayCompleted = 0;
  double _monthRev = 0.0;
  int _lowInventoryCount = 0;
  double _totalLiters = 0.0;
  double _petrolLiters = 0.0;
  double _dieselLiters = 0.0;
  double _keroseneLiters = 0.0;
  int _lowTanksCount = 0;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    _stationUid = user?.uid;

    if (_stationUid != null && _stationUid!.isNotEmpty) {
      _loadStats();
    }

    _refreshTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted && _stationUid != null && _stationUid!.isNotEmpty) {
        _loadStats();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stationId = _stationUid?.trim();
    if (stationId == null || stationId.isEmpty) return;

    try {
      final stats = await AppApi.stationStats(stationId);
      if (!mounted) return;
      setState(() {
        _pendingCount = (stats['pending_count'] as num?)?.toInt() ?? 0;
        _todayCompleted = (stats['today_completed'] as num?)?.toInt() ?? 0;
        _monthRev = (stats['month_rev'] as num?)?.toDouble() ?? 0.0;
        _lowInventoryCount = (stats['low_inventory_count'] as num?)?.toInt() ?? 0;
        _totalLiters = (stats['total_liters'] as num?)?.toDouble() ?? 0.0;
        _petrolLiters = (stats['petrol_liters'] as num?)?.toDouble() ?? 0.0;
        _dieselLiters = (stats['diesel_liters'] as num?)?.toDouble() ?? 0.0;
        _keroseneLiters = (stats['kerosene_liters'] as num?)?.toDouble() ?? 0.0;
        _lowTanksCount = (stats['low_tanks_count'] as num?)?.toInt() ?? 0;
        _statsLoading = false;
        _statsError = false;
      });
    } on ApiException catch (e) {
      debugPrint('Stats fetch error: $e');
      if (mounted) {
        setState(() {
          _statsLoading = false;
          _statsError = true;
        });
      }
    } catch (e) {
      debugPrint('Stats fetch error: $e');
      if (mounted) {
        setState(() {
          _statsLoading = false;
          _statsError = true;
        });
      }
    }
  }

  Widget _buildStatValue(Widget value) {
    if (_statsError) return _buildErrorWidget();
    if (_statsLoading) return _buildLoadingWidget();
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasStation = _stationUid != null && _stationUid!.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.8,
                ),
                delegate: SliverChildListDelegate([
                  _MiniStatCard(
                    icon: Icons.shopping_cart_outlined,
                    title: "Pending Orders",
                    color: Colors.blue,
                    child: !hasStation
                        ? const Text("—", style: TextStyle(fontSize: 14))
                        : _buildStatValue(
                            Text(
                              '$_pendingCount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                    onTap: widget.onNavigateToPreorders,
                  ),
                  _MiniStatCard(
                    icon: Icons.check_circle_outline_rounded,
                    title: "Today Completed",
                    color: Colors.green,
                    child: !hasStation
                        ? const Text("—", style: TextStyle(fontSize: 14))
                        : _buildStatValue(
                            Text(
                              '$_todayCompleted',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    onTap: null,
                  ),
                  _MiniStatCard(
                    icon: Icons.calendar_month_outlined,
                    title: "This Month",
                    color: Colors.purple,
                    child: !hasStation
                        ? const Text("ETB —", style: TextStyle(fontSize: 13))
                        : _buildStatValue(
                            Text(
                              "ETB ${_monthRev.toStringAsFixed(0)}",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                    onTap: null,
                  ),
                  _MiniStatCard(
                    icon: Icons.warning_amber_outlined,
                    title: "Low Stock",
                    color: Colors.orange,
                    child: !hasStation
                        ? const Text("—", style: TextStyle(fontSize: 14))
                        : _buildStatValue(
                            Text(
                              '$_lowInventoryCount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                    onTap: null,
                  ),
                  _MiniStatCard(
                    icon: Icons.local_gas_station,
                    title: "Total Fuel",
                    color: Colors.teal,
                    child: !hasStation
                        ? const Text("— L", style: TextStyle(fontSize: 13))
                        : _buildStatValue(
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${_totalLiters.toStringAsFixed(0)} L",
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                if (_lowTanksCount > 0)
                                  Text(
                                    "$_lowTanksCount low",
                                    style: const TextStyle(fontSize: 10, color: Colors.red),
                                  ),
                              ],
                            ),
                          ),
                    onTap: null,
                  ),
                  _MiniStatCard(
                    icon: Icons.local_gas_station_outlined,
                    title: "Petrol",
                    color: Colors.blue[800]!,
                    child: !hasStation
                        ? const Text("— L", style: TextStyle(fontSize: 13))
                        : _buildStatValue(
                            Text(
                              "${_petrolLiters.toStringAsFixed(0)} L",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                    onTap: null,
                  ),
                  _MiniStatCard(
                    icon: Icons.local_gas_station_outlined,
                    title: "Diesel",
                    color: Colors.green[800]!,
                    child: !hasStation
                        ? const Text("— L", style: TextStyle(fontSize: 13))
                        : _buildStatValue(
                            Text(
                              "${_dieselLiters.toStringAsFixed(0)} L",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                    onTap: null,
                  ),
                  _MiniStatCard(
                    icon: Icons.local_gas_station_outlined,
                    title: "Kerosene",
                    color: Colors.amber[800]!,
                    child: !hasStation
                        ? const Text("— L", style: TextStyle(fontSize: 13))
                        : _buildStatValue(
                            Text(
                              "${_keroseneLiters.toStringAsFixed(0)} L",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                    onTap: null,
                  ),
                ]),
              ),
            ),
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
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _CompactActionTile(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Pending Orders',
                    subtitle: 'View & confirm waiting orders',
                    color: Colors.blue,
                    onTap: widget.onNavigateToPreorders,
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.checklist_rounded,
                    title: 'Today Completed',
                    subtitle: 'View orders finished today',
                    color: Colors.green[700]!,
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.analytics_outlined,
                    title: 'Sales Reports',
                    subtitle: 'Daily, weekly, monthly',
                    color: Colors.indigo,
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.local_gas_station,
                    title: 'Fuel Inventory',
                    subtitle: 'Tanks, levels & refills',
                    color: Colors.teal,
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Other Inventory',
                    subtitle: 'Lubricants, shop items',
                    color: Colors.orange,
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.business_outlined,
                    title: 'Station Details',
                    subtitle: 'Update name, address, contact',
                    color: Colors.blue[700]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StationManagePage()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CompactActionTile(
                    icon: Icons.settings_outlined,
                    title: 'Station Settings',
                    subtitle: 'Prices, working hours, etc.',
                    color: Colors.grey[700]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StationSettingsPage()),
                    ),
                  ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _buildErrorWidget() {
    return const Text("Error", style: TextStyle(color: Colors.red, fontSize: 16));
  }
}

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
        borderRadius: BorderRadius.circular(10),
        side: isDark ? BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)) : BorderSide.none,
      ),
      color: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.5) : theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            // ── Card layout ──────────────────────────────────────────
            // Row 1: icon  on the LEFT,  label (title) on the RIGHT.
            // Row 2: the number/value BELOW, aligned to the left
            //        (directly under the icon).
            // ──────────────────────────────────────────────────────────
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: icon
                  Icon(icon, size: 18, color: color),
                  // Right: label
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withOpacity(0.75),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Below: the number / value (centered on the card width)
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: child,
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
        side: isDark ? BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)) : BorderSide.none,
      ),
      color: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.5) : theme.colorScheme.surface,
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
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.7)),
          ),
          trailing: Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.5)),
        ),
      ),
    );
  }
}