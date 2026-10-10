import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'screens/splash_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('╔════════════════════════════════════════════╗');
  print('║          Gas Station ET - Starting         ║');
  print('╚════════════════════════════════════════════╝');

  // 1. Environment (.env → API_BASE_URL for the Next.js backend)
  try {
    await dotenv.load(fileName: '.env');
    print('✓ .env loaded (API_BASE_URL=${dotenv.env['API_BASE_URL']})');
  } catch (e) {
    print('✗ Failed to load .env: $e');
    print('  → Using default API_BASE_URL (http://10.0.2.2:4000)');
  }

  // 2. Backend (Next.js + Prisma → Supabase) is reached lazily via
  //    lib/services/api_client.dart — nothing to initialise here.

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider = AppProvider();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          provider.loadPreferences();
        });
        return provider;
      },
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: 'Gas Station ET',
            debugShowCheckedModeBanner: false,

            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('am'),
              Locale('es'),
              Locale('fr'),
              Locale('ar'),
            ],
            locale: provider.locale,

            theme: ThemeData(
              useMaterial3: true,
              // Vibrant lime green (#32CD32) — CTA/accent color.
              colorSchemeSeed: const Color(0xFF32CD32),
              brightness: Brightness.light,
              // Clean, very light mint-green app background (defines the
              // entire app's aesthetic).
              scaffoldBackgroundColor: const Color(0xFFF0F8F4),
              appBarTheme: const AppBarTheme(
                elevation: 0,
                centerTitle: true,
                backgroundColor: Color(0xFFF0F8F4),
                foregroundColor: Color(0xFF1C1C1E),
                titleTextStyle: TextStyle(
                  color: Color(0xFF1C1C1E),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                iconTheme: IconThemeData(color: Color(0xFF1C1C1E)),
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Colors.white,
                selectedItemColor: Color(0xFF1C1C1E),
                unselectedItemColor: Colors.grey,
                elevation: 8,
              ),
              cardTheme: CardThemeData(
                elevation: 1,
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              textTheme: const TextTheme(
                titleLarge: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E),
                ),
                titleMedium: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E),
                ),
                bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF1C1C1E)),
                bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF4A4A4A)),
                bodySmall: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                labelLarge: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF32CD32),
              brightness: Brightness.dark,
              // Dark green-tinted background for dark mode.
              scaffoldBackgroundColor: const Color(0xFF0C110E),
              appBarTheme: const AppBarTheme(
                elevation: 0,
                centerTitle: true,
                backgroundColor: Color(0xFF0C110E),
                foregroundColor: Colors.white,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                iconTheme: IconThemeData(color: Colors.white),
              ),
              cardTheme: CardThemeData(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: const Color(0xFF16201A),
                surfaceTintColor: Colors.transparent,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Color(0xFF16201A),
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.grey,
                elevation: 8,
              ),
              textTheme: const TextTheme(
                titleLarge: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                titleMedium: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
                bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFB8C0BB)),
                bodySmall: TextStyle(fontSize: 12, color: Color(0xFF8A938E)),
                labelLarge: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            themeMode: provider.themeMode,

            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}