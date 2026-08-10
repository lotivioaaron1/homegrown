// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _scaleAnim;

  bool _showButtons = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _animController, curve: const Interval(0.0, 0.6,
          curve: Curves.easeOut)),
    );

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
          parent: _animController, curve: const Interval(0.0, 0.7,
          curve: Curves.easeOutCubic)),
    );

    // Start animation then wait a minimum display time
    _animController.forward();

    // Always wait 2.5s total before routing — user always sees splash
    Future.delayed(const Duration(milliseconds: 2500), _checkAuthState);
  }

  // ── Auth check ────────────────────────────────

  Future<void> _checkAuthState() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Already logged in → straight to home
      Get.offAllNamed('/home');
      return;
    }

    // Not logged in — check if onboarding was done
    final prefs          = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;

    if (!mounted) return;

    if (onboardingDone) {
      // Returning user who logged out → login screen
      Get.offAllNamed('/login');
    } else {
      // Brand new user → show buttons
      setState(() => _showButtons = true);
    }
  }

  void _onGetStarted() => Get.offNamed('/onboarding');
  void _onSignIn()     => Get.offNamed('/login');

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width:  double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            stops:  [0.0, 0.45, 1.0],
            colors: [
              Color(0xFF1A1200),
              Color(0xFF0F0F1A),
              Color(0xFF080810),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) => Opacity(
              opacity: _fadeAnim.value,
              child:   Transform.scale(
                scale: _scaleAnim.value,
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── Logo ──────────────────────
                  Container(
                    width:  88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                        colors: [AppTheme.accent, AppTheme.accent2],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color:        AppTheme.accent.withValues(alpha: 0.4),
                          blurRadius:   32,
                          spreadRadius: 0,
                          offset:       const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'HG',
                        style: TextStyle(
                          color:      AppTheme.buttonFg,
                          fontSize:   32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Sport icons ───────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ['🏀', '🏐', '🏸'].map((sport) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width:  52,
                        height: 52,
                        decoration: BoxDecoration(
                          color:        const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF2A2A3E)),
                        ),
                        child: Center(
                          child: Text(sport,
                              style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 36),

                  // ── Tagline ───────────────────
                  const Text(
                    'Every Game\nCounts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:         Colors.white,
                      fontSize:      36,
                      fontWeight:    FontWeight.w900,
                      height:        1.15,
                      letterSpacing: -0.8,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Spacer(flex: 2),

                  // ── Dot decoration ────────────
                  const SizedBox(height: 24),

                  // ── Buttons — fade in only for new users ──
                  AnimatedOpacity(
                    opacity:  _showButtons ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: AnimatedSlide(
                      offset:   _showButtons
                          ? Offset.zero
                          : const Offset(0, 0.08),
                      duration: const Duration(milliseconds: 400),
                      curve:    Curves.easeOut,
                      child: IgnorePointer(
                        ignoring: !_showButtons,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width:  double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _onGetStarted,
                                child: const Text('Get Started'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _onSignIn,
                              child: RichText(
                                text: const TextSpan(
                                  text:  'Already have an account? ',
                                  style: TextStyle(
                                      color:    Color(0xFF8888AA),
                                      fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text:  'Sign In',
                                      style: TextStyle(
                                        color:      AppTheme.accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}