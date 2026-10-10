import 'package:flutter/material.dart';

import 'station_home_page.dart';
import 'station_preorders_page.dart';
import 'station_history_page.dart';
import 'station_settings_page.dart';
import 'station_profile_page.dart';
import 'station_notifications_page.dart';

class StationDashboard extends StatefulWidget {
  const StationDashboard({super.key});

  @override
  State<StationDashboard> createState() => _StationDashboardState();
}

class _StationDashboardState extends State<StationDashboard> {
  int _selectedIndex = 0;

  int _notificationCount = 3;

  // ────────────────────────────────────────────────────────────
  // TABS (only these four): Home → Pre-Order → History → Settings
  // No drawer — the app bar (profile + notification) + the
  // floating pill navigation replace it, just like the driver app.
  // ────────────────────────────────────────────────────────────
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      StationHomePage(onNavigateToPreorders: _switchToPreorders),
      const StationPreordersPage(),
      const StationHistoryPage(),
      const StationSettingsPage(showAppBar: false),
    ];
  }

  void _switchToPreorders() {
    setState(() => _selectedIndex = 1);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StationProfilePage()),
    );
  }

  void _openNotifications() {
    setState(() => _notificationCount = 0);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StationNotificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE3E3E3);

    return Scaffold(
      // ── App bar section (header): profile + notification ──
      // Both icons get their OWN circle border, matching the floating
      // bottom-tab items (white circle + thin grey outline).
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        leadingWidth: 66,
        titleSpacing: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
        // Left: profile icon in its own circle (opens Station Profile).
        leading: Center(
          child: _HeaderCircleButton(
            icon: Icons.person_outline,
            tooltip: 'Profile',
            onPressed: _openProfile,
          ),
        ),
        // Right: notification icon in its own circle, with an unread badge.
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _HeaderCircleButton(
              icon: Icons.notifications_none,
              tooltip: 'Notifications',
              badgeCount: _notificationCount,
              onPressed: _openNotifications,
            ),
          ),
        ],
      ),
      // ── Page content always starts BELOW the app bar ───────
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildFloatingNavBar(),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Floating pill bottom navigation (Home / Pre-Order / History /
  // Settings). White capsule with soft shadow; the active tab is
  // a filled lime-green circle (#32CD32) with a solid dark icon,
  // inactive tabs are white circles with a thin grey outline.
  // ────────────────────────────────────────────────────────────
  Widget _buildFloatingNavBar() {
    const tabs = [
      _NavTab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
      _NavTab(
        icon: Icons.schedule_outlined,
        activeIcon: Icons.schedule,
        label: 'Pre-Order',
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

/// Circular header icon button (profile / notifications).
///
/// Mirrors the look of the floating bottom-tab items: a white circle with
/// a thin grey outline and the icon centered inside. An optional red badge
/// shows an unread count.
class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final int badgeCount;

  /// Diameter of the circle.
  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE3E3E3);
    final iconColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

    final iconWidget = Icon(icon, color: iconColor, size: _size * 0.55);

    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Center(
              child: badgeCount > 0
                  ? Badge.count(
                      count: badgeCount,
                      isLabelVisible: true,
                      backgroundColor: const Color(0xFFE5484D),
                      textColor: Colors.white,
                      offset: const Offset(6, -6),
                      child: iconWidget,
                    )
                  : iconWidget,
            ),
          ),
        ),
      ),
    );
  }
}