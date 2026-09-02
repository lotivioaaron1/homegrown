// test/onboarding_screen_test.dart
//
// Covers the onboarding flow after the "What sport do you play?" page was
// removed. That page saved a sport to SharedPreferences that nothing ever
// read, so registration asked for it again — and because onboarding runs
// before the role picker, it asked coaches and organizers a question meant
// for athletes. These tests pin the page down as gone and pin down the
// onboarding_complete flag that splash_screen.dart depends on.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:homegrown/screens/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// GetMaterialApp, not MaterialApp: _onGetStarted calls Get.offAllNamed, which
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

  testWidgets('ends on the Features page with a Get Started button',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await _pageToEnd(tester);

    // Assert this really is the Features page, not merely that some last
    // page exists — the sport page it replaced also ended with a CTA.
    expect(find.text('Performance Dashboard'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    // Skip only ever made sense while a page followed Features.
    expect(find.text('Skip'), findsNothing);
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

    await tester.tap(find.text('Get Started'));
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

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_sport'), isNull);
  });
}
