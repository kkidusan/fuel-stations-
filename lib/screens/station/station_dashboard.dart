import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'station_home_page.dart';
import 'station_preorders_page.dart';
import 'station_history_page.dart';
import 'station_profile_page.dart';
import 'station_inventory_page.dart';
import 'station_customers_page.dart';
import 'station_settings_page.dart';
import 'station_help_support_page.dart';
import 'station_notifications_page.dart';

import '../../services/auth_user_service.dart';

class StationDashboard extends StatefulWidget {
  const StationDashboard({super.key});

  @override
  State<StationDashboard> createState() => _StationDashboardState();
}

class _StationDashboardState extends State<StationDashboard> {
  // Preserve selected tab across hot-reload
  static int _selectedIndex = 0;

  String _stationName = 'Loading...';
  String _email = 'Loading...';
  bool _isLoading = true;
  bool _isLoggingOut = false;

  // Make notification count mutable so we can update it
  int _notificationCount = 7;

  static const List<Widget> _pages = <Widget>[
    StationHomePage(),
    StationPreordersPage(),
    StationHistoryPage(),
    StationProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadStationInfo();
    // In real app, set up Firestore listener for real-time notifications
  }

  Future<void> _loadStationInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _updateUI('Not signed in', 'Guest');
        return;
      }

      String emailFromAuth = user.email ?? 'No email';
      String nameFromAuth = user.displayName ?? 'Station Owner';

      setState(() {
        _email = emailFromAuth;
        _stationName = nameFromAuth;
      });

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailFromAuth)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        final firestoreName = data['name'] as String?;
        if (firestoreName != null && firestoreName.trim().isNotEmpty) {
          setState(() => _stationName = firestoreName.trim());
        }
      }
    } catch (e) {
      debugPrint('Error loading station info: $e');
      _updateUI('Error', 'Error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateUI(String email, String name) {
    if (!mounted) return;
    setState(() {
      _email = email;
      _stationName = name;
      _isLoading = false;
    });
  }

  void _onItemTapped(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() => _selectedIndex = index);
    }
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();
      await AuthService.clearUserData();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
    } catch (e) {
      debugPrint('Logout failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  void _pushNewScreen(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Future<void> _onNotificationPressed() async {
    // Navigate to notifications page
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StationNotificationsPage(),
      ),
    );
    
    // Update badge count when returning from notifications
    if (mounted) {
      setState(() {
        _notificationCount = 0; // Reset since user viewed notifications
      });
    }
  }

  void _openSettings() {
    Navigator.pop(context); // Close drawer first
    _pushNewScreen(const StationSettingsPage());
  }

  // Add this method for navigating to help & support
  void _openHelpSupport() {
    Navigator.pop(context); // Close drawer first
    _pushNewScreen(const StationHelpSupportPage());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(_selectedIndex)),
        centerTitle: true,
        actions: [
          // Notification badge
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Badge.count(
              count: _notificationCount,
              isLabelVisible: _notificationCount > 0,
              smallSize: 12,
              largeSize: 16,
              alignment: Alignment.topRight,
              offset: const Offset(-7, 4),
              padding: EdgeInsets.zero,
              backgroundColor: Colors.redAccent.shade700,
              textColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.bold,
              ),
              child: IconButton(
                icon: Icon(
                  _notificationCount > 0
                      ? Icons.notifications
                      : Icons.notifications_none_rounded,
                  size: 26,
                ),
                tooltip: _notificationCount > 0
                    ? '$_notificationCount unread notification${_notificationCount > 1 ? 's' : ''}'
                    : 'Notifications',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _onNotificationPressed,
              ),
            ),
          ),
        ],
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: theme.colorScheme.primary),
              accountName: Text(
                _stationName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text(_email),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.local_gas_station_rounded,
                  size: 50,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            _buildDrawerTile(Icons.home, 'Home', 0),
            _buildDrawerTile(Icons.schedule, 'Pre-orders', 1),
            _buildDrawerTile(Icons.history, 'History', 2),
            _buildDrawerTile(Icons.person, 'Profile', 3),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Inventory'),
              onTap: () {
                Navigator.pop(context);
                _pushNewScreen(const StationInventoryPage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('Customers'),
              onTap: () {
                Navigator.pop(context);
                _pushNewScreen(const StationCustomersPage());
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: _openSettings,
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              onTap: _openHelpSupport, // Use the new method
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              enabled: !_isLoggingOut,
              trailing: _isLoggingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : null,
              onTap: _isLoggingOut
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to log out?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Logout',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        await _handleLogout();
                      }
                    },
            ),
          ],
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),

      bottomNavigationBar: _buildModernBottomNavBar(),
    );
  }

  Widget _buildModernBottomNavBar() {
    final List<BottomTab> tabs = [
      BottomTab(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
      BottomTab(icon: Icons.schedule_outlined, selectedIcon: Icons.schedule, label: 'Pre-orders'),
      BottomTab(icon: Icons.history_outlined, selectedIcon: Icons.history, label: 'History'),
      BottomTab(icon: Icons.person_outlined, selectedIcon: Icons.person, label: 'Profile'),
    ];

    return Container(
      margin: EdgeInsets.zero,
      height: 90,
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(
          top: BorderSide(color: const Color(0xFF256af4).withAlpha(51)),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF256af4).withAlpha(26),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isActive = index == _selectedIndex;

          return GestureDetector(
            onTap: () => _onItemTapped(index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              padding: EdgeInsets.symmetric(
                horizontal: isActive ? 20 : 12,
                vertical: 10,
              ),
              decoration: isActive
                  ? BoxDecoration(
                      color: const Color(0xFF256af4).withAlpha(51),
                      borderRadius: BorderRadius.circular(30),
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? tab.selectedIcon : tab.icon,
                    color: isActive
                        ? const Color(0xFF256af4)
                        : Colors.grey[500],
                    size: 24,
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    Text(
                      tab.label,
                      style: const TextStyle(
                        color: Color(0xFF256af4),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  ListTile _buildDrawerTile(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: _selectedIndex == index,
      selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
      onTap: () {
        Navigator.pop(context);
        _onItemTapped(index);
      },
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Station Dashboard';
      case 1:
        return 'Pre-orders';
      case 2:
        return 'History';
      case 3:
        return 'Profile';
      default:
        return 'Station';
    }
  }
}

class BottomTab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  BottomTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}