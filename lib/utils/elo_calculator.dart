// lib/utils/elo_calculator.dart
import 'dart:math';

const int kStartingRating = 1000;
const int _kFloorRating = 100;
const int _kFactor = 32;

/// Result of applying one match's outcome to every participant's rating.
class EloUpdateResult {
  final Map<String, int> newRatings;
  final Map<String, int> deltas;

  const EloUpdateResult({required this.newRatings, required this.deltas});
}

/// Applies a single side-vs-side Elo update.
///
/// Each side's expected result is based on the average rating of its
/// players (missing ratings default to [kStartingRating]). The base Elo
/// delta for a side is then scaled per player by how their
/// [performanceScores] entry compares to their own side's average, so a
/// standout performance moves a player's rating more than a teammate's on
/// the same win. Ratings never drop below [_kFloorRating].
EloUpdateResult calculateEloUpdate({
  required List<String> sideA,
  required List<String> sideB,
  required Map<String, int> currentRatings,
  required Map<String, double> performanceScores,
  required String winner, // 'A' | 'B'
  int kFactor = _kFactor,
}) {
  int ratingOf(String uid) => currentRatings[uid] ?? kStartingRating;

  final avgA = sideA.map(ratingOf).reduce((a, b) => a + b) / sideA.length;
  final avgB = sideB.map(ratingOf).reduce((a, b) => a + b) / sideB.length;

  final expectedA = 1 / (1 + pow(10, (avgB - avgA) / 400));
  final expectedB = 1 - expectedA;

  final actualA = winner == 'A' ? 1.0 : 0.0;
  final actualB = 1 - actualA;

  final newRatings = <String, int>{};
  final deltas = <String, int>{};

  void applySide(List<String> side, double expected, double actual) {
    final sideAvgPerf =
        side.map((uid) => performanceScores[uid] ?? 0).reduce((a, b) => a + b) /
            side.length;
    for (final uid in side) {
      final perf = performanceScores[uid] ?? 0;
      final multiplier = (1 + 0.3 * (perf - sideAvgPerf) / max(sideAvgPerf, 1))
          .clamp(0.7, 1.3);
      final delta = (kFactor * multiplier * (actual - expected)).round();
      final oldRating = ratingOf(uid);
      final newRating = max(_kFloorRating, oldRating + delta);
      deltas[uid] = newRating - oldRating;
      newRatings[uid] = newRating;
    }
  }

  applySide(sideA, expectedA, actualA);
  applySide(sideB, expectedB, actualB);

  return EloUpdateResult(newRatings: newRatings, deltas: deltas);
}
