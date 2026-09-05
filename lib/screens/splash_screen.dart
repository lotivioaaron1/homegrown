// lib/screens/splash_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/auth_routing.dart';
import '../utils/onboarding_flag.dart';
import '../widgets/homegrown_wordmark.dart';

/// Deliberately a single dark scene in both themes.
///
/// A splash is a held moment, not a screen you work in, and a photographic
/// background only holds up against dark type. Keeping it fixed also removes
/// a flash: the app used to build in light theme and then snap to the saved
/// one, which was most visible here. main() now resolves the theme before the
/// first frame, and this screen simply commits to its own palette.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _markAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _riseAnim;
  late Animation<double> _scrimAnim;

  bool _showButtons = false;

  // Ink colours for this screen only. The scene is always dark, so these do
  // not come from AppTheme — a theme-aware getter here would produce dark
  // text on a dark photograph in light mode.
  static const _ink = Colors.white;
  static final _inkSoft = Colors.white.withValues(alpha: 0.72);
  static final _inkFaint = Colors.white.withValues(alpha: 0.55);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // The scene darkens first so the mark has something to sit against.
    _scrimAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    // Then Mayon rises from the baseline.
    _markAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.10, 0.70, curve: Curves.easeOutCubic),
    );
    // Wordmark and tagline follow it up.
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
    _riseAnim = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
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
      // A backstop now rather than the only writer. AuthController marks this
      // at registration and at sign-in, which is where it actually becomes
      // true; this line only still matters for accounts that were already
      // signed in when that change shipped and so never passed through it.
      //
      // It is still keyed on a signed-in user, not on the intro finishing:
      // marking it when the intro merely finished stranded anyone who watched
      // it and then abandoned registration, since the CTA below is the only
      // route to /onboarding and they were sent to /login from then on.
      await markOnboardingComplete();
      if (!mounted) return;
      // Where a returning user lands — the super-admin's approval queue, the
      // verification screen, or home — is decided by landingRoute so this
      // cold-start path and AuthController's direct sign-in cannot disagree.
      //
      // reload() refreshes the cached emailVerified flag: someone who verified
      // in their browser since the last launch would otherwise be bounced back
      // to the verification screen on a stale token.
      try {
        await user.reload();
      } catch (_) {
        // Offline or the account was disabled — fall through with the cached
        // flag rather than blocking the launch on a network round trip.
      }
      if (!mounted) return;
      final refreshed = FirebaseAuth.instance.currentUser ?? user;
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(refreshed.uid).get();
      if (!mounted) return;
      Get.offAllNamed(landingRoute(
        role: doc.data()?['role'] as String? ?? '',
        emailVerified: refreshed.emailVerified,
        hasPasswordProvider: hasPasswordProvider(
            refreshed.providerData.map((p) => p.providerId)),
      ));
      return;
    }
    // Not logged in — check if onboarding was done
    final onboardingDone = await isOnboardingComplete();
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
    return Scaffold(
      backgroundColor: const Color(0xFF07070C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _background(),
          _scrim(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _identity(),
                  const Spacer(flex: 4),
                  _actions(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _background() {
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
      child: Image.asset(
        'assets/images/ring.jpg',
        fit: BoxFit.cover,
        color: Colors.black.withValues(alpha: 0.12),
        colorBlendMode: BlendMode.darken,
        // Falls back to a plain dark gradient if the asset is missing so
        // layout never breaks.
        errorBuilder: (context, error, stackTrace) => const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF07070C), Color(0xFF1A1200)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scrim() {
    return AnimatedBuilder(
      animation: _scrimAnim,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Weighted toward the middle, where the mark and wordmark sit.
            // A lighter scrim left the photograph competing with the lockup
            // — the hoop read louder than the brand.
            stops: const [0.0, 0.38, 0.72, 1.0],
            colors: [
              Color.lerp(Colors.transparent, const Color(0xCC07070C),
                  _scrimAnim.value)!,
              Color.lerp(Colors.transparent, const Color(0xE60A0910),
                  _scrimAnim.value)!,
              Color.lerp(Colors.transparent, const Color(0xD90C0B14),
                  _scrimAnim.value)!,
              Color.lerp(Colors.transparent, const Color(0xF01A1200),
                  _scrimAnim.value)!,
            ],
          ),
        ),
      ),
    );
  }

  /// Wordmark, tagline and dedication as one stacked lockup.
  ///
  /// The app name is the hero. A drawn mark sat here previously and read as a
  /// shape rather than an identity; a splash for an app called Homegrown
  /// should lead with the word itself until real artwork exists.
  Widget _identity() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Column(
          children: [
            // The wordmark inherits the entrance the drawn mark used to
            // drive: it rises and settles first, then the supporting lines
            // follow. Always the on-dark variant — this scene is dark in both
            // themes, so the light-background artwork would put black letters
            // on a black photograph.
            Opacity(
              opacity: _markAnim.value,
              child: Transform.translate(
                offset: Offset(0, (1 - _markAnim.value) * 16),
                // 200 wide gives ~62 tall at the stacked 3.24:1 aspect, which
                // sits under the 38px two-line tagline rather than rivalling
                // it. The same width on the old 11:1 artwork was only ~21 tall.
                child: const HomegrownWordmark(width: 200, onDark: true),
              ),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: _fadeAnim.value,
              child: Transform.translate(
                offset: Offset(0, _riseAnim.value),
                child: child,
              ),
            ),
          ],
        );
      },
      child: Column(
        children: [
          // The tagline carries the screen; the wordmark identifies it. Both
          // can be large because the artwork is wide and short — it takes
          // horizontal space, the tagline takes vertical, so they occupy
          // different room instead of competing for the same.
          const Text(
            'Every Game\nCounts.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1.14,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 28),
          // The verse is a dedication, not a headline. Set quieter and
          // narrower than the tagline so the two stop competing — the script
          // face at near-tagline size was the loudest thing on the screen and
          // pulled the eye away from the brand.
          SizedBox(
            width: 240,
            child: Column(
              children: [
                Text(
                  'I can do all things through Christ who strengthens me.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dancingScript(
                    color: _inkSoft,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PHILIPPIANS 4:13',
                  style: TextStyle(
                    color: _inkFaint,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return AnimatedOpacity(
      opacity: _showButtons ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: AnimatedSlide(
        offset: _showButtons ? Offset.zero : const Offset(0, 0.08),
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
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _onSignIn,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account?  ',
                      style: TextStyle(color: _inkSoft, fontSize: 14),
                      children: const [
                        TextSpan(
                          text: 'Sign in',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
