import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_user_service.dart'; // ← corrected import (use the real file name)

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;

  String _email = 'Loading...';
  String _role = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      // Prefer the newer/cleaner method if you updated AuthService
      final role = await AuthService.getUserRole();
      final email = await AuthService.getCurrentEmail();

      if (mounted) {
        setState(() {
          _email = email;
          _role = role;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');

      if (mounted) {
        setState(() {
          _email = 'Error';
          _role = 'Error';
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPageContent() {
    switch (_selectedIndex) {
      case 0: // Home
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_gas_station_rounded,
                  size: 90,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 32),
                Text(
                  'Welcome, Passenger!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Find nearby fuel stations\nOrder fuel delivery\nTrack your orders',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        );

      case 1: // Notifications
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Notifications\n• Order updates\n• Promotions & discounts\n• Station alerts',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ),
        );

      case 2: // Profile
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Your Profile\n• Personal information\n• Order history\n• Payment methods',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passenger Dashboard'),
        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildPageContent(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
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

  Drawer _buildDrawer() {
    final theme = Theme.of(context);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.primary),
            accountName: Text(
              'Passenger${_role != 'user' && _role != 'Loading...' && _role.isNotEmpty ? ' ($_role)' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(_email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person_rounded,
                size: 50,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          // Main navigation
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
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            selected: _selectedIndex == 1,
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedIndex = 1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            selected: _selectedIndex == 2,
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedIndex = 2);
            },
          ),

          const Divider(),

          // Additional features (placeholders)
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Order History'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigator.push(context, MaterialPageRoute(builder: (_) => OrderHistoryScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.payment),
            title: const Text('Payment Methods'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigator.push(...)
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Settings screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Help screen
            },
          ),

          const Divider(),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              await AuthService.clearUserData();

              if (context.mounted) {
                // Better: use pushReplacementNamed if you have named routes
                // or pushAndRemoveUntil if not
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/', // ← assuming '/' is your AuthWrapper / Splash / Login route
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}