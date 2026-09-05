// lib/screens/splash_screen.dart
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
import '../widgets/orbit_mark.dart';

/// Deliberately a single dark scene in both themes.
///
/// A splash is a held moment, not a screen you work in. Keeping it fixed also
/// removes a flash: the app used to build in light theme and then snap to the
/// saved one, which was most visible here. main() now resolves the theme
/// before the first frame, and this screen simply commits to its own palette.
///
/// The photograph that used to sit behind all this is gone. It needed a heavy
/// four-stop scrim to keep the lockup readable, and the two spent the whole
/// animation fighting each other — the hoop read louder than the brand. A
/// still gradient ground gives the mark somewhere quiet to land, and drops a
/// 312 KB image decode out of the launch path.
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
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // The supporting lines follow the mark up rather than arriving with it,
    // so the eye lands on the identity first. OrbitMark owns the mark's own
    // entrance; this controller only drives the type beneath it.
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.42, 1.0, curve: Curves.easeOut),
    );
    _riseAnim = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.42, 1.0, curve: Curves.easeOutCubic),
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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // A warm lift at the bottom only, so the ground has somewhere to
            // go without ever competing with the gold in the mark.
            stops: [0.0, 0.55, 1.0],
            colors: [
              Color(0xFF07070C),
              Color(0xFF0C0B14),
              Color(0xFF16100A),
            ],
          ),
        ),
        child: SafeArea(
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
      ),
    );
  }

  /// Mark, wordmark, tagline and dedication as one stacked lockup.
  ///
  /// The tagline used to be 38px/w900 across two lines, which made it — not
  /// the brand — the loudest thing on screen. With the mark now animating it
  /// is set quiet and on one line, so there is exactly one thing to look at.
  Widget _identity(bool compact) {
    return Column(
      children: [
        // The wordmark rides inside the ring, so the lockup is the real logo
        // rather than a stand-in shape. It only appears once on the screen
        // now — repeating it below the ring would be the same artwork twice.
        //
        // Sized off its diagonal, not its width. The artwork is 3.24:1, so a
        // width W needs roughly 1.05·W of circle for its corners to stay
        // inside the dashes; the ring itself is inset by the orbiting icon,
        // which is why the numbers are not simply half the size.
        //
        // Still the swap point for new artwork — OrbitMark takes whatever
        // sits at the centre, so this one line is the whole change.
        OrbitMark(
          size: compact ? 160 : 196,
          child: HomegrownWordmark(
              width: compact ? 114 : 140, onDark: true),
        ),

        SizedBox(height: compact ? 22 : 30),

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
                'Every Game Counts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _inkSoft,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: compact ? 22 : 30),
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
        ),
      ],
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
