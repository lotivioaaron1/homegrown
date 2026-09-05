// test/register_screen_test.dart
//
// The signup role picker, after it gained a photographic header to match
// login's.
//
// The header was added on the strength of an arithmetic estimate — roughly
// 508px of content against ~800px of height, with a Spacer absorbing the rest.
// That is exactly the kind of reasoning that holds on a big phone and fails on
// a small one, so the overflow case below is the test that matters most here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:homegrown/screens/auth/register_screen.dart';
import 'package:homegrown/widgets/auth_hero.dart';

// GetMaterialApp, not MaterialApp: AppTheme's semantic getters switch on
// Get.isDarkMode, which needs Get's theme in scope.
Widget _host() => const GetMaterialApp(home: RegisterScreen());

/// Renders at a given logical size, undoing it afterwards so one test's
/// viewport cannot leak into the next.
Future<void> _pumpAt(WidgetTester tester, Size logical) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = logical;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_host());
  await tester.pump();
}

void main() {
  testWidgets('offers all three roles', (tester) async {
    await _pumpAt(tester, const Size(393, 851));

    expect(find.text('Athlete'), findsOneWidget);
    expect(find.text('Coach'), findsOneWidget);
    expect(find.text('Organizer'), findsOneWidget);
  });

  // findRichText, because the link is a TextSpan inside a RichText rather than
  // its own Text widget — a plain find.text walks straight past it.
  testWidgets('keeps the route back to sign-in', (tester) async {
    await _pumpAt(tester, const Size(393, 851));

    expect(find.textContaining('Sign In', findRichText: true), findsOneWidget);
  });

  testWidgets('shows the photographic header', (tester) async {
    await _pumpAt(tester, const Size(393, 851));

    expect(find.byType(AuthHero), findsOneWidget);
  });

  // Login uses the basketball frame. Using it here too would make the two
  // screens read as one screen shown twice rather than as a pair.
  testWidgets('uses a different photograph from login', (tester) async {
    await _pumpAt(tester, const Size(393, 851));

    final hero = tester.widget<AuthHero>(find.byType(AuthHero));
    expect(hero.asset, isNot(contains('basketball')));
    expect(hero.asset, contains('volleyball'));
  });

  // The cover crop is taken from the top because the ball and hands sit in the
  // upper sixth of the source frame; centred would land on the player's back.
  testWidgets('crops the photograph from the top', (tester) async {
    await _pumpAt(tester, const Size(393, 851));

    final hero = tester.widget<AuthHero>(find.byType(AuthHero));
    expect(hero.alignment, Alignment.topCenter);
  });

  group('layout', () {
    testWidgets('does not overflow on a small phone', (tester) async {
      await _pumpAt(tester, const Size(375, 667));

      expect(tester.takeException(), isNull);
    });

    testWidgets('still reaches every role and the sign-in link when small',
        (tester) async {
      await _pumpAt(tester, const Size(375, 667));

      expect(find.text('Athlete'), findsOneWidget);
      expect(find.text('Organizer'), findsOneWidget);
      expect(
          find.textContaining('Sign In', findRichText: true), findsOneWidget);
    });

    // The header is a proportion of screen height with a floor and a ceiling,
    // so a very tall device cannot let it eat the screen.
    testWidgets('caps the header height on a tall device', (tester) async {
      await _pumpAt(tester, const Size(430, 1400));

      expect(tester.getSize(find.byType(AuthHero)).height, lessThanOrEqualTo(200));
    });

    testWidgets('keeps the header off the floor on a short device',
        (tester) async {
      await _pumpAt(tester, const Size(375, 667));

      final height = tester.getSize(find.byType(AuthHero)).height;
      expect(height, greaterThanOrEqualTo(120));
      expect(height, lessThan(200));
    });
  });
}
