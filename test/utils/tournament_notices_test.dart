// test/utils/tournament_notices_test.dart
//
// What each team is told when a bracket game is recorded.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/tournament_notices.dart';

void main() {
  // An 8-team bracket has three rounds: quarterfinal, semifinal, final.
  ResultNotices notices({required int round, int roundCount = 3}) =>
      resultNotices(
        tournamentName: 'Mayon Cup',
        round: round,
        roundCount: roundCount,
        winnerTeam: 'Rawis Rockets',
        loserTeam: 'Bitano Bulls',
        winnerScore: 84,
        loserScore: 70,
      );

  group('resultNotices before the final', () {
    test('tells the winner which round they reached', () {
      final n = notices(round: 1).winner;

      expect(n.title, 'Advanced to the Semifinal');
      expect(n.body,
          'Rawis Rockets beat Bitano Bulls 84–70 in the Quarterfinal of Mayon Cup.');
    });

    // Each side reads the scoreline from its own point of view.
    test('tells the loser they are out, their score first', () {
      final n = notices(round: 1).loser;

      expect(n.title, 'Eliminated from Mayon Cup');
      expect(n.body,
          'Bitano Bulls lost 70–84 to Rawis Rockets in the Quarterfinal.');
    });

    test('names an early round in a big bracket', () {
      final n = notices(round: 1, roundCount: 4);

      expect(n.winner.title, 'Advanced to the Quarterfinal');
      expect(n.winner.body, contains('in the Round of 16 of Mayon Cup'));
      expect(n.loser.body, contains('in the Round of 16.'));
    });
  });

  group('resultNotices in the final', () {
    test('crowns the champion', () {
      final n = notices(round: 3).winner;

      expect(n.title, 'Champions of Mayon Cup!');
      expect(n.body, 'Rawis Rockets won the final 84–70 against Bitano Bulls.');
    });

    test('tells the other side they finished runner-up', () {
      final n = notices(round: 3).loser;

      expect(n.title, 'Runner-up in Mayon Cup');
      expect(n.body, 'Bitano Bulls lost the final 70–84 to Rawis Rockets.');
    });
  });

  group('teamRecipients', () {
    test('is the coach plus every player', () {
      expect(teamRecipients('coach', ['p1', 'p2']), ['coach', 'p1', 'p2']);
    });

    test('drops blanks and repeats', () {
      expect(teamRecipients('coach', ['p1', '', 'p1', 'coach']),
          ['coach', 'p1']);
    });

    test('still reaches the players when the coach id is missing', () {
      expect(teamRecipients('', ['p1']), ['p1']);
    });
  });
}
