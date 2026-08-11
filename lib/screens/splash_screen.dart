// lib/screens/splash_screen.dart
import 'dart:ui' as ui;
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
  late Animation<double> _fadeAnim;
  late Animation<double> _riseAnim;
  late Animation<double> _volcanoRevealAnim;

  bool _showButtons = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    // Volcano silhouette draws in first, grounding the scene.
    _volcanoRevealAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    );
    // Headline fades and rises in shortly after.
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.25, 0.85, curve: Curves.easeOut),
    );
    _riseAnim = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.25, 0.85, curve: Curves.easeOutCubic),
      ),
    );
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
    final prefs = await SharedPreferences.getInstance();
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
  void _onSignIn() => Get.offNamed('/login');

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Mayon Volcano photo (signature background) ────
          // Drop your photo at this path. Falls back to a plain
          // dark gradient if it's missing so layout never breaks.
          // Light blur + mild darken — volcano stays clearly visible.
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
            child: Image.asset(
              'assets/images/mayon_volcano.jpg',
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.12),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (context, error, stackTrace) =>
                  const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF07070C), Color(0xFF1A1200)],
                  ),
                ),
              ),
            ),
          ),
          // ── Scrim for text legibility over the photo ──────
          AnimatedBuilder(
            animation: _volcanoRevealAnim,
            builder: (context, child) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 1.0],
                  colors: [
                    Color.lerp(Colors.transparent, const Color(0xB307070C),
                        _volcanoRevealAnim.value)!,
                    Color.lerp(Colors.transparent, const Color(0x800C0B14),
                        _volcanoRevealAnim.value)!,
                    Color.lerp(Colors.transparent, const Color(0xE01A1200),
                        _volcanoRevealAnim.value)!,
                  ],
                ),
              ),
            ),
          ),
          // ── Content ────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) => Opacity(
                      opacity: _fadeAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, _riseAnim.value),
                        child: child,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'HOMEGROWN',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Every Game\nCounts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            height: 1.14,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 4),
                  // ── Buttons — fade in only for new users ──
                  AnimatedOpacity(
                    opacity: _showButtons ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: AnimatedSlide(
                      offset: _showButtons
                          ? Offset.zero
                          : const Offset(0, 0.08),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      child: IgnorePointer(
                        ignoring: !_showButtons,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
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
                                  text: 'Already have an account? ',
                                  style: TextStyle(
                                      color: Color(0xFF8888AA),
                                      fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text: 'Sign In',
                                      style: TextStyle(
                                        color: AppTheme.accent,
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
        ],
      ),
    );
  }
}