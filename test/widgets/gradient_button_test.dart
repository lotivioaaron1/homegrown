// test/widgets/gradient_button_test.dart
//
// Covers the primary call to action introduced with the login redesign.
//
// LoginScreen itself cannot be pumped: it resolves AuthController in a field
// initializer, and that controller touches FirebaseFirestore.instance and
// FirebaseAuth.instance on construction, so it needs a live Firebase. The same
// limitation is recorded for google_profile_setup_screen.dart at
// register_step_alignment_test.dart:12-14. Testing the button on its own is
// what is reachable without adding Firebase mocks to the project.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:homegrown/widgets/gradient_button.dart';

// GetMaterialApp, not MaterialApp: AppTheme's semantic getters switch on
// Get.isDarkMode, which needs Get's theme in scope.
Widget _host({required VoidCallback? onPressed}) => GetMaterialApp(
      home: Scaffold(
        body: Center(
          child: GradientButton(
            onPressed: onPressed,
            child: const Text('Sign In'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders its label', (tester) async {
    await tester.pumpWidget(_host(onPressed: () {}));

    expect(find.text('Sign In'), findsOneWidget);
  });

  // Taps the InkWell rather than the GradientButton: the outer finder resolves
  // to the AnimatedScale's Transform, which flutter_test warns about hit
  // testing through even when the tap lands correctly.
  testWidgets('fires onPressed when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(onPressed: () => taps++));

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  // A null handler has to make the control genuinely inert, not merely
  // unstyled — a button that looks tappable and does nothing invites a
  // second tap and reads as a broken app.
  testWidgets('does nothing when disabled', (tester) async {
    await tester.pumpWidget(_host(onPressed: null));

    await tester.tap(find.byType(GradientButton), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.onTap, isNull);
  });

  testWidgets('drops the gradient when disabled', (tester) async {
    await tester.pumpWidget(_host(onPressed: null));

    final ink = tester.widget<Ink>(find.byType(Ink));
    final decoration = ink.decoration as BoxDecoration;

    expect(decoration.gradient, isNull,
        reason: 'a disabled button must not wear the primary fill');
    expect(decoration.color, isNotNull);
  });

  testWidgets('wears the gradient when enabled', (tester) async {
    await tester.pumpWidget(_host(onPressed: () {}));

    final ink = tester.widget<Ink>(find.byType(Ink));
    final decoration = ink.decoration as BoxDecoration;

    expect(decoration.gradient, isNotNull);
  });

  // The press dip is feedback, so it must not move the button's bounds and
  // must return to rest. AnimatedScale keeps layout stable by construction.
  testWidgets('dips while pressed and returns to rest', (tester) async {
    await tester.pumpWidget(_host(onPressed: () {}));

    double currentScale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    expect(currentScale(), 1.0);

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(GradientButton)));
    await tester.pump();
    expect(currentScale(), lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(currentScale(), 1.0);
  });

  testWidgets('does not dip when disabled', (tester) async {
    await tester.pumpWidget(_host(onPressed: null));

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(GradientButton)));
    await tester.pump();

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  // 54px clears both the 44pt iOS and 48dp Android minimums.
  testWidgets('meets the minimum touch target height', (tester) async {
    await tester.pumpWidget(_host(onPressed: () {}));

    expect(tester.getSize(find.byType(GradientButton)).height,
        greaterThanOrEqualTo(48.0));
  });
}
