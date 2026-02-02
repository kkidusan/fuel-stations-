import 'package:flutter/material.dart';

import 'en.dart';
import 'am.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Map<String, String> get _current => locale.languageCode == 'am' ? am : en;

  // ──────────────────────────────────────────────────────────────────────────
  // General / App wide
  // ──────────────────────────────────────────────────────────────────────────
  String get appName          => _current['appName'] ?? 'Gas Station ET';
  String get welcome          => _current['welcome'] ?? 'Welcome';
  String get welcomeBack      => _current['welcomeBack'] ?? 'Welcome back';
  String get home             => _current['home'] ?? 'Home';
  String get profile          => _current['profile'] ?? 'Profile';
  String get darkMode         => _current['darkMode'] ?? 'Dark Mode';
  String get language         => _current['language'] ?? 'Language';
  String get logout           => _current['logout'] ?? 'Logout';

  // ──────────────────────────────────────────────────────────────────────────
  // Auth related
  // ──────────────────────────────────────────────────────────────────────────
  String get login            => _current['login'] ?? 'Login';
  String get signUp           => _current['signUp'] ?? 'Sign Up';
  String get email            => _current['email'] ?? 'Email';
  String get password         => _current['password'] ?? 'Password';
  String get confirmPassword  => _current['confirmPassword'] ?? 'Confirm Password';
  String get alreadyHave      => _current['alreadyHaveAccount'] ?? 'Already have an account? Login';
  String get dontHaveAccount  => _current['dontHaveAccount'] ?? "Don't have an account?";
  String get forgotPassword   => _current['forgotPassword'] ?? 'Forgot password?';
  String get loading => _current['loading'] ?? 'Loading...';
  
  String get selectYourRole      => _current['selectYourRole'] ?? 'Select your role';
  String get passwordsDoNotMatch => _current['passwordsDoNotMatch'] ?? 'Passwords do not match';
  String get pleaseSelectRole    => _current['pleaseSelectRole'] ?? 'Please select a role';
  String get getStarted          => _current['getStarted'] ?? 'Get Started';
  String get findNearbyStations  => _current['findNearbyStations'] ?? 'Find nearby gas stations in Ethiopia easily';
  String get authenticationError => _current['authenticationError'] ?? 'Authentication error';
  String get firestoreError       => _current['firestoreError'] ?? 'Firestore error';
  String get unexpectedError      => _current['unexpectedError'] ?? 'An unexpected error occurred';
  
  String get loginSuccessful         => _current['loginSuccessful'] ?? 'Login successful!';
  String get pleaseFillAllFields     => _current['pleaseFillAllFields'] ?? 'Please fill in all fields';
  String get userNotFound            => _current['userNotFound'] ?? 'No account found with this email.';
  String get wrongPassword           => _current['wrongPassword'] ?? 'Incorrect password.';
  String get invalidEmail            => _current['invalidEmail'] ?? 'Invalid email format.';
  String get accountDisabled         => _current['accountDisabled'] ?? 'This account has been disabled.';
  String get forgotPasswordComingSoon => _current['forgotPasswordComingSoon'] ?? 'Forgot password feature coming soon';
  // ──────────────────────────────────────────────────────────────────────────
  // Other screens / features (you can expand later)
  // ──────────────────────────────────────────────────────────────────────────
  String get noAccount        => _current['noAccount'] ?? "Don't have an account? Sign Up";
  String get enjoyYourRide    => _current['enjoyYourRide'] ?? 'Enjoy your ride!';
  String get waitingForDriver => _current['waitingForDriver'] ?? 'Waiting for a driver...';
  String get rideNotFound     => _current['rideNotFound'] ?? 'Ride not found';
  String get goOffline        => _current['goOffline'] ?? 'Go Offline';
  String get lookingForNearby => _current['lookingForNearby'] ?? 'Looking for nearby stations...';

  String? get pleaseEnterEmail => null;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'am'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}