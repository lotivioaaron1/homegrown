// test/onboarding_screen_test.dart
//
// Covers the onboarding flow after the "What sport do you play?" page was
// removed. That page saved a sport to SharedPreferences that nothing ever
// read, so registration asked for it again — and because onboarding runs
// before the role picker, it asked coaches and organizers a question meant
// for athletes. These tests pin the page down as gone and pin down the
// onboarding_complete flag that splash_screen.dart depends on.
//
// The Features page that followed the sport panels is gone too: it repeated
// the pitch the splash's welcome screen had just made and asked for a second
// tap before the form. The last sport panel carries Create Account instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:homegrown/screens/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// GetMaterialApp, not MaterialApp: _onCreateAccount calls Get.offAllNamed, which
// needs Get's navigator. The '/register' route is stubbed so the tap has
// somewhere to land.
Widget _host() => GetMaterialApp(
      home: const OnboardingScreen(),
      getPages: [
        GetPage(
            name: '/register',
            page: () => const Scaffold(body: Text('register screen'))),
      ],
    );

/// Swipes to the last page, whatever the page count is.
///
/// Deliberately swipes more times than the flow has pages: flinging at the
/// last page is a no-op, so this can't stop short. An earlier version used a
/// fixed three swipes and silently passed the "no sport question" test by
/// never reaching the page that asked it.
Future<void> _pageToEnd(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('never asks which sport the user plays', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await _pageToEnd(tester);

    // The question belongs to the registration screens now, where the role
    // is known and the answer is actually stored.
    expect(find.textContaining('sport do'), findsNothing);
    expect(find.text('Basketball'), findsNothing);
    expect(find.text('Volleyball'), findsNothing);
    expect(find.text('Badminton'), findsNothing);
  });

  testWidgets('ends on the last sport panel with Create Account',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await _pageToEnd(tester);

    // The badminton panel, not a Features page after it.
    expect(find.text('BADMINTON'), findsOneWidget);
    expect(find.text('Performance Dashboard'), findsNothing);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    // Its own button goes where Skip would, so a Skip beside it would be two
    // controls doing one job.
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('Create Account on the last panel goes to registration',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await _pageToEnd(tester);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('register screen'), findsOneWidget);
  });

  // Skip exists so someone who wants an account does not have to sit through
  // the whole pitch to reach one. It briefly did not exist at all: it was
  // hidden on the last page, and when the sport-selection page was removed,
  // Features became last and Skip could never render, so it was deleted as
  // dead code rather than as a decision.
  group('Skip', () {
    testWidgets('is offered on the sport panels', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('stays available past the first panel', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // One swipe leaves us on the middle panel. Skip has to survive the run
      // of panels, not just the first; only the last, whose own button does
      // Skip's job, drops it.
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('VOLLEYBALL'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('goes straight to registration', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('register screen'), findsOneWidget);
    });

    // Same rule as finishing the intro normally: watching or skipping the
    // pitch is not what makes someone a returning user, signing in is. If
    // Skip recorded it, anyone who skipped and then abandoned registration
    // would be sent to /login from then on and could never see the intro.
    testWidgets('does not mark onboarding complete', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_complete'), isNull);
    });

    // A 14px label is not a tap target. Android wants 48dp.
    testWidgets('has a tappable hit area', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final size = tester.getSize(
        find.ancestor(
          of: find.text('Skip'),
          matching: find.byType(GestureDetector),
        ).first,
      );

      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    });
  });

  // Onboarding deliberately records nothing. splash_screen.dart sets
  // onboarding_complete once it finds a signed-in user instead, because the
  // splash CTA is the only route to this screen: marking it done here meant
  // anyone who watched the intro and then abandoned registration was sent to
  // the login screen from then on and could never reach the intro again.
  // Don't "fix" this back to isTrue.
  testWidgets('does not mark onboarding complete on its own', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await _pageToEnd(tester);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_complete'), isNull);
  });

  // Guards against the dead write coming back rather than proving the page
  // is gone (test one does that): the old code only wrote user_sport when a
  // sport had been picked, so an untouched run left it unset either way.
  testWidgets('writes no user_sport key', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await _pageToEnd(tester);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_sport'), isNull);
  });
}
