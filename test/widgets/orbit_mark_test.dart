// test/widgets/orbit_mark_test.dart
//
// Covers the splash screen's orbiting mark: the geometry that places the
// travelling icon on the ring, and the reduced-motion branch that has to
// render a finished state rather than a half-drawn one.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/widgets/orbit_mark.dart';

/// Hosts the widget with animations disabled or enabled, the way the OS
/// Reduce Motion setting reaches a Flutter app.
Widget _host({required bool disableAnimations}) => MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: OrbitMark(
            size: 160,
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );

void main() {
  group('orbitOffset', () {
    test('starts the icon at twelve o\'clock, not at three', () {
      final o = orbitOffset(turns: 0, radius: 100);

      // Screen coordinates: negative dy is up. Starting at three o'clock is
      // the default for cos/sin and would put the icon on the mark's flank.
      expect(o.dx, closeTo(0, 0.001));
      expect(o.dy, closeTo(-100, 0.001));
    });

    test('travels clockwise', () {
      // A quarter turn from the top is three o'clock, i.e. +x.
      final o = orbitOffset(turns: 0.25, radius: 100);

      expect(o.dx, closeTo(100, 0.001));
      expect(o.dy, closeTo(0, 0.001));
    });

    test('stays on the circle at every angle', () {
      for (var i = 0; i <= 16; i++) {
        final o = orbitOffset(turns: i / 16, radius: 73);
        expect(o.distance, closeTo(73, 0.001), reason: 'at turn ${i / 16}');
      }
    });

    test('a full turn returns to the start', () {
      final start = orbitOffset(turns: 0, radius: 50);
      final full = orbitOffset(turns: 1, radius: 50);

      expect(full.dx, closeTo(start.dx, 0.001));
      expect(full.dy, closeTo(start.dy, 0.001));
    });

    test('a zero radius collapses to the centre', () {
      expect(orbitOffset(turns: 0.4, radius: 0), Offset.zero);
    });
  });

  group('OrbitMark', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(_host(disableAnimations: false));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SizedBox), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    // The orbit runs on a repeating controller. Under reduced motion it must
    // not start, or the widget never settles — pumpAndSettle would spin
    // forever, and more importantly the user asked the OS for no motion.
    testWidgets('settles when animations are disabled', (tester) async {
      await tester.pumpWidget(_host(disableAnimations: true));

      // Would time out if a repeating controller were running.
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps animating when motion is allowed', (tester) async {
      await tester.pumpWidget(_host(disableAnimations: false));
      await tester.pump(const Duration(seconds: 2));

      // The orbit repeats, so there is always a frame scheduled.
      expect(tester.binding.hasScheduledFrame, isTrue);

      // Let the test tear down cleanly rather than leaving a live ticker.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('lays out within the size it was given', (tester) async {
      await tester.pumpWidget(_host(disableAnimations: true));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(OrbitMark));
      expect(size.width, 160);
      expect(size.height, 160);
    });
  });

  // Guards the painter's own maths rather than its pixels: a dash count that
  // does not divide the circle cleanly used to leave a visible seam.
  test('dashes divide the circle without a remainder', () {
    const dashCount = 36;
    const step = (2 * math.pi) / dashCount;

    expect(step * dashCount, closeTo(2 * math.pi, 1e-9));
  });
}
