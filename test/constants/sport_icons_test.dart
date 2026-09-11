// test/constants/sport_icons_test.dart
//
// Every sport used to be drawn with a basketball. These pin each sport to its
// own glyph, and a position row to the sport that position belongs to.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/constants/sport_icons.dart';

void main() {
  group('sportIcon', () {
    test('each sport gets its own icon', () {
      expect(sportIcon('Basketball'), Icons.sports_basketball_outlined);
      expect(sportIcon('Volleyball'), Icons.sports_volleyball_outlined);
      expect(sportIcon('Badminton'), Icons.sports_tennis_outlined);
    });

    test('an unknown or missing sport gets the generic icon', () {
      expect(sportIcon('Chess'), Icons.sports_outlined);
      expect(sportIcon(null), Icons.sports_outlined);
    });
  });

  group('positionIcon', () {
    test('follows the sport the position belongs to', () {
      expect(positionIcon('Setter', ['Basketball', 'Volleyball']),
          Icons.sports_volleyball_outlined);
    });

    test('falls back to the first sport before a position is picked', () {
      expect(positionIcon('', ['Badminton', 'Basketball']),
          Icons.sports_tennis_outlined);
    });

    test('ignores a position from a sport the athlete does not play', () {
      expect(positionIcon('Setter', ['Basketball']),
          Icons.sports_basketball_outlined);
    });

    test('no sports at all gets the generic icon', () {
      expect(positionIcon('', const []), Icons.sports_outlined);
    });
  });
}
