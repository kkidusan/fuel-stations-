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
import 'station_notifications_page.dart';           // ← added this import

import '../../services/auth_user_service.dart'; // adjust path as needed

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

  // We'll keep this for display — later you can make it dynamic from Firestore stream
  int _notificationCount = 7; // placeholder — in real app → listen to unread count

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
        '/', // ← change to '/login' if that's your actual login route
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

  void _onNotificationPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StationNotificationsPage(),
      ),
    );

    // Optional: you can reset the badge here after viewing
    // setState(() => _notificationCount = 0);
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
                icon: const Icon(Icons.notifications_none_rounded),
                iconSize: 26,
                tooltip: 'Notifications',
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
              onTap: () {
                Navigator.pop(context);
                _pushNewScreen(const StationSettingsPage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.pop(context);
                _pushNewScreen(const StationHelpSupportPage());
              },
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

      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Pre-orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
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