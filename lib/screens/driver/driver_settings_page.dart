import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/app_provider.dart';

import '../../services/auth_user_service.dart';
import '../auth/auth_wrapper.dart';
import 'driver_profile_page.dart';
import 'driver_help_support_page.dart';

class DriverSettingsPage extends StatelessWidget {
  const DriverSettingsPage({Key? key, this.showAppBar = true})
      : super(key: key);

  /// When this page is embedded as a dashboard tab it must not render its
  /// own AppBar/back button (the dashboard provides both).
  final bool showAppBar;

  Future<void> _openProfile(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriverProfilePage()),
    );
  }

  Future<void> _openHelpSupport(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriverHelpSupportPage()),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
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
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AuthService.signOut();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Consumer<AppProvider>(
        builder: (context, provider, child) {
          return ListView(
            children: [
              // ── Appearance ──────────────────────────────────────────
              _buildSectionHeader('Appearance'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Enable dark theme'),
                      value: provider.themeMode == ThemeMode.dark,
                      onChanged: (value) {
                        provider.setTheme(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                      secondary: const Icon(Icons.dark_mode),
                    ),
                    CheckboxListTile(
                      title: const Text('Follow System Theme'),
                      subtitle: const Text('Match device theme settings'),
                      value: provider.themeMode == ThemeMode.system,
                      onChanged: (bool? value) {
                        if (value == true) {
                          provider.setTheme(ThemeMode.system);
                        } else {
                          provider.setTheme(ThemeMode.light);
                        }
                      },
                      secondary: const Icon(Icons.settings),
                    ),
                  ],
                ),
              ),

              // ── Language ────────────────────────────────────────────
              _buildSectionHeader('Language'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      _buildLanguageOption(
                        context: context,
                        code: 'en',
                        name: 'English',
                        currentCode: provider.locale.languageCode,
                        onTap: () => provider.setLanguage(Locale('en')),
                      ),
                      _buildLanguageOption(
                        context: context,
                        code: 'am',
                        name: 'አማርኛ (Amharic)',
                        currentCode: provider.locale.languageCode,
                        onTap: () => provider.setLanguage(Locale('am')),
                      ),
                      _buildLanguageOption(
                        context: context,
                        code: 'es',
                        name: 'Español (Spanish)',
                        currentCode: provider.locale.languageCode,
                        onTap: () => provider.setLanguage(Locale('es')),
                      ),
                      _buildLanguageOption(
                        context: context,
                        code: 'fr',
                        name: 'Français (French)',
                        currentCode: provider.locale.languageCode,
                        onTap: () => provider.setLanguage(Locale('fr')),
                      ),
                      _buildLanguageOption(
                        context: context,
                        code: 'ar',
                        name: 'العربية (Arabic)',
                        currentCode: provider.locale.languageCode,
                        onTap: () => provider.setLanguage(Locale('ar')),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Account ─────────────────────────────────────────────
              _buildSectionHeader('Account'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline,
                          color: Colors.blue),
                      title: const Text('Profile'),
                      subtitle: const Text('View and edit your driver profile'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openProfile(context),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading:
                          const Icon(Icons.help_outline, color: Colors.green),
                      title: const Text('Help & Support'),
                      subtitle: const Text('Contact support and FAQs'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openHelpSupport(context),
                    ),
                  ],
                ),
              ),

              // ── Reset ───────────────────────────────────────────────
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.restore, color: Colors.blue),
                  title: const Text('Reset to Default Settings'),
                  subtitle: const Text('Reset theme and language to default'),
                  onTap: () {
                    provider.resetToDefaults();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings reset to default'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),

              // ── Logout ──────────────────────────────────────────────
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text('Sign out of your account'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.red),
                  onTap: () => _confirmLogout(context),
                ),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      );

    if (!showAppBar) return content;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: content,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String code,
    required String name,
    required String currentCode,
    required VoidCallback onTap,
  }) {
    final isSelected = currentCode == code;

    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).primaryColor : null,
      ),
      title: Text(name),
      trailing: isSelected
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Selected',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}