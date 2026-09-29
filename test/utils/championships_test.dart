// test/utils/championships_test.dart
//
// Who a tournament title belongs to, and which titles each showcase lists.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/models/tournament.dart';
import 'package:homegrown/utils/championships.dart';
import 'package:homegrown/utils/tournament_notices.dart';

Tournament _cup(
  String id, {
  String status = Tournament.statusCompleted,
  String? champion = 'coachA',
  DateTime? completedAt,
}) =>
    Tournament(
      id: id,
      organizerId: 'org',
      name: 'Cup $id',
      sport: 'Basketball',
      status: status,
      championCoachId: status == Tournament.statusCompleted ? champion : null,
      championTeamName: 'Rawis Rockets',
      completedAt: completedAt ?? DateTime(2026, 9, 29),
      entrants: const [
        TournamentEntrant(
          seed: 1,
          coachId: 'coachA',
          teamName: 'Rawis Rockets',
          players: [
            EntrantPlayer(uid: 'a1', fullName: 'A One'),
            EntrantPlayer(uid: 'a2', fullName: 'A Two'),
          ],
        ),
        TournamentEntrant(
          seed: 2,
          coachId: 'coachB',
          teamName: 'Bitano Bulls',
          players: [EntrantPlayer(uid: 'b1', fullName: 'B One')],
        ),
      ],
    );

List<String> _ids(List<Tournament> ts) => ts.map((t) => t.id).toList();

void main() {
  group('isChampion', () {
    test('credits the champion coach', () {
      expect(isChampion(_cup('1'), 'coachA'), isTrue);
    });

    test("credits every player on the champion's entered roster", () {
      expect(isChampion(_cup('1'), 'a1'), isTrue);
      expect(isChampion(_cup('1'), 'a2'), isTrue);
    });

    test('does not credit the runner-up or its coach', () {
      expect(isChampion(_cup('1'), 'b1'), isFalse);
      expect(isChampion(_cup('1'), 'coachB'), isFalse);
    });

    test('credits nobody before the final is played', () {
      final running = _cup('1', status: Tournament.statusActive);

      expect(isChampion(running, 'coachA'), isFalse);
      expect(isChampion(running, 'a1'), isFalse);
    });

    test('credits nobody for a blank id', () {
      expect(isChampion(_cup('1'), ''), isFalse);
    });
  });

  group('titlesFor', () {
    test('lists only the titles someone won, newest first', () {
      final titles = titlesFor([
        _cup('old', completedAt: DateTime(2026, 5, 1)),
        _cup('lost', champion: 'coachB'),
        _cup('new', completedAt: DateTime(2026, 9, 29)),
      ], 'a1');

      expect(_ids(titles), ['new', 'old']);
    });
  });

  group('teamTitles', () {
    test("lists the titles a coach's team won", () {
      final titles = teamTitles([
        _cup('won'),
        _cup('lost', champion: 'coachB'),
        _cup('running', status: Tournament.statusActive),
      ], 'coachA');

      expect(_ids(titles), ['won']);
    });
  });

  group('recentChampions', () {
    final now = DateTime(2026, 9, 30, 12);

    test('keeps titles won in the last week, newest first', () {
      final recent = recentChampions([
        _cup('two days', completedAt: DateTime(2026, 9, 28)),
        _cup('yesterday', completedAt: DateTime(2026, 9, 29)),
        _cup('last month', completedAt: DateTime(2026, 8, 30)),
      ], now: now);

      expect(_ids(recent), ['yesterday', 'two days']);
    });

    test('drops a tournament still being played', () {
      final recent = recentChampions(
          [_cup('running', status: Tournament.statusActive)],
          now: now);

      expect(recent, isEmpty);
    });
  });

  group('titleCountLabel', () {
    test('says Champion once, then counts', () {
      expect(titleCountLabel(1), 'Champion');
      expect(titleCountLabel(3), '3× Champion');
    });
  });

  group('isChampionNotice', () {
    test('recognises the champion notification the app sends', () {
      final notices = resultNotices(
        tournamentName: 'Mayon Cup',
        round: 3,
        roundCount: 3,
        winnerTeam: 'Rawis Rockets',
        loserTeam: 'Bitano Bulls',
        winnerScore: 84,
        loserScore: 70,
      );

      expect(isChampionNotice(notices.winner.title), isTrue);
      expect(isChampionNotice(notices.loser.title), isFalse);
    });

    test('ignores a win in an earlier round', () {
      expect(isChampionNotice("Congratulations! You're in the Final"), isFalse);
    });
  });
}
