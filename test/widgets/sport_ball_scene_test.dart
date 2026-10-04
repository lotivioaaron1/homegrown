// test/widgets/sport_ball_scene_test.dart
//
// The scene is pure painting, so what can go wrong is geometry: a size that
// leaves nothing to paint in, a slice of the entrance that divides by zero,
// a painter that repaints every frame whether or not anything moved. The
// look itself is judged by eye, not here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/widgets/sport_ball_scene.dart';

Widget _scene(double entrance,
        {bool idle = false,
        bool reduced = false,
        SportBallLayout layout = SportBallLayout.overHeadline}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: SportBallScene(
        entrance: AlwaysStoppedAnimation(entrance),
        idle: idle,
        reducedMotion: reduced,
        bleed: 24,
        layout: layout,
      ),
    );

void main() {
  for (final layout in SportBallLayout.values) {
    for (final size in const [Size(320, 480), Size(412, 915), Size(800, 400)]) {
      testWidgets('paints every stage of the arrival, ${layout.name}, at $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        // 0.33 is the basketball's first touchdown, where it squashes.
        for (final t in const [0.0, 0.1, 0.33, 0.35, 0.5, 0.72, 0.9, 1.0]) {
          await tester.pumpWidget(_scene(t, layout: layout));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('paints nothing, without failing, in a box with no height',
      (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [
        SizedBox(
          height: 0,
          child: SportBallScene(entrance: AlwaysStoppedAnimation(1)),
        ),
      ]),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('drifts while idle and stops when it no longer is',
      (tester) async {
    await tester.pumpWidget(_scene(1, idle: true));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(_scene(1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('holds still when motion is reduced, even while idle',
      (tester) async {
    await tester.pumpWidget(_scene(1, idle: true, reduced: true));
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('BounceCurve', () {
    test('with a restitution of 0.5 and three bounces it is Curves.bounceOut',
        () {
      // Penner's classic bounce is exactly this physics — each rebound a
      // quarter as high and half as long as the one before — so Flutter's own
      // implementation is an independent check on the general formula.
      const curve = BounceCurve(restitution: 0.5, bounces: 3);
      for (var i = 0; i <= 200; i++) {
        final t = i / 200;
        expect(curve.transform(t),
            closeTo(Curves.bounceOut.transform(t), 1e-9),
            reason: 't = $t');
      }
    });

    test('a softer ball lands later in its slice and rebounds lower', () {
      // Worked by hand: 1 + 2(0.42 + 0.42²) = 2.1928 fall-lengths in all, so
      // the first touchdown is at 1 / 2.1928, and the first hop climbs back
      // 0.42² = 17.64% of the drop, peaking halfway through it at
      // (1 + 0.42) / 2.1928.
      const curve = BounceCurve(restitution: 0.42, bounces: 2);
      expect(curve.landing, closeTo(0.4560, 1e-4));
      expect(curve.transform(0.44), lessThan(1.0));
      expect(curve.transform(curve.landing), closeTo(1.0, 1e-9));
      expect(curve.transform(0.6476), closeTo(0.8236, 1e-3));
    });

    test('never carries a ball past where it comes to rest', () {
      // Over 1 would draw the ball below its resting point, down towards the
      // wordmark underneath.
      const curve = BounceCurve(restitution: 0.42, bounces: 2);
      for (var i = 0; i <= 1000; i++) {
        expect(curve.transform(i / 1000), lessThanOrEqualTo(1.0));
      }
    });

    test('impact lands on each touchdown, hardest first, and never at rest',
        () {
      const curve = BounceCurve(restitution: 0.5, bounces: 3);
      // Touchdowns fall at 1, 2 and 2.5 of the 2.75 fall-lengths, each hit
      // half as hard as the last.
      expect(curve.impact(1 / 2.75), closeTo(1.0, 1e-9));
      expect(curve.impact(2 / 2.75), closeTo(0.5, 1e-9));
      expect(curve.impact(2.5 / 2.75), closeTo(0.25, 1e-9));
      // In the air: mid-fall, and the top of the first hop.
      expect(curve.impact(0.2), 0.0);
      expect(curve.impact(1.5 / 2.75), 0.0);
      // The final settle is not a hit: a ball at rest is round.
      expect(curve.impact(1.0), 0.0);
    });
  });

  test('repaints only when what it shows has changed', () {
    const a = SportBallScenePainter(entrance: 0.5, drift: 0.2, bleed: 24);

    expect(
      a.shouldRepaint(
          const SportBallScenePainter(entrance: 0.5, drift: 0.2, bleed: 24)),
      isFalse,
    );
    expect(
      a.shouldRepaint(
          const SportBallScenePainter(entrance: 0.6, drift: 0.2, bleed: 24)),
      isTrue,
    );
    expect(
      a.shouldRepaint(
          const SportBallScenePainter(entrance: 0.5, drift: 0.3, bleed: 24)),
      isTrue,
    );
  });
}
