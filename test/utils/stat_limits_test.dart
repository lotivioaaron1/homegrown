// test/utils/stat_limits_test.dart
//
// What a stat line may not exceed: a player's points (or badminton sets) are
// capped by their team's final score, and basketball teammates share it.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/stat_limits.dart';

// Rockets beat Bulls 84–70.
final _match = {
  'sideA': ['a1', 'a2', 'a3'],
  'sideB': ['b1', 'b2'],
  'scoreA': 84,
  'scoreB': 70,
  'winner': 'A',
};

ScoreCap? _cap(String athleteId,
        {String sport = 'Basketball',
        Map<String, int> entered = const {},
        Map<String, dynamic>? match}) =>
    scoreCapFor(
      sport: sport,
      match: match ?? _match,
      athleteId: athleteId,
      nameA: 'Rockets',
      nameB: 'Bulls',
      enteredByAthlete: entered,
    );

void main() {
  group('basketball points', () {
    test("caps a player at their team's score", () {
      final cap = _cap('a1')!;

      expect(cap.teamScore, 84);
      expect(cap.statKey, 'points');
      expect(scoreCapError(cap, 84), isNull);
      expect(scoreCapError(cap, 100),
          'Rockets scored 84, so no player can have more than 84 points.');
    });

    test('uses the score of the side the player was on', () {
      expect(_cap('b1')!.teamScore, 70);
      expect(_cap('b1')!.teamName, 'Bulls');
    });

    test('shares the score with teammates already entered', () {
      final cap = _cap('a3', entered: {'a1': 40, 'a2': 20, 'b1': 50})!;

      expect(cap.teammatesTotal, 60);
      expect(cap.remaining, 24);
      expect(scoreCapError(cap, 24), isNull);
      expect(scoreCapError(cap, 30),
          "Only 24 of Rockets' 84 points are left: 60 are already entered "
          'for teammates.');
    });

    // Re-entering a player mustn't count their own earlier line against them.
    test("leaves the player's own saved line out of the teammates' total", () {
      expect(_cap('a1', entered: {'a1': 40, 'a2': 20})!.teammatesTotal, 20);
    });

    test('shows how much is left while typing', () {
      expect(scoreCapHint(_cap('a1')!), 'Up to 84 points · Rockets scored 84');
      expect(scoreCapHint(_cap('a3', entered: {'a1': 40, 'a2': 20})!),
          'Up to 24 points · Rockets scored 84, 60 entered for teammates');
    });

    test('never shows a negative amount left', () {
      expect(_cap('a3', entered: {'a1': 60, 'a2': 30})!.remaining, 0);
    });
  });

  group('badminton sets', () {
    // Doubles, won 2–1 in sets.
    final sets = {
      'sideA': ['a1', 'a2'],
      'sideB': ['b1', 'b2'],
      'scoreA': 2,
      'scoreB': 1,
      'winner': 'A',
    };

    test("caps Sets Won at the side's sets", () {
      final cap = _cap('a1', sport: 'Badminton', match: sets)!;

      expect(cap.statKey, 'setsWon');
      expect(scoreCapError(cap, 2), isNull);
      expect(scoreCapError(cap, 3),
          "Rockets won 2 sets, so Sets Won can't be more than 2.");
      expect(scoreCapHint(cap), 'Rockets won 2 sets');
    });

    // Both partners won the same sets, so nothing is shared.
    test("ignores a partner's entry", () {
      final cap =
          _cap('a2', sport: 'Badminton', match: sets, entered: {'a1': 2})!;

      expect(cap.remaining, 2);
      expect(scoreCapError(cap, 2), isNull);
    });
  });

  group('no cap', () {
    test('for volleyball', () {
      expect(_cap('a1', sport: 'Volleyball'), isNull);
    });

    test('for a player who was on neither side', () {
      expect(_cap('sat-out'), isNull);
    });
  });

  group('matchWonFor', () {
    test('is true on the winning side and false on the other', () {
      expect(matchWonFor(_match, 'a2'), isTrue);
      expect(matchWonFor(_match, 'b1'), isFalse);
    });

    test('is null for a player on neither side', () {
      expect(matchWonFor(_match, 'sat-out'), isNull);
    });
  });
}
