import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/app_provider.dart';

class DriverSettingsPage extends StatelessWidget {
  const DriverSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return ListView(
            children: [
              // Theme Settings Section
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
              
              // Language Settings Section
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
              
              // Reset Section
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
              
              const SizedBox(height: 32),
            ],
          );
        },
      ),
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