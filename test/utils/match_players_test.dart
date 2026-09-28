// test/utils/match_players_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/match_players.dart';

void main() {
  final match = {
    'sideA': ['a1', 'a2'],
    'sideB': ['b1'],
    'scoreA': 84,
    'scoreB': 90,
  };

  group('playersInMatch', () {
    test('keeps only players recorded on either side, in event order', () {
      final players = [
        {'uid': 'b1'}, {'uid': 'sat'}, {'uid': 'a2'}, {'uid': 'a1'},
      ];
      expect(playersInMatch(players, match).map((p) => p['uid']),
          ['b1', 'a2', 'a1']);
    });

    test('drops a player who sat the match out', () {
      expect(playersInMatch([{'uid': 'sat'}], match), isEmpty);
    });

    test('handles a match doc missing its sides', () {
      expect(playersInMatch([{'uid': 'a1'}], const {}), isEmpty);
    });
  });

  group('matchLabel', () {
    test('reads as a scoreline between the two team names', () {
      expect(matchLabel(match, nameA: 'Warriors', nameB: 'Tigers'),
          'Warriors 84 — 90 Tigers');
    });
  });
}
