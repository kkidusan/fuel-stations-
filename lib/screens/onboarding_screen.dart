import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../l10n/app_localizations.dart';
import 'auth/login_screen.dart'; // adjust path if needed

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // ────────────────────────────────────────────────────────────
  // Brand palette — matches the driver dashboard design system:
  //   mint background, lime-green CTAs, dark-gray text/icons.
  // ────────────────────────────────────────────────────────────
  static const Color _mint = Color(0xFFF0F8F4); // app background
  static const Color _lime = Color(0xFF32CD32); // CTA / accent
  static const Color _ink = Color(0xFF1C1C1E); // titles / icons
  static const Color _bodyGrey = Color(0xFF4A4A4A); // body text
  static const Color _softGrey = Color(0xFF6B6B6B); // secondary text

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      lottieAsset: 'assets/lottie/lo.json', // location / nearby
      title: 'Find Nearby Fuel Stations',
      description:
          'Discover the closest stations instantly with real-time fuel prices and availability — anywhere, anytime.',
    ),
    _OnboardingPage(
      lottieAsset: 'assets/lottie/qr.json', // QR code / scanning
      title: 'Order Faster with QR Code',
      description:
          'Scan QR codes at the station to order fuel, join queues digitally, and reduce waiting time dramatically.',
    ),
    _OnboardingPage(
      lottieAsset: 'assets/lottie/fl.json', // fuel / queue
      title: 'Skip Queues & Reserve Spot',
      description:
          'Reserve your place in line, pay smartly, and get served faster — modern fuel experience at your fingertips.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _mint,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle lime-tinted glow (keeps the mint background base).
            Positioned(
              top: -120,
              right: -120,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _lime.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -120,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _lime.withValues(alpha: 0.05),
                ),
              ),
            ),

            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      return _buildModernPage(_pages[index], loc);
                    },
                  ),
                ),

                // Bottom section
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Column(
                    children: [
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: _pages.length,
                        effect: const ExpandingDotsEffect(
                          dotHeight: 10,
                          dotWidth: 10,
                          spacing: 14,
                          expansionFactor: 4,
                          activeDotColor: _lime,
                          dotColor: Color(0x4032CD32), // lime at 25%
                        ),
                      ),
                      const SizedBox(height: 40),

                      if (_currentPage == _pages.length - 1)
                        _buildGetStartedButton(loc)
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _finishOnboarding,
                              style: TextButton.styleFrom(
                                foregroundColor: _softGrey,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text(
                                'Skip',
                                style: TextStyle(fontSize: 17),
                              ),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _lime,
                                foregroundColor: _ink,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 44,
                                  vertical: 18,
                                ),
                              ),
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeInOutCubic,
                                );
                              },
                              child: const Text(
                                'Next',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPage(_OnboardingPage page, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // White circular card behind the animation — matches the
          // pill / card look of the driver dashboard.
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: _lime.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: SizedBox(
                height: 290,
                width: 290,
                child: Lottie.asset(
                  page.lottieAsset,
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                ),
              ),
            ),
          ),

          const SizedBox(height: 44),

          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 800),
            child: Text(
              page.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _ink,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 18),

          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 1100),
            child: Text(
              page.description,
              style: const TextStyle(
                fontSize: 16,
                color: _bodyGrey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGetStartedButton(AppLocalizations loc) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: _lime,
        foregroundColor: _ink,
        minimumSize: const Size.fromHeight(62),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        elevation: 6,
        shadowColor: _lime.withValues(alpha: 0.40),
      ),
      onPressed: _finishOnboarding,
      child: Text(
        loc.getStarted,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _OnboardingPage {
  final String lottieAsset;
  final String title;
  final String description;

  _OnboardingPage({
    required this.lottieAsset,
    required this.title,
    required this.description,
  });
}