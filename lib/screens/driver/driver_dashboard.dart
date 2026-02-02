import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_user_service.dart';

import 'driver_home_page.dart';
import 'driver_profile_page.dart';
import 'driver_station_page.dart';
import 'driver_history_page.dart';
import 'driver_notifications_page.dart';
import 'driver_settings_page.dart';
import 'driver_help_support_page.dart'; // Add this import

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

  // This will be updated when notifications are marked as read
  int _unreadNotifications = 5;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    // In real app, you might set up a Firestore listener here
    // to get real-time notification count
  }

  Future<void> _loadUserInfo() async {
    try {
      final email = await AuthService.getCurrentEmail();
      final role = await AuthService.getUserRole();

      if (!mounted) return;

      setState(() {
        _email = email;
        _role = role;
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

  void _openNotifications() async {
    // Navigate to notifications page and wait for result
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverNotificationsPage(),
      ),
    );
    
    // When returning from notifications page, update the badge count
    // In real app, fetch actual unread count from database
    if (mounted) {
      setState(() {
        // Simulate reading notifications
        _unreadNotifications = 0; // Reset to 0 since user viewed notifications
      });
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverSettingsPage(),
      ),
    );
  }

  // Add this method for navigating to help & support
  void _openHelpSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverHelpSupportPage(),
      ),
    );
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
            padding: const EdgeInsets.only(right: 4.0),
            child: Badge.count(
              count: _unreadNotifications,
              isLabelVisible: _unreadNotifications > 0,
              smallSize: 12,
              largeSize: 16,
              alignment: Alignment.topRight,
              offset: const Offset(-8, 4),
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
                    ? '$_unreadNotifications unread notification${_unreadNotifications > 1 ? 's' : ''}'
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
      bottomNavigationBar: _buildModernBottomNavBar(),
    );
  }

  Widget _buildModernBottomNavBar() {
    final List<BottomTab> tabs = [
      BottomTab(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
      BottomTab(icon: Icons.person_outlined, selectedIcon: Icons.person, label: 'Profile'),
      BottomTab(icon: Icons.local_gas_station_outlined, selectedIcon: Icons.local_gas_station, label: 'Station'),
      BottomTab(icon: Icons.history_outlined, selectedIcon: Icons.history, label: 'History'),
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
              offset: const Offset(-10, 3),
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
            subtitle: _unreadNotifications > 0 
                ? Text('$_unreadNotifications unread')
                : null,
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
             
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Earnings & Payouts'),
            onTap: () {
              Navigator.pop(context);
               
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              _openSettings();
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context);
              _openHelpSupport(); // Use the new method
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
                '/',
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
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