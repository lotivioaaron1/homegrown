// test/register_step_alignment_test.dart
//
// Pins the registration steppers to a top-aligned layout.
//
// AnimatedSwitcher's default layoutBuilder stacks its children with
// Alignment.center, and a SingleChildScrollView shrink-wraps under a Stack's
// loose constraints. The result was that a step with little content (Coaching
// Info, Organization) floated in the middle of the screen while a step with a
// lot (the organizer's Profile step) filled the height and sat at the top —
// so the header jumped around between steps of the same flow.
//
// google_profile_setup_screen.dart carries the same layoutBuilder but is not
// covered here: it reads FirebaseAuth.instance.currentUser in its field
// initializers, so it can't be pumped without initialising Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:homegrown/screens/auth/athlete_register_screen.dart';
import 'package:homegrown/screens/auth/coach_register_screen.dart';
import 'package:homegrown/screens/auth/organizer_register_screen.dart';

void main() {
  final screens = <String, Widget>{
    'coach': const CoachRegisterScreen(),
    'athlete': const AthleteRegisterScreen(),
    'organizer': const OrganizerRegisterScreen(),
  };

  screens.forEach((name, screen) {
    testWidgets('$name registration lays its steps out from the top',
        (tester) async {
      await tester.pumpWidget(GetMaterialApp(home: screen));
      await tester.pumpAndSettle();

      final switcher =
          tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));

      // Exercise the builder the way AnimatedSwitcher does, then check where
      // it puts the child. The default builder answers Alignment.center here.
      final laidOut = switcher.layoutBuilder(const SizedBox(), const <Widget>[])
          as Stack;

      expect(laidOut.alignment, Alignment.topCenter,
          reason: 'a short step would otherwise float in the middle of the '
              'screen while a long one sat at the top');
    });
  });

  testWidgets('the current step stays on top of any outgoing step',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: CoachRegisterScreen()));
    await tester.pumpAndSettle();

    final switcher =
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
    const outgoing = SizedBox(key: ValueKey('outgoing'));
    const incoming = SizedBox(key: ValueKey('incoming'));

    final laidOut =
        switcher.layoutBuilder(incoming, const <Widget>[outgoing]) as Stack;

    // Order matters during the cross-fade: the step being animated in has to
    // paint over the one leaving, not under it.
    expect(laidOut.children.last, same(incoming));
    expect(laidOut.children.first, same(outgoing));
  });

  // Step 1 used to end with a fixed SizedBox(height: 262) to push the Next
  // button down, which only positioned it correctly on the screen it was
  // measured against. It now fills the viewport and lets a Spacer take up
  // the slack, so the button tracks the bottom of whatever screen it is on.
  group('step 1 Next button', () {
    Future<void> pumpAt(
        WidgetTester tester, Widget screen, double viewport) async {
      // Wide enough that the side-by-side name fields don't overflow under
      // the test font, which measures wider than the real one. Only the
      // height is under test here.
      await tester.binding.setSurfaceSize(Size(600, viewport));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(GetMaterialApp(home: screen));
      await tester.pumpAndSettle();
    }

    screens.forEach((name, screen) {
      testWidgets('sits at the bottom of a tall $name screen', (tester) async {
        await pumpAt(tester, screen, 900);

        final button =
            tester.getRect(find.widgetWithText(ElevatedButton, 'Next'));
        // 900 tall, less the step's 24px bottom padding.
        expect(button.bottom, moreOrLessEquals(876, epsilon: 1),
            reason: 'the button should track the bottom of the viewport, '
                'not sit a fixed distance below the last field');
      });

      testWidgets('does not overflow a short $name screen', (tester) async {
        await pumpAt(tester, screen, 480);

        // A RenderFlex overflow would surface here; the step should scroll.
        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });
    });
  });

  // Steps 2 and 3 kept the plain SingleChildScrollView that step 1 was moved
  // off, so their button sat directly under the last field with dead space
  // below it — the button jumped up the screen as you advanced through a
  // flow. They now use the same FillViewportScroll + Spacer as step 1.
  group('later steps put the button in the same place as step 1', () {
    testWidgets('athlete steps 2 and 3 track the bottom', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
          const GetMaterialApp(home: AthleteRegisterScreen()));
      await tester.pumpAndSettle();

      Future<void> fill(String hint, String value) async {
        await tester.enterText(find.widgetWithText(TextFormField, hint), value);
        await tester.pump();
      }

      await fill('First Name', 'Test');
      await fill('Last Name', 'Athlete');
      await fill('Email Address', 'test@example.com');
      // Must clear the step's own rules: 8+ chars, an uppercase and a digit.
      await fill('Password', 'Password123');
      await fill('Confirm Password', 'Password123');

      // Barangay is required to leave step 1. The picker is backed by
      // BarangayService, which falls back to a bundled list when offline —
      // which is what it does here.
      await tester.tap(find.text('Select Barangay (Legazpi City)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 3 — Athletic details'), findsOneWidget,
          reason: 'the rest of this test depends on reaching step 2');
      expect(
          tester.getRect(find.widgetWithText(ElevatedButton, 'Next')).bottom,
          moreOrLessEquals(876, epsilon: 1),
          reason: "step 2's button should sit where step 1's does, not "
              'directly under the last field');

      // Step 2 needs a sport and a years chip before it will advance.
      await tester.tap(find.text('Basketball'));
      await tester.tap(find.text('3-5 Yrs'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 3 — Photo & visibility'), findsOneWidget);
      expect(
          tester
              .getRect(find.widgetWithText(ElevatedButton, 'Create Account'))
              .bottom,
          moreOrLessEquals(876, epsilon: 1),
          reason: "step 3's Create Account button should sit at the same "
              'height as every other step button');
    });
  });
}
