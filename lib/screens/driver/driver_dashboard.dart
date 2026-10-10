import 'package:flutter/material.dart';

import 'driver_home_page.dart';
import 'driver_station_page.dart';
import 'driver_history_page.dart';
import 'driver_settings_page.dart';
import 'driver_profile_page.dart';
import 'driver_notifications_page.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _selectedIndex = 0;

  int _unreadNotifications = 2;

  // ────────────────────────────────────────────────────────────
  // TABS (only these four): Home → Station → History → Settings
  // The app bar section contains the header icons and the page
  // content always starts BELOW it (no overlap).
  // ────────────────────────────────────────────────────────────
  static const List<Widget> _pages = <Widget>[
    DriverHomePage(),                       // 0 — Home
    DriverStationPage(),                    // 1 — Station
    DriverHistoryPage(),                    // 2 — History
    DriverSettingsPage(showAppBar: false),  // 3 — Settings
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriverProfilePage()),
    );
  }

  void _openNotifications() {
    setState(() => _unreadNotifications = 0);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriverNotificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE3E3E3);

    return Scaffold(
      // ── App bar section: contains the header icons ─────────
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 56,
        titleSpacing: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
        // Left: profile icon.
        leading: IconButton(
          onPressed: _openProfile,
          tooltip: 'Profile',
          icon: const Icon(
            Icons.person_outline,
            color: Color(0xFF1C1C1E),
            size: 26,
          ),
        ),
        // Right: notification icon with unread badge.
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _openNotifications,
              tooltip: 'Notifications',
              icon: Badge.count(
                count: _unreadNotifications,
                isLabelVisible: _unreadNotifications > 0,
                backgroundColor: const Color(0xFFE5484D),
                textColor: Colors.white,
                child: const Icon(
                  Icons.notifications_none,
                  color: Color(0xFF1C1C1E),
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
      // ── Page content always starts BELOW the app bar ───────
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildFloatingNavBar(),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Floating pill bottom navigation (Home / Station / History /
  // Settings). White capsule with soft shadow; the active tab is
  // a filled lime-green circle (#32CD32) with a solid dark icon,
  // inactive tabs are white circles with a thin grey outline.
  // ────────────────────────────────────────────────────────────
  Widget _buildFloatingNavBar() {
    const tabs = [
      _NavTab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
      _NavTab(
        icon: Icons.local_gas_station_outlined,
        activeIcon: Icons.local_gas_station,
        label: 'Station',
      ),
      _NavTab(
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: 'History',
      ),
      _NavTab(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Settings',
      ),
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < tabs.length; i++)
              _FloatingNavItem(
                tab: tabs[i],
                isActive: i == _selectedIndex,
                onTap: () => _onItemTapped(i),
              ),
          ],
        ),
      ),
    );
  }
}

/// Single tab entry — outline icon (inactive) / filled icon (active).
class _NavTab {
  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// One circular icon button inside the floating pill.
class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final _NavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  // Vibrant lime green used for the active tab / CTA accent.
  static const Color _activeGreen = Color(0xFF32CD32);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isActive,
      button: true,
      label: tab.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: isActive ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Active: filled lime green. Inactive: white + thin grey outline.
              color: isActive ? _activeGreen : Colors.white,
              border: isActive
                  ? null
                  : Border.all(color: const Color(0xFFE3E3E3), width: 1),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: _activeGreen.withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isActive ? tab.activeIcon : tab.icon,
              // Active gets a solid dark icon; inactive keeps the outline.
              color: isActive ? Colors.black : const Color(0xFF6B7280),
              size: isActive ? 26 : 23,
            ),
          ),
        ),
      ),
    );
  }
}