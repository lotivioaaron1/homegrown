// test/utils/match_players_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Event details shows one score. An event takes one result now, but a game
  // recorded twice before that rule still holds two.
  group('latestMatch', () {
    Map<String, dynamic> recorded(String id, DateTime? at) => {
          'id': id,
          'createdAt': at == null ? null : Timestamp.fromDate(at),
        };

    String? latestId(List<Map<String, dynamic>> matches) =>
        latestMatch(matches, data: (m) => m)?['id'] as String?;

    test('is null when nothing has been recorded', () {
      expect(latestId([]), isNull);
    });

    test('picks the most recently recorded match', () {
      expect(
          latestId([
            recorded('first', DateTime(2026, 9, 24, 18)),
            recorded('second', DateTime(2026, 9, 24, 19)),
            recorded('oldest', DateTime(2026, 9, 1)),
          ]),
          'second');
    });

    // A match saved moments ago has no server timestamp yet.
    test('treats a match still waiting for its timestamp as the newest', () {
      expect(
          latestId([
            recorded('earlier', DateTime(2026, 9, 24)),
            recorded('just now', null),
          ]),
          'just now');
    });
  });
}
