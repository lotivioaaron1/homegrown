// test/utils/elo_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/elo_calculator.dart';

void main() {
  group('calculateEloUpdate', () {
    test('moves an evenly-matched winner up by roughly half the K-factor', () {
      final result = calculateEloUpdate(
        sideA: ['a1'],
        sideB: ['b1'],
        currentRatings: {'a1': 1000, 'b1': 1000},
        performanceScores: {'a1': 20, 'b1': 20},
        winner: 'A',
      );

      // expected = 0.5, actual = 1 -> delta = round(32 * 1.0 * 0.5) = 16
      expect(result.newRatings['a1'], 1016);
      expect(result.newRatings['b1'], 984);
      expect(result.deltas['a1'], 16);
      expect(result.deltas['b1'], -16);
    });

    test('gives a heavy underdog a bigger rating jump than a heavy favorite', () {
      final result = calculateEloUpdate(
        sideA: ['a1'],
        sideB: ['b1'],
        currentRatings: {'a1': 1200, 'b1': 800},
        performanceScores: {'a1': 20, 'b1': 20},
        winner: 'B',
      );

      final underdogGain = result.deltas['b1']!;
      final favoriteWinGain = calculateEloUpdate(
        sideA: ['a1'],
        sideB: ['b1'],
        currentRatings: {'a1': 1200, 'b1': 800},
        performanceScores: {'a1': 20, 'b1': 20},
        winner: 'A',
      ).deltas['a1']!;

      expect(underdogGain, greaterThan(favoriteWinGain));
    });

    test('boosts an above-average performer\'s delta beyond a teammate\'s', () {
      final result = calculateEloUpdate(
        sideA: ['a1', 'a2'],
        sideB: ['b1', 'b2'],
        currentRatings: {'a1': 1000, 'a2': 1000, 'b1': 1000, 'b2': 1000},
        performanceScores: {'a1': 40, 'a2': 10, 'b1': 20, 'b2': 20},
        winner: 'A',
      );

      expect(result.deltas['a1']!, greaterThan(result.deltas['a2']!));
    });

    test('never drops a rating below the floor of 100', () {
      // a1 is (artificially) a near-certain favorite over b1 but loses,
      // producing close to the maximum possible single-match loss
      // (~K * 1.3 ≈ 42) -- more than enough to push 120 under the floor.
      final result = calculateEloUpdate(
        sideA: ['a1'],
        sideB: ['b1'],
        currentRatings: {'a1': 120, 'b1': -3000},
        performanceScores: {'a1': 5, 'b1': 20},
        winner: 'B',
      );

      expect(result.newRatings['a1'], 100);
    });

    test('defaults an unrated player to a starting rating of 1000', () {
      final result = calculateEloUpdate(
        sideA: ['a1'],
        sideB: ['b1'],
        currentRatings: {'b1': 1000},
        performanceScores: {'a1': 20, 'b1': 20},
        winner: 'A',
      );

      expect(result.deltas['a1'], 16);
    });
  });
}
