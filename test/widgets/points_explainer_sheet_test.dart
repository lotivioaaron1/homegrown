// test/widgets/points_explainer_sheet_test.dart
//
// The "How points work" sheet restates the scoring weights for athletes. If
// stat_scoring.dart is retuned and the sheet is not, athletes are told the
// wrong thing — these tests fail the moment the two drift apart.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/stat_scoring.dart';
import 'package:homegrown/widgets/points_explainer_sheet.dart';

void main() {
  test('covers every sport the app scores', () {
    expect(kPointWeights.keys.toSet(), {'Basketball', 'Volleyball', 'Badminton'});
  });

  for (final entry in kPointWeights.entries) {
    final sport = entry.key;
    for (final w in entry.value) {
      test('$sport: ${w.label} is worth ${w.perUnit}', () {
        if (w.statKey == 'matchWon') {
          expect(calcPointsAwarded(sport, {'matchWon': true}),
              w.perUnit.round());
          return;
        }
        if (w.perUnit >= 0) {
          // Two units, so half-point weights land on whole numbers and the
          // rounding in calcPointsAwarded cannot hide a mismatch.
          expect(calcPointsAwarded(sport, {w.statKey: 2}),
              (w.perUnit * 2).round());
          return;
        }
        // A penalty is clamped at zero on its own, so measure it against a
        // positive base: a large number of the sport's first positive stat.
        final base = entry.value.firstWhere((o) => o.perUnit > 0);
        final withPenalty =
            calcPointsAwarded(sport, {base.statKey: 100, w.statKey: 2});
        final without = calcPointsAwarded(sport, {base.statKey: 100});
        expect(withPenalty - without, (w.perUnit * 2).round());
      });
    }
  }
}
