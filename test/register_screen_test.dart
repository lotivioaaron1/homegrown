// test/register_screen_test.dart
//
// The signup role picker.
//
// It briefly carried a photographic header, added so signup would read as
// login's sibling. That was removed by preference: this screen is a set of
// choices and the cards should carry it, rather than borrowing the
// hero-and-sheet construction from the screen before it. The absence is
// asserted below so it does not drift back in.

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

  testWidgets('carries no photographic header', (tester) async {
    await _pumpAt(tester, const Size(393, 851));

    expect(find.byType(AuthHero), findsNothing,
        reason: 'this screen keeps its own plain ground rather than login\'s '
            'hero construction');
    expect(find.byType(Image), findsNothing);
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

    // The Spacer only has room to work inside a bounded height, which is what
    // FillViewportScroll gives it. Without that the link would sit directly
    // under the last card on a tall screen instead of near the bottom.
    testWidgets('pushes the sign-in link toward the bottom when there is room',
        (tester) async {
      await _pumpAt(tester, const Size(430, 1000));

      final linkY = tester
          .getCenter(find.textContaining('Sign In', findRichText: true))
          .dy;
      final lastCardY = tester.getBottomLeft(find.text('Organizer')).dy;

      expect(linkY, greaterThan(lastCardY + 200),
          reason: 'the Spacer should be doing its job');
    });
  });
}
