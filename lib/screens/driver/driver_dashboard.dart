import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_user_service.dart';

import 'driver_home_page.dart';
import 'driver_profile_page.dart';
import 'driver_station_page.dart';
import 'driver_history_page.dart';
import 'driver_notifications_page.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _selectedIndex = 0;

  String _email = 'Loading...';
  String _role = 'Loading...';
  bool _isLoading = true;

  int _unreadNotifications = 5; // ← will be replaced with real data later

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final email = await AuthService.getCurrentEmail();
      final role = await AuthService.getUserRole();

      if (!mounted) return;

      setState(() {
        _email = email ?? 'No email';
        _role = role ?? 'unknown';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading driver info: $e');
      if (!mounted) return;

      setState(() {
        _email = 'Error';
        _role = 'Error';
        _isLoading = false;
      });
    }
  }

  static const List<Widget> _pages = <Widget>[
    DriverHomePage(),
    DriverProfilePage(),
    DriverStationPage(),
    DriverHistoryPage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverNotificationsPage(),
      ),
    ).then((_) {
      // Optional: refresh count logic here in real app
      // For now we simulate "viewed → clear badge"
      if (_unreadNotifications > 0) {
        setState(() => _unreadNotifications = 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4.0), // tighter right padding
            child: Badge.count(
              count: _unreadNotifications,
              isLabelVisible: _unreadNotifications > 0,
              smallSize: 12,
              largeSize: 16,
              alignment: Alignment.topRight,
              // ── Key values for tight/modern overlap ──
              offset: const Offset(-8, 4),     // pulls badge left & slightly down
              padding: EdgeInsets.zero,
              backgroundColor: Colors.redAccent.shade700,
              textColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
              child: IconButton(
                icon: Icon(
                  _unreadNotifications > 0
                      ? Icons.notifications
                      : Icons.notifications_outlined,
                  size: 26,
                ),
                tooltip: _unreadNotifications > 0
                    ? '$_unreadNotifications unread'
                    : 'Notifications',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _openNotifications,
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pages[_selectedIndex],
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_gas_station_outlined),
            selectedIcon: Icon(Icons.local_gas_station),
            label: 'Station',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer() {
    final theme = Theme.of(context);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.primary),
            accountName: Text(
              'Driver${_role != 'driver' && _role != 'Loading...' && _role.isNotEmpty ? ' ($_role)' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(_email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.drive_eta_rounded,
                size: 50,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            selected: _selectedIndex == 0,
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedIndex = 0);
            },
          ),
          ListTile(
            leading: Badge.count(
              count: _unreadNotifications,
              isLabelVisible: _unreadNotifications > 0,
              smallSize: 12,
              largeSize: 16,
              alignment: Alignment.topRight,
              // Adjusted for drawer list tile (icon is smaller/larger spacing)
              offset: const Offset(-10, 3),   // ← tight overlap like app bar
              padding: EdgeInsets.zero,
              backgroundColor: Colors.redAccent.shade700,
              textColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
              child: const Icon(Icons.notifications, size: 26),
            ),
            title: const Text('Notifications'),
            onTap: () {
              Navigator.pop(context);
              _openNotifications();
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            selected: _selectedIndex == 1,
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedIndex = 1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_gas_station),
            title: const Text('Find Station'),
            selected: _selectedIndex == 2,
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedIndex = 2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('History'),
            selected: _selectedIndex == 3,
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedIndex = 3);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Available Orders'),
            onTap: () {
              Navigator.pop(context);
              // TODO: push to AvailableOrdersScreen
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Earnings & Payouts'),
            onTap: () {
              Navigator.pop(context);
              // TODO
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              // TODO
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context);
              // TODO
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              await AuthService.clearUserData();

              if (!mounted) return;

              Navigator.pushNamedAndRemoveUntil(
                context,
                '/', // ← your login / splash / auth wrapper route
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}