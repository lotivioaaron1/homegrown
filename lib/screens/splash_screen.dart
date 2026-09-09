// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../theme/app_theme.dart';
import '../utils/auth_routing.dart';
import '../utils/onboarding_flag.dart';
import '../widgets/fill_viewport_scroll.dart';
import '../widgets/homegrown_wordmark.dart';

/// Deliberately a single dark scene in both themes.
///
/// A splash is a held moment, not a screen you work in, and committing to one
/// palette also removes a flash: the app used to build in light theme and then
/// snap to the saved one, which was most visible here. main() now resolves the
/// theme before the first frame, and this screen simply ignores it.
///
/// The scene is a flat [_kInk] ground. Two earlier versions are worth knowing
/// about before reaching for something richer: a blurred photograph behind a
/// gradient scrim, and before that a flat gradient with the wordmark inside an
/// orbiting ring. Both were replaced on the same complaint — the background
/// competed with the lockup — and the ground is now the same near-black as the
/// Android launch screen and the adaptive icon's plate, so the OS hands over to
/// Flutter with nothing changing colour.
///
/// The reveal is staged rather than simultaneous: half a second of nothing,
/// then the wordmark, then the tagline, then a progress rail. The empty beat is
/// load-bearing — it is what makes the wordmark read as arriving instead of
/// having always been there.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// The intro's stagger: black hold, wordmark, tagline, rail.
  late AnimationController _introController;
  late Animation<double> _markAnim;
  late Animation<double> _taglineAnim;
  late Animation<double> _taglineRise;
  late Animation<double> _railAnim;

  /// The progress rail's value, 0..1. Separate from [_introController] because
  /// it is not purely time-driven — see [_startLaunch].
  late AnimationController _progress;

  bool _showButtons = false;
  bool _launched = false;
  bool _reducedMotion = false;

  // ── Timing ────────────────────────────────────
  //
  // The stagger is expressed as milliseconds from Flutter's first frame and the
  // Interval fractions below are divided out of _kIntroMs, because an Interval
  // written as 0.575 tells you nothing about when it happens. Const int
  // division yields a const double, so this costs nothing at runtime.

  /// Length of the staged intro. Interval fractions are relative to this.
  static const _kIntroMs = 2000;
  static const _kIntro = Duration(milliseconds: _kIntroMs);

  /// Nothing is painted before this. The whole point of the change.
  static const _kBlackHold = 500;
  static const _kMarkEnd = 1150;

  /// Starts 50ms before the wordmark lands — see the note in [initState].
  static const _kTaglineStart = 1100;
  static const _kTaglineEnd = 1750;

  static const _kRailFadeStart = 1300;
  static const _kRailFadeEnd = 1700;

  /// How long the brand moment is held before routing.
  ///
  /// The auth work runs underneath it rather than after it, so this is the
  /// floor on a cold start, not an addition to one. It used to be a flat
  /// 2500ms that only *then* began talking to Firebase, which made the real
  /// wait 2.5s plus a network round trip, with ~700ms of dead air in the
  /// middle where the animation had finished and nothing was happening.
  ///
  /// 2200ms is where the rail reaches 90%; the completion sweep and its beat
  /// bring the real floor to about 2.58s, near where the flat delay had it.
  static const _kMinHold = Duration(milliseconds: 2200);

  /// When the rail starts moving — tied to the moment it starts fading in, so
  /// the two cannot drift apart.
  static const _kRailStart = Duration(milliseconds: _kRailFadeStart);

  /// The rail's unhurried stretch, and where it stops to wait.
  static const _kRailRun = Duration(milliseconds: 900);
  static const _kRailRest = 0.90;

  /// The completion sweep once the destination is known, and the beat after it
  /// so the screen does not cut away on the rail's last frame.
  static const _kRailFinish = Duration(milliseconds: 240);
  static const _kSettle = Duration(milliseconds: 140);

  // Ink for this screen only. The scene is always dark, so these do not come
  // from AppTheme — a theme-aware getter here would produce dark text on a
  // dark ground in light mode.
  static const _kInk = Color(0xFF07070C);
  static final _inkSoft = Colors.white.withValues(alpha: 0.72);
  static final _railTrack = Colors.white.withValues(alpha: 0.12);

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(vsync: this, duration: _kIntro);
    _progress = AnimationController(vsync: this);

    // Fractions of _kIntro. The wordmark and tagline overlap by 50ms on
    // purpose: a hard gap reads as two animations stopping and starting, a
    // small overlap reads as one element following another.
    _markAnim = CurvedAnimation(
      parent: _introController,
      curve: const Interval(
        _kBlackHold / _kIntroMs,
        _kMarkEnd / _kIntroMs,
        curve: Curves.easeOutCubic,
      ),
    );
    _taglineAnim = CurvedAnimation(
      parent: _introController,
      curve: const Interval(
        _kTaglineStart / _kIntroMs,
        _kTaglineEnd / _kIntroMs,
        curve: Curves.easeOutCubic,
      ),
    );
    _taglineRise = Tween<double>(begin: 22, end: 0).animate(_taglineAnim);
    _railAnim = CurvedAnimation(
      parent: _introController,
      // Lands as the rail begins to move, so it is never visible sitting still.
      curve: const Interval(
        _kRailFadeStart / _kIntroMs,
        _kRailFadeEnd / _kIntroMs,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_launched) return;
    _launched = true;

    _reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_reducedMotion) {
      // Present the finished state immediately. The hold below still applies —
      // it is about work in flight, not about the animation.
      _introController.value = 1.0;
      _progress.value = 1.0;
    } else {
      _introController.forward();
      _startRail();
    }
    _startLaunch();
  }

  /// Eases the rail out to [_kRailRest] and leaves it there.
  ///
  /// The number is a *timed* impression of progress, not a measurement: there
  /// is no meaningful percentage to report for "restore a session, then read
  /// one document". What makes it honest rather than decorative is that it
  /// stops at 90% and only completes when the destination genuinely resolves,
  /// so it never claims to be finished before the app is. easeOut is doing the
  /// same work — decelerating reads as approaching completion, where a linear
  /// fill that stalls at 90% reads as stuck.
  Future<void> _startRail() async {
    await Future<void>.delayed(_kRailStart);
    if (!mounted) return;
    _progress.animateTo(_kRailRest,
        duration: _kRailRun, curve: Curves.easeOut);
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

    // Close the rail out before leaving, so the last thing seen is 100% rather
    // than whatever it happened to be mid-sweep.
    if (!_reducedMotion) {
      await _progress.animateTo(1.0,
          duration: _kRailFinish, curve: Curves.easeOutCubic);
      await Future<void>.delayed(_kSettle);
      if (!mounted) return;
    }

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
      bool suspended = false;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshed.uid)
            .get();
        role = doc.data()?['role'] as String? ?? '';
        suspended = doc.data()?['suspended'] == true;
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
        suspended: suspended,
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
    _introController.dispose();
    _progress.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light icons, because the ground is always dark. Without this a
      // light-mode device draws dark status bar icons onto near-black.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _kInk,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kInk,
        body: SafeArea(
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
                _footer(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Wordmark and tagline as one stacked lockup, revealed in that order.
  ///
  /// The app name is the hero and the tagline carries the screen. Both can be
  /// large because the artwork is wide and short — it takes horizontal space,
  /// the tagline takes vertical, so they occupy different room instead of
  /// competing for the same.
  Widget _identity(bool compact) {
    return AnimatedBuilder(
      animation: _introController,
      builder: (context, child) {
        return Column(
          children: [
            // Always the on-dark variant — this scene is dark in both themes,
            // so the light-background artwork would put black letters on a
            // near-black ground.
            Opacity(
              opacity: _markAnim.value,
              child: Transform.translate(
                offset: Offset(0, (1 - _markAnim.value) * 18),
                child:
                    HomegrownWordmark(width: compact ? 172 : 200, onDark: true),
              ),
            ),
            SizedBox(height: compact ? 16 : 22),
            Opacity(
              opacity: _taglineAnim.value,
              child: Transform.translate(
                offset: Offset(0, _taglineRise.value),
                child: child,
              ),
            ),
          ],
        );
      },
      child: Text(
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
    );
  }

  /// The rail and the CTA share one slot, cross-fading between them.
  ///
  /// A Stack rather than a swap so the slot keeps the height of the taller
  /// child — the buttons — and nothing above it shifts when loading finishes.
  /// Non-positioned Stack children report intrinsics, so this is safe inside
  /// FillViewportScroll's IntrinsicHeight.
  Widget _footer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity: _showButtons ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 260),
          child: _rail(),
        ),
        _actions(),
      ],
    );
  }

  Widget _rail() {
    return AnimatedBuilder(
      animation: Listenable.merge([_introController, _progress]),
      builder: (context, child) {
        final percent = (_progress.value * 100).round();
        return Opacity(
          opacity: _railAnim.value,
          child: Semantics(
            label: 'Loading',
            // The number changes many times a second and carries nothing a
            // screen reader user needs; the label above says all of it.
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(color: _railTrack),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progress.value.clamp(0.0, 1.0),
                          child: const ColoredBox(color: AppTheme.accent),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$percent%',
                  style: TextStyle(
                    color: _inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    // Tabular figures so the digits keep their column and the
                    // number does not jitter as it counts up.
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
