// test/widgets/sport_ball_scene_test.dart
//
// The scene is pure painting, so what can go wrong is geometry: a size that
// leaves nothing to paint in, a slice of the entrance that divides by zero,
// a painter that repaints every frame whether or not anything moved. The
// look itself is judged by eye, not here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/widgets/sport_ball_scene.dart';

Widget _scene(double entrance, {bool idle = false, bool reduced = false}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: SportBallScene(
        entrance: AlwaysStoppedAnimation(entrance),
        idle: idle,
        reducedMotion: reduced,
        bleed: 24,
      ),
    );

void main() {
  for (final size in const [Size(320, 480), Size(412, 915), Size(800, 400)]) {
    testWidgets('paints every stage of the arrival at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final t in const [0.0, 0.1, 0.35, 0.5, 0.72, 0.9, 1.0]) {
        await tester.pumpWidget(_scene(t));
        expect(tester.takeException(), isNull);
      }
    });
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
