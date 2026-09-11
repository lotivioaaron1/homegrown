// test/splash_screen_test.dart
//
// Covers the staged reveal on the splash. The screen used to bring its whole
// lockup up together over a photograph; it now opens on half a second of black
// and introduces one element at a time, with a progress rail that only reaches
// 100% once the destination has actually resolved. All of that is timing, and
// timing is exactly the kind of thing that drifts silently — an Interval nudged
// by a few hundredths reads fine in code review and ruins the sequence on a
// device.
//
// No Firebase is initialised here, so FirebaseAuth.instance throws inside
// _resolveDestination. That is the point: _startLaunch catches it, resolves to
// a null destination, and the screen falls through to its Get Started CTA —
// which is the same path a genuinely signed-out launch takes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:homegrown/screens/splash_screen.dart';
import 'package:homegrown/widgets/homegrown_wordmark.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host() => GetMaterialApp(
      home: const SplashScreen(),
      getPages: [
        GetPage(
            name: '/onboarding',
            page: () => const Scaffold(body: Text('onboarding screen'))),
        GetPage(
            name: '/login',
            page: () => const Scaffold(body: Text('login screen'))),
      ],
    );

final _wordmark = find.byType(HomegrownWordmark);
final _tagline = find.text('Every Game\nCounts.');
final _railPercent = find
    .byWidgetPredicate((w) => w is Text && (w.data ?? '').endsWith('%'));

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
/// painted. AnimatedOpacity builds a FadeTransition rather than an Opacity, so
/// the cross-fade on the footer cannot be picked up by mistake.
double _revealOf(WidgetTester tester, Finder target) => tester
    .widget<Opacity>(
      find.ancestor(of: target, matching: find.byType(Opacity)).first,
    )
    .opacity;

/// The rail's percentage as an integer, read off the label the user sees.
int _percent(WidgetTester tester) => int.parse(
    tester.widget<Text>(_railPercent).data!.replaceAll('%', ''));

/// Whether the Get Started CTA can actually be pressed.
///
/// Better than asking whether it is on screen: it is always in the tree, held
/// transparent and inert until the launch resolves.
bool _ctaLive(WidgetTester tester) => !tester
    .widget<IgnorePointer>(
      find
          .ancestor(
              of: find.text('Get Started'), matching: find.byType(IgnorePointer))
          .first,
    )
    .ignoring;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('holds on black, then reveals wordmark, tagline and rail in turn',
      (tester) async {
    await tester.pumpWidget(_host());
    final clock = _Clock(tester);

    // 0–500ms: the empty beat. Nothing is painted, which is what makes the
    // wordmark read as arriving rather than as having always been there.
    await clock.to(400);
    expect(_revealOf(tester, _wordmark), 0.0);
    expect(_revealOf(tester, _tagline), 0.0);
    expect(_revealOf(tester, _railPercent), 0.0);

    // The wordmark comes up alone.
    await clock.to(900);
    expect(_revealOf(tester, _wordmark), greaterThan(0.0));
    expect(_revealOf(tester, _tagline), 0.0);

    // The tagline follows, with the wordmark already settled.
    await clock.to(1300);
    expect(_revealOf(tester, _wordmark), 1.0);
    expect(_revealOf(tester, _tagline), greaterThan(0.0));

    // The rail is last, and everything is up by 1800ms.
    await clock.to(1800);
    expect(_revealOf(tester, _tagline), 1.0);
    expect(_revealOf(tester, _railPercent), 1.0);

    await clock.to(3200);
    await tester.pumpAndSettle();
  });

  testWidgets('rail rests short of full and only completes once resolved',
      (tester) async {
    await tester.pumpWidget(_host());
    final clock = _Clock(tester);

    // Starts at 0 the moment it starts fading in, so it is never seen sitting
    // still at some arbitrary value.
    await clock.to(1300);
    expect(_percent(tester), 0);

    await clock.to(1800);
    expect(_percent(tester), greaterThan(0));
    expect(_percent(tester), lessThan(90));

    // Just before the minimum hold elapses. The rail has eased almost all the
    // way to its resting 90% and stops there: the number is a timed impression
    // of progress, and claiming completion before the destination is known
    // would be the one dishonest thing it could do.
    await clock.to(2150);
    expect(_percent(tester), greaterThanOrEqualTo(85));
    expect(_percent(tester), lessThanOrEqualTo(90));
    expect(_ctaLive(tester), isFalse);

    // The completion sweep runs only after the launch resolves, and the CTA
    // takes over after it.
    await clock.to(3200);
    await tester.pumpAndSettle();
    expect(_percent(tester), 100);
    expect(_ctaLive(tester), isTrue);
  });

  testWidgets('carries no background photograph and no dedication',
      (tester) async {
    await tester.pumpWidget(_host());
    await _Clock(tester).to(3200);
    await tester.pumpAndSettle();

    // The verse was retired with the redesign.
    expect(find.textContaining('strengthens me'), findsNothing);
    expect(find.textContaining('PHILIPPIANS'), findsNothing);

    // The wordmark is the only artwork left — ring.jpg and its scrim are gone,
    // so anything more than one Image here means a background crept back in.
    expect(find.byType(Image), findsOneWidget);
    expect(_wordmark, findsOneWidget);
  });
}
