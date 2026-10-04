// test/splash_screen_test.dart
//
// Covers the staged reveal on the splash, in both of its looks. Each opens on
// half a second of black and drops the sport balls in from above the screen
// to bounce to a stop, and the wordmark lands on the basketball's first
// touchdown. The opening screen — every app launch — then brings in the
// "Every Game Counts." headline under a left-aligned wordmark and a
// full-width loading rail. The screen after Sign out shows the wordmark on
// its own at the centre, over a short loading bar. Either way the rail only
// completes once the destination has actually resolved. All of that is
// timing, and timing is exactly the kind of thing that drifts silently — an
// Interval nudged by a few hundredths reads fine in code review and ruins the
// sequence on a device.
//
// No Firebase is initialised here, so FirebaseAuth.instance throws inside
// _resolveDestination. That is the point: _startLaunch catches it, resolves to
// a null destination, and the screen falls through to its welcome actions —
// which is the same path a genuinely signed-out launch takes. Tests that need
// a launch to resolve somewhere else, or to stay unresolved, hand the screen
// their own resolver.
//
// Once those actions are up the balls drift on a loop that never ends, so
// nothing here can pumpAndSettle past that point; the clock is stepped to a
// fixed time instead.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:homegrown/screens/splash_screen.dart';
import 'package:homegrown/widgets/homegrown_wordmark.dart';
import 'package:homegrown/widgets/sport_ball_scene.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A phone's screen, in logical pixels — the layout the splash is built for.
const _kPhone = Size(411, 891);

/// The splash as the app's first route, with stand-ins for where it leads.
Widget _app(Widget splash) => GetMaterialApp(
      home: splash,
      getPages: [
        GetPage(
            name: '/onboarding',
            page: () => const Scaffold(body: Text('onboarding screen'))),
        GetPage(
            name: '/login',
            page: () => const Scaffold(body: Text('login screen'))),
      ],
    );

/// Shows the splash on a phone-sized screen.
///
/// [resolve] stands in for the launch's own destination lookup; left null,
/// the screen uses its real one, which fails fast here as described above.
/// [afterSignOut] picks the look shown after Sign out.
Future<void> _pumpSplash(
  WidgetTester tester, {
  Future<String?> Function()? resolve,
  Size screen = _kPhone,
  bool afterSignOut = false,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(SplashScreen(
    resolveDestination: resolve,
    afterSignOut: afterSignOut,
  )));
}

final _wordmark = find.byType(HomegrownWordmark);
final _headline = find.text('Every Game\nCounts.');
final _rail = find.byKey(const Key('splash-rail'));

/// Walks the fake clock forward a frame at a time, remembering where it is so
/// checkpoints below can be written as absolute times on the timeline.
///
/// Deliberately not a single `pump(bigDuration)`. Each pump produces exactly
/// one frame, so an animation started between two coarse pumps does not begin
/// ticking until the next one and then jumps a whole step — which leaves the
/// animation clocks hundreds of milliseconds behind the fake clock that
/// `Future.delayed` runs on, and makes every assertion below wrong by a
/// different amount. Stepping at frame size keeps the two within ~16ms, which
/// is why the checkpoints can carry real numbers instead of wide tolerances.
class _Clock {
  _Clock(this.tester);

  final WidgetTester tester;
  static const _frame = Duration(milliseconds: 16);
  int _now = 0;

  /// Advances until at least [ms] have elapsed since the first frame.
  Future<void> to(int ms) async {
    while (_now < ms) {
      await tester.pump(_frame);
      _now += _frame.inMilliseconds;
    }
  }
}

/// The opacity of the nearest [Opacity] above [target].
///
/// Each staged element is wrapped in its own explicit Opacity, so this reads
/// the reveal directly rather than inferring it from what happens to be
/// painted.
double _revealOf(WidgetTester tester, Finder target) => tester
    .widget<Opacity>(
      find.ancestor(of: target, matching: find.byType(Opacity)).first,
    )
    .opacity;

/// How far the balls are through their arrival, 0 (none yet) to 1 (at rest).
double _entrance(WidgetTester tester) =>
    tester.widget<SportBallScene>(find.byType(SportBallScene)).entrance.value;

/// How full the rail is, 0..1, read off the fill's width.
double _fill(WidgetTester tester) => tester
    .widget<FractionallySizedBox>(
      find.descendant(of: _rail, matching: find.byType(FractionallySizedBox)),
    )
    .widthFactor!;

/// Whether the welcome actions can actually be pressed.
///
/// Better than asking whether it is on screen: it is always in the tree, held
/// transparent and inert until the launch resolves.
bool _ctaLive(WidgetTester tester) => !tester
    .widget<IgnorePointer>(
      find
          .ancestor(
              of: find.text('Create Account'),
              matching: find.byType(IgnorePointer))
          .first,
    )
    .ignoring;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('opening screen', () {
    testWidgets(
        'holds on black, drops the balls, then brings in the wordmark, '
        'headline and rail in turn', (tester) async {
      await _pumpSplash(tester);
      final clock = _Clock(tester);

      // 0–500ms: the empty beat. Nothing is painted, which is what makes the
      // scene read as arriving rather than as having always been there.
      await clock.to(400);
      expect(_entrance(tester), 0.0);
      expect(_revealOf(tester, _wordmark), 0.0);
      expect(_revealOf(tester, _headline), 0.0);
      expect(_revealOf(tester, _rail), 0.0);

      // The balls are on their way down, but the basketball has not hit the
      // ground yet, so the wordmark is still waiting for it.
      await clock.to(700);
      expect(_entrance(tester), greaterThan(0.0));
      await clock.to(850);
      expect(_revealOf(tester, _wordmark), 0.0);

      // The touchdown, at about 876ms, brings the wordmark in. The headline
      // waits for it.
      await clock.to(950);
      expect(_revealOf(tester, _wordmark), greaterThan(0.0));
      expect(_revealOf(tester, _headline), 0.0);

      // The headline follows with the wordmark all but settled.
      await clock.to(1300);
      expect(_revealOf(tester, _wordmark), 1.0);
      expect(_revealOf(tester, _headline), greaterThan(0.0));

      await clock.to(1900);
      expect(_revealOf(tester, _headline), 1.0);
      expect(_revealOf(tester, _rail), 1.0);

      await clock.to(3400);
    });

    testWidgets('the rail stays on as the divider above the actions',
        (tester) async {
      await _pumpSplash(tester);
      await _Clock(tester).to(3400);

      expect(_ctaLive(tester), isTrue);
      expect(_revealOf(tester, _rail), 1.0);
    });

    testWidgets('carries no background photograph and no dedication',
        (tester) async {
      await _pumpSplash(tester);
      await _Clock(tester).to(3400);

      // The verse was retired with the redesign.
      expect(find.textContaining('strengthens me'), findsNothing);
      expect(find.textContaining('PHILIPPIANS'), findsNothing);

      // The wordmark is the only artwork left — ring.jpg and its scrim are
      // gone, so anything more than one Image here means a background crept
      // back in. The balls are painted, not images, so they do not count.
      expect(find.byType(Image), findsOneWidget);
      expect(_wordmark, findsOneWidget);
      expect(find.byType(SportBallScene), findsOneWidget);
    });

    // pumpAndSettle is safe after a tap: the splash is replaced, and the
    // drift's ticker goes with it.
    testWidgets('Create Account goes to the intro pages', (tester) async {
      await _pumpSplash(tester);
      await _Clock(tester).to(3400);
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      expect(find.text('onboarding screen'), findsOneWidget);
    });

    testWidgets('Log in goes to the sign-in screen', (tester) async {
      await _pumpSplash(tester);
      await _Clock(tester).to(3400);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('login screen'), findsOneWidget);
    });

    testWidgets('a tap before the launch resolves does nothing',
        (tester) async {
      await _pumpSplash(tester);
      final clock = _Clock(tester);

      // The actions are laid out but invisible here, so a stray tap lands on
      // them. It has to be ignored rather than routing a signed-in user to
      // the intro before their own destination is known.
      await clock.to(2000);
      await tester.tap(find.text('Create Account'), warnIfMissed: false);
      await clock.to(2400);
      expect(find.text('onboarding screen'), findsNothing);
      await clock.to(3400);
    });

    testWidgets('with animations off, presents the finished scene at once',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await _pumpSplash(tester);
      await tester.pump();
      expect(_entrance(tester), 1.0);
      expect(_revealOf(tester, _wordmark), 1.0);
      expect(_revealOf(tester, _headline), 1.0);

      // The hold still applies — it is about work in flight — and the
      // actions still arrive, just without moving.
      await _Clock(tester).to(2400);
      expect(_ctaLive(tester), isTrue);
    });
  });

  group('after sign-out', () {
    testWidgets('carries the wordmark alone, without the headline',
        (tester) async {
      await _pumpSplash(tester, afterSignOut: true);
      await _Clock(tester).to(3400);

      expect(_wordmark, findsOneWidget);
      expect(_headline, findsNothing);
    });

    testWidgets('centres the wordmark on the screen', (tester) async {
      await _pumpSplash(tester, afterSignOut: true);
      final clock = _Clock(tester);
      await clock.to(1600);

      final centre = tester.getCenter(_wordmark);
      expect(centre.dx, closeTo(_kPhone.width / 2, 1));
      // On the centre line, give or take the bottom padding, which lifts it a
      // touch above the geometric middle.
      expect(centre.dy,
          inInclusiveRange(_kPhone.height * 0.40, _kPhone.height * 0.55));

      await clock.to(3400);
    });

    testWidgets('stays centred on real phone metrics with a gesture-bar inset',
        (tester) async {
      // The Android emulator's own metrics: 1080×2340 at 2.75 is 392.7×850.9
      // logical, with an inset at the bottom for the gesture bar. The
      // wordmark gives up the centre only when the screen genuinely runs out
      // of room, and an ordinary phone has plenty.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      tester.view.padding = const FakeViewPadding(bottom: 63);
      tester.view.viewPadding = const FakeViewPadding(bottom: 63);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const SplashScreen(afterSignOut: true)));
      final clock = _Clock(tester);
      await clock.to(1600);

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final centre = tester.getCenter(_wordmark);
      expect(centre.dx, closeTo(screen.width / 2, 1));
      expect(centre.dy,
          inInclusiveRange(screen.height * 0.40, screen.height * 0.55));

      await clock.to(3400);
    });

    testWidgets(
        'keeps the actions on screen at the largest text size on a small '
        'phone', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const small = Size(360, 640);
      await _pumpSplash(tester, screen: small, afterSignOut: true);
      await _Clock(tester).to(3400);

      // Centring the wordmark there would leave the top half as tall as the
      // enlarged actions, pushing Log in below the bottom of the screen. The
      // balls give up their room instead, and the wordmark stays in view.
      final logIn = find.widgetWithText(OutlinedButton, 'Log in');
      expect(tester.getRect(logIn).bottom, lessThanOrEqualTo(small.height));
      expect(tester.getRect(_wordmark).top, greaterThanOrEqualTo(0));
    });

    testWidgets('the rail fades out once the welcome actions are up',
        (tester) async {
      await _pumpSplash(tester, afterSignOut: true);
      await _Clock(tester).to(3400);

      expect(_ctaLive(tester), isTrue);
      // Its job is done. It does not linger as a second line over the
      // actions.
      expect(_revealOf(tester, _rail), 0.0);
    });

    testWidgets('goes on to Login once the hold is up', (tester) async {
      // Where a sign-out lands: nobody is signed in, and this device has had
      // an account, so the launch resolves to the sign-in screen.
      await _pumpSplash(tester,
          afterSignOut: true, resolve: () async => '/login');
      final clock = _Clock(tester);

      await clock.to(2400);
      expect(find.text('login screen'), findsNothing);

      await clock.to(3000);
      await tester.pumpAndSettle();
      expect(find.text('login screen'), findsOneWidget);
    });
  });

  // How the rail fills is the same in both looks.
  group('loading rail', () {
    testWidgets('rests short of full and only completes once resolved',
        (tester) async {
      await _pumpSplash(tester);
      final clock = _Clock(tester);

      // Starts at 0 the moment it starts fading in, so it is never seen
      // sitting still at some arbitrary value.
      await clock.to(1300);
      expect(_fill(tester), 0.0);

      await clock.to(1800);
      expect(_fill(tester), greaterThan(0.0));
      expect(_fill(tester), lessThan(0.8));

      // Just before the minimum hold elapses, the rail has all but reached
      // the 80% it runs to: the number is a timed impression of progress, and
      // claiming completion before the destination is known would be the one
      // dishonest thing it could do.
      await clock.to(2150);
      expect(_fill(tester), greaterThanOrEqualTo(0.75));
      expect(_fill(tester), lessThanOrEqualTo(0.80));
      expect(_ctaLive(tester), isFalse);

      // The completion sweep runs only after the launch resolves, and the
      // actions take over after it.
      await clock.to(3400);
      expect(_fill(tester), 1.0);
      expect(_ctaLive(tester), isTrue);
    });

    testWidgets('keeps moving while a slow launch is still resolving',
        (tester) async {
      final destination = Completer<String?>();
      await _pumpSplash(tester, resolve: () => destination.future);
      final clock = _Clock(tester);

      await clock.to(2300);
      final atHold = _fill(tester);
      expect(atHold, closeTo(0.8, 0.02));

      // Still waiting on a slow connection. A rail that stops dead here reads
      // as frozen, so it keeps creeping — without ever claiming to be done.
      await clock.to(4000);
      final later = _fill(tester);
      expect(later, greaterThan(atHold + 0.03));
      expect(later, lessThan(1.0));
      expect(_ctaLive(tester), isFalse);

      destination.complete(null);
      await clock.to(4600);
      expect(_fill(tester), 1.0);
      expect(_ctaLive(tester), isTrue);
    });
  });
}
