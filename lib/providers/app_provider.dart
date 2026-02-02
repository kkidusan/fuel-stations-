import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  // Make load method public or keep it private but accessible from main
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load theme mode
    final themeIndex = prefs.getInt('theme') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];

    // Load language
    final lang = prefs.getString('lang') ?? 'en';
    _locale = Locale(lang);

    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme', mode.index);
    notifyListeners();
  }

  Future<void> setLanguage(Locale loc) async {
    _locale = loc;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', loc.languageCode);
    notifyListeners();
  }

  // Toggle between light and dark themes
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      // If system mode, check current system brightness
      final Brightness platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _themeMode = platformBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme', _themeMode.index);
    notifyListeners();
  }

  // Reset to default settings
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    _locale = const Locale('en');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme', ThemeMode.system.index);
    await prefs.setString('lang', 'en');
    
    notifyListeners();
  }

  void loadPreferences() {}
}