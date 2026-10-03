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
    test('congratulates the winner and names the round they reached', () {
      final n = notices(round: 1).winner;

      expect(n.title, "Congratulations! You're in the Semifinal");
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

      expect(n.winner.title, "Congratulations! You're in the Quarterfinal");
      expect(n.winner.body, contains('in the Round of 16 of Mayon Cup'));
      expect(n.loser.body, contains('in the Round of 16.'));
    });
  });

  group('resultNotices in the final', () {
    test('congratulates the champion', () {
      final n = notices(round: 3).winner;

      expect(n.title, 'Congratulations, champions of Mayon Cup!');
      expect(n.body, 'Rawis Rockets won the final 84–70 against Bitano Bulls.');
    });

    test('tells the other side they finished runner-up', () {
      final n = notices(round: 3).loser;

      expect(n.title, 'Runner-up in Mayon Cup');
      expect(n.body, 'Bitano Bulls lost the final 70–84 to Rawis Rockets.');
    });
  });

  // Sent to each team when the organizer sets a matchup's kickoff.
  group('scheduledNotice', () {
    final kickoff = DateTime(2026, 9, 29, 17, 30); // a Tuesday

    Notice scheduled({
      int round = 2,
      int roundCount = 3,
      String team = 'Rawis Rockets',
      String opponent = 'Bitano Bulls',
      String venue = 'Albay Astrodome',
    }) =>
        scheduledNotice(
          round: round,
          roundCount: roundCount,
          team: team,
          opponent: opponent,
          kickoff: kickoff,
          venue: venue,
        );

    test('names the round in the title', () {
      expect(scheduled(round: 2).title, 'Semifinal scheduled');
      expect(scheduled(round: 3).title, 'Final scheduled');
      expect(scheduled(round: 1, roundCount: 4).title,
          'Round of 16 scheduled');
    });

    test('gives the opponent, kickoff and venue', () {
      expect(scheduled().body,
          'Rawis Rockets vs Bitano Bulls · Tue, Sep 29 · 5:30 PM at Albay Astrodome');
    });

    test("puts the team's own name first", () {
      expect(scheduled(team: 'Bitano Bulls', opponent: 'Rawis Rockets').body,
          startsWith('Bitano Bulls vs Rawis Rockets'));
    });

    test('leaves the venue out when there is none', () {
      expect(scheduled(venue: ' ').body,
          'Rawis Rockets vs Bitano Bulls · Tue, Sep 29 · 5:30 PM');
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
