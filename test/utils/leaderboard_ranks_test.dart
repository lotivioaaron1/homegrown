// test/utils/leaderboard_ranks_test.dart
//
// Rank numbering for the leaderboard and the City Rank badge. The bug this
// guards against is real: with no stats recorded anywhere, every athlete tied
// on zero and was shown as "#1".

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/leaderboard_ranks.dart';

List<int?> _ranks(List<int> values, {Set<int> unrankedAt = const {}}) {
  final indexed = List.generate(values.length, (i) => i);
  return assignRanks<int>(
    indexed,
    valueOf: (i) => values[i],
    isUnranked: (i) => unrankedAt.contains(i),
  );
}

void main() {
  group('cityRankLabel', () {
    test('zero points is unranked, not first', () {
      expect(cityRankLabel(points: 0, rank: 1), '—');
    });

    test('negative points is unranked', () {
      expect(cityRankLabel(points: -3, rank: 1), '—');
    });

    test('shows the rank once there are points', () {
      expect(cityRankLabel(points: 12, rank: 3), '#3');
    });

    test('a scored athlete whose rank is still loading gets a placeholder', () {
      expect(cityRankLabel(points: 12), '#—');
    });
  });

  group('assignRanks', () {
    test('numbers a strictly ordered board 1..n', () {
      expect(_ranks([50, 40, 30]), [1, 2, 3]);
    });

    test('ties share a rank and consume the numbers behind them', () {
      expect(_ranks([50, 40, 40, 10]), [1, 2, 2, 4]);
    });

    test('a tie for first', () {
      expect(_ranks([40, 40, 10]), [1, 1, 3]);
    });

    test('unranked entries get no number', () {
      expect(_ranks([50, 40, 0, 0], unrankedAt: {2, 3}), [1, 2, null, null]);
    });

    test('an everyone-on-zero board has no ranks at all', () {
      expect(_ranks([0, 0, 0], unrankedAt: {0, 1, 2}), [null, null, null]);
    });

    test('an unranked entry out of place does not shift the others', () {
      expect(_ranks([50, 0, 40], unrankedAt: {1}), [1, null, 2]);
    });

    test('an unranked entry does not form a tie with the next ranked one', () {
      expect(_ranks([50, 50, 50], unrankedAt: {1}), [1, null, 1]);
    });

    test('works without an isUnranked callback', () {
      final ranks = assignRanks<int>([30, 20, 20], valueOf: (v) => v);
      expect(ranks, [1, 2, 2]);
    });

    test('an empty board', () {
      expect(_ranks([]), isEmpty);
    });
  });
}
