// test/models/rating_history_entry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/models/rating_history_entry.dart';

void main() {
  group('RatingHistoryEntry', () {
    test('toMap includes every field needed to rebuild the entry', () {
      const entry = RatingHistoryEntry(
        matchId: 'm1',
        sport: 'Basketball',
        oldRating: 1000,
        newRating: 1016,
        delta: 16,
        result: 'win',
      );

      final map = entry.toMap();

      expect(map['matchId'], 'm1');
      expect(map['sport'], 'Basketball');
      expect(map['oldRating'], 1000);
      expect(map['newRating'], 1016);
      expect(map['delta'], 16);
      expect(map['result'], 'win');
    });

    test('fromMap round-trips the fields written by toMap', () {
      final rebuilt = RatingHistoryEntry.fromMap({
        'matchId': 'm1',
        'sport': 'Basketball',
        'oldRating': 1000,
        'newRating': 984,
        'delta': -16,
        'result': 'loss',
      });

      expect(rebuilt.newRating, 984);
      expect(rebuilt.delta, -16);
      expect(rebuilt.result, 'loss');
    });
  });
}
