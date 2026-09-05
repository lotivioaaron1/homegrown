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
import '../widgets/fill_viewport_scroll.dart';
import '../widgets/homegrown_wordmark.dart';

/// Deliberately a single dark scene in both themes.
///
/// A splash is a held moment, not a screen you work in, and a photographic
/// background only holds up against dark type. Keeping it fixed also removes a
/// flash: the app used to build in light theme and then snap to the saved one,
/// which was most visible here. main() now resolves the theme before the first
/// frame, and this screen simply commits to its own palette.
///
/// A version of this screen briefly replaced the photograph with a flat
/// gradient and put the wordmark inside an orbiting ring. It is back to the
/// photograph by preference — the argument for the gradient was that the scrim
/// and the picture fought each other, and that was not the trade wanted.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scrimAnim;
  late Animation<double> _markAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _riseAnim;

  bool _showButtons = false;
  bool _launched = false;

  /// How long the brand moment is held before routing.
  ///
  /// The auth work runs underneath it rather than after it, so this is the
  /// floor on a cold start, not an addition to one. It used to be a flat
  /// 2500ms that only *then* began talking to Firebase, which made the real
  /// wait 2.5s plus a network round trip, with ~700ms of dead air in the
  /// middle where the animation had finished and nothing was happening.
  static const _kMinHold = Duration(milliseconds: 1800);

  // Ink colours for this screen only. The scene is always dark, so these do
  // not come from AppTheme — a theme-aware getter here would produce dark
  // text on a dark ground in light mode.
  static final _inkSoft = Colors.white.withValues(alpha: 0.72);
  static final _inkFaint = Colors.white.withValues(alpha: 0.55);

  @override
  void initState() {
    super.initState();
    // Lands a little before _kMinHold so the screen settles for a beat before
    // routing rather than cutting away on the animation's last frame. The
    // original ran 1800ms against a flat 2500ms delay, which gave it the same
    // pause by accident.
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // The scene darkens first so the mark has something to sit against.
    _scrimAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    // Then the wordmark rises into it.
    _markAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.10, 0.70, curve: Curves.easeOutCubic),
    );
    // Tagline and verse follow it up, so the eye lands on the identity first.
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_launched) return;
    _launched = true;

    if (MediaQuery.of(context).disableAnimations) {
      _animController.value = 1.0;
    } else {
      _animController.forward();
    }
    _startLaunch();
  }

  // ── Launch ────────────────────────────────────

  /// Holds the splash for [_kMinHold] while resolving where to go, then goes.
  ///
  /// The two run concurrently: on a fast connection the hold is what you wait
  /// for, and on a slow one the animation keeps moving instead of freezing.
  Future<void> _startLaunch() async {
    String? destination;
    try {
      final results = await Future.wait<String?>([
        _resolveDestination(),
        Future<String?>.delayed(_kMinHold, () => null),
      ]);
      destination = results.first;
    } catch (_) {
      // Nothing below the CTA is safe to assume if this failed outright, and
      // stranding someone on a splash forever is the worst outcome available.
      destination = null;
    }

    if (!mounted) return;
    if (destination == null) {
      setState(() => _showButtons = true);
    } else {
      Get.offAllNamed(destination);
    }
  }

  /// Where this launch should land, or null to show the Get Started CTA.
  Future<String?> _resolveDestination() async {
    final user = await _restoredUser();

    if (user != null) {
      // A backstop now rather than the only writer. AuthController marks this
      // at registration and at sign-in, which is where it actually becomes
      // true; this only still matters for accounts that were already signed in
      // when that change shipped and so never passed through it.
      await markOnboardingComplete();

      // reload() refreshes the cached emailVerified flag: someone who verified
      // in their browser since the last launch would otherwise be bounced back
      // to the verification screen on a stale token.
      try {
        await user.reload();
      } catch (_) {
        // Offline or the account was disabled — fall through with the cached
        // flag rather than blocking the launch on a network round trip.
      }
      final refreshed = FirebaseAuth.instance.currentUser ?? user;

      String role = '';
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshed.uid)
            .get();
        role = doc.data()?['role'] as String? ?? '';
      } catch (_) {
        // Same reasoning: an unreachable Firestore should not pin a signed-in
        // user to the splash. landingRoute sends a roleless account to /home
        // or /verify-email, both of which can recover on their own.
      }

      // Where a returning user lands is decided by landingRoute so this
      // cold-start path and AuthController's direct sign-in cannot disagree.
      return landingRoute(
        role: role,
        emailVerified: refreshed.emailVerified,
        hasPasswordProvider: hasPasswordProvider(
            refreshed.providerData.map((p) => p.providerId)),
      );
    }

    // Not signed in: someone who has had an account on this device goes to
    // login, everyone else gets the intro.
    return await isOnboardingComplete() ? '/login' : null;
  }

  /// The signed-in user, giving Firebase a moment to restore one from disk.
  ///
  /// `currentUser` is usually populated by the time `Firebase.initializeApp`
  /// returns, but it is not promised to be: the SDK can still be reading the
  /// persisted session, and until it finishes the getter answers null. The old
  /// flat 2500ms delay hid that entirely by never asking until long after
  /// startup. Asking immediately does not, and the failure it would produce —
  /// a signed-in user dropped on the login screen — is much worse than a short
  /// wait.
  ///
  /// Costs nothing in practice. The common case returns without awaiting at
  /// all, and even the slow path runs underneath the minimum hold rather than
  /// after it. The timeout is what distinguishes "not restored yet" from
  /// "genuinely signed out", since authStateChanges never closes on its own.
  Future<User?> _restoredUser() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return current;

    return FirebaseAuth.instance
        .authStateChanges()
        .firstWhere((u) => u != null)
        .timeout(const Duration(milliseconds: 1200), onTimeout: () => null);
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
    final compact = MediaQuery.sizeOf(context).height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF07070C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _background(),
          _scrim(),
          SafeArea(
            // Scrolls rather than overflows once the lockup outgrows the
            // viewport, which it does at the largest system text sizes. The
            // Spacers still do their job while it fits — that is the whole
            // reason this widget exists rather than a plain scroll view.
            child: FillViewportScroll(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _identity(compact),
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
            // Weighted toward the middle, where the wordmark and tagline sit.
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
  /// The app name is the hero and the tagline carries the screen. Both can be
  /// large because the artwork is wide and short — it takes horizontal space,
  /// the tagline takes vertical, so they occupy different room instead of
  /// competing for the same.
  Widget _identity(bool compact) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Column(
          children: [
            // The wordmark rises and settles first, then the supporting lines
            // follow. Always the on-dark variant — this scene is dark in both
            // themes, so the light-background artwork would put black letters
            // on a dark photograph.
            Opacity(
              opacity: _markAnim.value,
              child: Transform.translate(
                offset: Offset(0, (1 - _markAnim.value) * 16),
                child:
                    HomegrownWordmark(width: compact ? 172 : 200, onDark: true),
              ),
            ),
            SizedBox(height: compact ? 12 : 16),
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
          Text(
            'Every Game\nCounts.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 32 : 38,
              fontWeight: FontWeight.w900,
              height: 1.14,
              letterSpacing: -1.0,
            ),
          ),
          SizedBox(height: compact ? 22 : 28),
          // The verse is a dedication, not a headline — narrower and
          // quieter than everything above it.
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
