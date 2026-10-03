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
import '../widgets/sport_ball_scene.dart';

/// Deliberately a single dark scene in both themes.
///
/// A splash is a held moment, not a screen you work in, and committing to one
/// palette also removes a flash: the app used to build in light theme and then
/// snap to the saved one, which was most visible here. main() now resolves the
/// theme before the first frame, and this screen simply ignores it.
///
/// The ground is flat [_kInk], the same near-black as the Android launch
/// screen and the adaptive icon's plate, so the OS hands over to Flutter with
/// nothing changing colour. On it, a basketball, a volleyball and a
/// shuttlecock ([SportBallScene]) fill the top of the screen, and the wordmark,
/// tagline, loading rail and — for a first launch — the welcome actions sit on
/// plain ink below them.
///
/// Two earlier versions put something *behind* the lockup — a blurred
/// photograph under a scrim, and before that a gradient with the wordmark in an
/// orbiting ring — and both were replaced on the same complaint: the
/// background competed with it. The balls are not a background. They take only
/// the height left above the text, so nothing is ever drawn under a letter.
///
/// The reveal is staged rather than simultaneous: half a second of nothing,
/// then the balls, then the wordmark, the tagline and the rail. The empty beat
/// is load-bearing — it is what makes everything read as arriving instead of
/// having always been there.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// The intro's stagger: black hold, balls, wordmark, tagline, rail.
  late AnimationController _introController;
  late Animation<double> _ballsAnim;
  late Animation<double> _markAnim;
  late Animation<double> _taglineAnim;
  late Animation<double> _taglineRise;
  late Animation<double> _railAnim;

  /// The progress rail's value, 0..1. Separate from [_introController] because
  /// it is not purely time-driven — see [_startLaunch].
  late AnimationController _progress;

  /// The welcome actions' entrance, once a first launch has resolved: the
  /// rail settles into a divider, then the pitch and the two buttons rise in
  /// one after another.
  late AnimationController _cta;
  late Animation<double> _railSettle;
  late Animation<double> _pitchIn;
  late Animation<double> _createIn;
  late Animation<double> _signInIn;

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

  /// The balls arrive first and on their own, starting the moment the hold
  /// ends; the scene staggers the three inside this window.
  static const _kBallsEnd = 1200;

  /// The wordmark follows a quarter of a second behind the first ball, so the
  /// eye travels from the top of the screen down to the text.
  static const _kMarkStart = 750;
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

  /// The welcome actions' whole entrance, stagger included.
  static const _kCtaReveal = Duration(milliseconds: 460);

  /// A strong ease-out for things arriving: fast off the mark, long settle.
  static const _kArrive = Cubic(0.23, 1, 0.32, 1);

  // Ink for this screen only. The scene is always dark, so these do not come
  // from AppTheme — a theme-aware getter here would produce dark text on a
  // dark ground in light mode.
  static const _kInk = Color(0xFF07070C);
  static final _inkSoft = Colors.white.withValues(alpha: 0.72);
  static final _railTrack = Colors.white.withValues(alpha: 0.12);

  /// What the full rail fades to once loading is over and it stays on as the
  /// divider above the actions. Gold would put a second gold bar directly over
  /// the gold button.
  static final _railDivider = Colors.white.withValues(alpha: 0.28);

  /// Side padding for the text column, which the ball scene paints past so
  /// the balls can run off the screen edges.
  static const _kGutter = 24.0;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(vsync: this, duration: _kIntro);
    _progress = AnimationController(vsync: this);
    _cta = AnimationController(vsync: this, duration: _kCtaReveal);

    // Linear on purpose: the scene gives each ball its own curve.
    _ballsAnim = CurvedAnimation(
      parent: _introController,
      curve: const Interval(_kBlackHold / _kIntroMs, _kBallsEnd / _kIntroMs),
    );

    // Fractions of _kIntro. The wordmark and tagline overlap by 50ms on
    // purpose: a hard gap reads as two animations stopping and starting, a
    // small overlap reads as one element following another.
    _markAnim = CurvedAnimation(
      parent: _introController,
      curve: const Interval(
        _kMarkStart / _kIntroMs,
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

    // Fractions of _kCtaReveal; about 55ms between each element.
    _railSettle = CurvedAnimation(
      parent: _cta,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _pitchIn = CurvedAnimation(
      parent: _cta,
      curve: const Interval(0.0, 0.8, curve: _kArrive),
    );
    _createIn = CurvedAnimation(
      parent: _cta,
      curve: const Interval(0.12, 0.92, curve: _kArrive),
    );
    _signInIn = CurvedAnimation(
      parent: _cta,
      curve: const Interval(0.2, 1.0, curve: _kArrive),
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
      _revealActions();
    } else {
      Get.offAllNamed(destination);
    }
  }

  /// Where this launch should land, or null to show the welcome actions.
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
  /// The slow path waits for the first `authStateChanges()` emission, which the
  /// platform delivers only once it has finished restoring (or ruled out)
  /// restoring a persisted session — so a null first emission means genuinely
  /// signed out and answers quickly, and a signed-in user arrives the moment
  /// restore completes. Waiting for a *non-null* emission on a fixed 1200ms
  /// timeout, as this did, could not tell "restore is merely slow on this
  /// device" from "really signed out": the timeout returned null, and that
  /// frozen decision to go to /login overrode the splash's own 2200ms minimum
  /// hold, which would have covered a late restore anyway. The timeout below
  /// is only a last-resort guard for a stream that never emits, and sits under
  /// that hold so a signed-out launch loses no time to it.
  Future<User?> _restoredUser() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      debugPrint('_restoredUser: currentUser ready before listening');
      return current;
    }

    var timedOut = false;
    final restored = await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(
          const Duration(milliseconds: 2000),
          onTimeout: () {
            timedOut = true;
            return null;
          },
        );

    if (timedOut) {
      debugPrint('_restoredUser: no auth state within 2000ms '
          '(treated as signed out)');
    } else if (restored == null) {
      debugPrint('_restoredUser: first auth state is null (signed out)');
    } else {
      debugPrint('_restoredUser: restored user ${restored.uid}');
    }
    return restored;
  }

  /// Hands a first launch over to the welcome actions.
  void _revealActions() {
    setState(() => _showButtons = true);
    if (_reducedMotion) {
      _cta.value = 1.0;
    } else {
      _cta.forward();
    }
  }

  // Create Account goes through the intro pages on its way to registration,
  // exactly as the Get Started it replaced did: they are the only route into
  // onboarding, and each one carries a Skip.
  void _onCreateAccount() => Get.offNamed('/onboarding');
  void _onSignIn() => Get.offNamed('/login');

  @override
  void dispose() {
    _introController.dispose();
    _progress.dispose();
    _cta.dispose();
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
        // Not inset at the top: the balls run up behind the transparent status
        // bar, the way they run off the sides. The text below them is nowhere
        // near it.
        body: SafeArea(
          top: false,
          // Scrolls rather than overflows once the text outgrows the viewport,
          // which it does at the largest system text sizes. The scene is the
          // flexible part, so it gives up its height first.
          child: FillViewportScroll(
            padding:
                EdgeInsets.fromLTRB(_kGutter, 0, _kGutter, compact ? 20 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Whatever height the text leaves, so a ball can never sit
                // behind a line of it on any screen.
                Expanded(
                  child: SportBallScene(
                    entrance: _ballsAnim,
                    idle: _showButtons,
                    reducedMotion: _reducedMotion,
                    bleed: _kGutter,
                  ),
                ),
                _identity(compact),
                SizedBox(height: compact ? 10 : 14),
                _pitch(compact),
                SizedBox(height: compact ? 18 : 22),
                _rail(),
                SizedBox(height: compact ? 18 : 22),
                _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Wordmark over tagline, left-aligned, revealed in that order.
  ///
  /// The wordmark names the app and the tagline carries the screen, which is
  /// why the tagline keeps its full size: it was once cut to a small single
  /// line and the screen lost its voice.
  Widget _identity(bool compact) {
    return AnimatedBuilder(
      animation: _introController,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Always the on-dark variant — this scene is dark in both themes,
            // so the light-background artwork would put black letters on a
            // near-black ground.
            Opacity(
              opacity: _markAnim.value,
              child: Transform.translate(
                offset: Offset(0, (1 - _markAnim.value) * 18),
                child:
                    HomegrownWordmark(width: compact ? 128 : 150, onDark: true),
              ),
            ),
            SizedBox(height: compact ? 12 : 16),
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

  /// What the app does, in one line, for someone deciding whether to sign up.
  ///
  /// Only shown with the welcome actions. A returning user sees this screen on
  /// every launch on the way into the app, and a sales line every time would
  /// be noise. Its space is held either way so nothing moves when it appears.
  Widget _pitch(bool compact) {
    return _rising(
      _pitchIn,
      Text(
        // "Leaderboard" rather than "Elo": it is the word a newcomer already
        // knows, and Elo is explained once they are inside.
        'Track your stats. Get scouted by coaches. Climb the leaderboard.',
        style: TextStyle(
          color: _inkSoft,
          fontSize: compact ? 13.5 : 14.5,
          height: 1.5,
        ),
      ),
    );
  }

  /// The loading rail, which stays on afterwards as the divider above the
  /// welcome actions.
  ///
  /// The fill used to be a bare ColoredBox in a loose Stack, which gave it no
  /// height at all: the track showed and the gold never did. StackFit.expand
  /// hands the fill the rail's full height.
  Widget _rail() {
    return AnimatedBuilder(
      animation: Listenable.merge([_introController, _progress, _cta]),
      builder: (context, child) {
        return Opacity(
          opacity: _railAnim.value,
          child: Semantics(
            // Only while it means something. Once the actions are up it is a
            // divider, and announcing "Loading" then would be wrong.
            label: _showButtons ? null : 'Loading',
            excludeSemantics: true,
            child: SizedBox(
              key: const Key('splash-rail'),
              height: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: _railTrack),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progress.value.clamp(0.0, 1.0),
                      child: ColoredBox(
                        color: Color.lerp(
                            AppTheme.accent, _railDivider, _railSettle.value)!,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Create Account and Log in, held transparent and inert until a first
  /// launch resolves, then risen in one after the other.
  ///
  /// Always laid out, so the screen does not reflow when they appear.
  Widget _actions() {
    return IgnorePointer(
      ignoring: !_showButtons,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rising(
            _createIn,
            _PressScale(
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _onCreateAccount,
                  child: const Text('Create Account'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _rising(
            _signInIn,
            _PressScale(
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: _onSignIn,
                  // Set here rather than taken from the theme: the light
                  // theme's outlined button is dark gold on a pale border,
                  // and this scene is dark in both.
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.accent, width: 1.5),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Log in'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fades [child] in as [anim] runs, rising the last few pixels into place.
  Widget _rising(Animation<double> anim, Widget child) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Shrinks its child a touch while a finger is down on it.
///
/// The buttons' ink ripple confirms a tap after the fact; this answers the
/// moment the finger lands, which is what makes a press feel heard.
class _PressScale extends StatefulWidget {
  final Widget child;

  const _PressScale({required this.child});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
