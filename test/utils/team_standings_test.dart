// test/utils/team_standings_test.dart
//
// A team's record for a season: which games count, how teams are ordered,
// and where one season ends and the next begins.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/team_standings.dart';

final _played = DateTime.utc(2026, 6, 1, 4);

Map<String, dynamic> _event({
  String? type = 'Liga game',
  String status = 'completed',
  String? coachA = 'coachA',
  String? coachB = 'coachB',
  String nameA = 'Rawis Rockets',
  String nameB = 'Bitano Bulls',
}) =>
    {
      'eventType': type,
      'status': status,
      'teamACoachId': coachA,
      'teamBCoachId': coachB,
      'teamAName': nameA,
      'teamBName': nameB,
    };

Map<String, dynamic> _match(int scoreA, int scoreB) =>
    {'scoreA': scoreA, 'scoreB': scoreB};

StandingsGame _game(
  String coachA,
  String coachB,
  int scoreA,
  int scoreB, {
  DateTime? playedAt,
  String? nameA,
  String? nameB,
}) =>
    StandingsGame(
      coachA: coachA,
      coachB: coachB,
      nameA: nameA ?? 'Team $coachA',
      nameB: nameB ?? 'Team $coachB',
      scoreA: scoreA,
      scoreB: scoreB,
      playedAt: playedAt ?? _played,
    );

void main() {
  group('standingsGameFrom', () {
    test('a Liga game counts', () {
      final g = standingsGameFrom(
          event: _event(), match: _match(80, 72), playedAt: _played)!;
      expect(g.coachA, 'coachA');
      expect(g.coachB, 'coachB');
      expect(g.nameA, 'Rawis Rockets');
      expect(g.scoreA, 80);
      expect(g.scoreB, 72);
    });

    test('a tournament game counts', () {
      expect(
          standingsGameFrom(
              event: _event(type: 'Tournament'),
              match: _match(60, 61),
              playedAt: _played),
          isNotNull);
    });

    test('an event saved with no type still counts, as it does for Elo', () {
      expect(
          standingsGameFrom(
              event: _event(type: null), match: _match(2, 1), playedAt: _played),
          isNotNull);
    });

    test('a tune-up does not count', () {
      expect(
          standingsGameFrom(
              event: _event(type: 'Tune-up'),
              match: _match(80, 72),
              playedAt: _played),
          isNull);
    });

    test('the old Friendly type does not count either', () {
      expect(
          standingsGameFrom(
              event: _event(type: 'Friendly'),
              match: _match(80, 72),
              playedAt: _played),
          isNull);
    });

    test('a cancelled event does not count', () {
      expect(
          standingsGameFrom(
              event: _event(status: 'cancelled'),
              match: _match(80, 72),
              playedAt: _played),
          isNull);
    });

    test('a side with no coach does not count (older events, singles)', () {
      for (final event in [
        _event(coachA: null),
        _event(coachB: null),
        _event(coachA: ''),
      ]) {
        expect(
            standingsGameFrom(
                event: event, match: _match(80, 72), playedAt: _played),
            isNull);
      }
    });

    test('a coach on both sides does not count', () {
      expect(
          standingsGameFrom(
              event: _event(coachB: 'coachA'),
              match: _match(80, 72),
              playedAt: _played),
          isNull);
    });

    test('a missing or tied score does not count', () {
      expect(
          standingsGameFrom(
              event: _event(), match: {'scoreA': 80}, playedAt: _played),
          isNull);
      expect(
          standingsGameFrom(
              event: _event(), match: _match(70, 70), playedAt: _played),
          isNull);
    });

    test('a malformed document is skipped rather than throwing', () {
      expect(
          standingsGameFrom(
              event: {..._event(), 'teamACoachId': 42},
              match: _match(80, 72),
              playedAt: _played),
          isNull);
      expect(
          standingsGameFrom(
              event: _event(),
              match: {'scoreA': '80', 'scoreB': 72},
              playedAt: _played),
          isNull);
    });

    test('an event with no date does not count', () {
      expect(
          standingsGameFrom(
              event: _event(), match: _match(80, 72), playedAt: null),
          isNull);
    });
  });

  group('computeStandings', () {
    test('adds up wins, losses and points across games', () {
      final table = computeStandings([
        _game('a', 'b', 80, 70),
        _game('b', 'a', 65, 60),
        _game('a', 'c', 90, 50),
      ]);
      final a = table.firstWhere((s) => s.coachId == 'a');
      expect(a.wins, 2);
      expect(a.losses, 1);
      expect(a.played, 3);
      expect(a.pointsFor, 80 + 60 + 90);
      expect(a.pointsAgainst, 70 + 65 + 50);
      expect(a.diff, 230 - 185);

      final c = table.firstWhere((s) => s.coachId == 'c');
      expect(c.wins, 0);
      expect(c.losses, 1);
      expect(c.winPct, 0);
    });

    test('only teams that played appear', () {
      expect(computeStandings([]), isEmpty);
      expect(computeStandings([_game('a', 'b', 2, 1)]).map((s) => s.coachId),
          unorderedEquals(['a', 'b']));
    });

    test('orders by win percentage first', () {
      // a: 1-0 (1.000), b: 2-1 (.667), c: 0-2.
      final table = computeStandings([
        _game('a', 'c', 2, 1),
        _game('b', 'c', 2, 1),
        _game('b', 'd', 2, 1),
        _game('d', 'b', 2, 1),
      ]);
      expect(table.map((s) => s.coachId).take(2), ['a', 'b']);
      expect(table.last.coachId, 'c');
    });

    test('then by wins when the percentage is level', () {
      // a: 2-0, b: 1-0 — both 1.000.
      final table = computeStandings([
        _game('a', 'x', 2, 1),
        _game('a', 'y', 2, 1),
        _game('b', 'z', 2, 1),
      ]);
      expect(table.map((s) => s.coachId).take(2), ['a', 'b']);
    });

    test('then by point difference', () {
      // a and b both 1-0; a won by 20, b by 5.
      final table = computeStandings([
        _game('b', 'x', 60, 55),
        _game('a', 'y', 80, 60),
      ]);
      expect(table.map((s) => s.coachId).take(2), ['a', 'b']);
    });

    test('then by team name, so the order never shuffles', () {
      final table = computeStandings([
        _game('z', 'x', 60, 50, nameA: 'Arimbay Aces'),
        _game('y', 'w', 60, 50, nameA: 'Bonot Bulls'),
      ]);
      expect(table.map((s) => s.storedName).take(2),
          ['Arimbay Aces', 'Bonot Bulls']);
    });

    test("keeps the name from the team's latest game", () {
      final table = computeStandings([
        _game('a', 'b', 2, 1,
            nameA: 'New Name', playedAt: DateTime.utc(2026, 8, 1)),
        _game('a', 'b', 2, 1,
            nameA: 'Old Name', playedAt: DateTime.utc(2026, 3, 1)),
      ]);
      expect(table.firstWhere((s) => s.coachId == 'a').storedName, 'New Name');
    });
  });

  group('standingRanks', () {
    test('numbers teams in order', () {
      final table = computeStandings([
        _game('a', 'b', 80, 60),
        _game('a', 'c', 80, 70),
        _game('b', 'c', 80, 75),
      ]);
      expect(standingRanks(table), [1, 2, 3]);
    });

    test('teams level on every tiebreak share a rank', () {
      // a and b each 1-0 by 10; c and d each 0-1 by 10.
      final table = computeStandings([
        _game('a', 'c', 60, 50),
        _game('b', 'd', 60, 50),
      ]);
      expect(standingRanks(table), [1, 1, 3, 3]);
    });
  });

  group('seasons', () {
    test('a season is the calendar year in Philippine time', () {
      // 23:30 on 31 Dec in Manila is 15:30 UTC.
      expect(seasonOf(DateTime.utc(2026, 12, 31, 15, 30)), 2026);
      // 00:30 on 1 Jan in Manila is still 31 Dec in UTC.
      expect(seasonOf(DateTime.utc(2026, 12, 31, 16, 30)), 2027);
    });

    test('season bounds are midnight in Manila', () {
      final b = seasonBounds(2027);
      expect(b.start, DateTime.utc(2026, 12, 31, 16));
      expect(b.end, DateTime.utc(2027, 12, 31, 16));
      expect(seasonOf(b.start), 2027);
      expect(seasonOf(b.end.subtract(const Duration(seconds: 1))), 2027);
      expect(seasonOf(b.end), 2028);
    });

    test('seasonsSince lists every season newest first', () {
      expect(seasonsSince(2026, DateTime.utc(2028, 5, 1)), [2028, 2027, 2026]);
      expect(seasonsSince(2026, DateTime.utc(2026, 5, 1)), [2026]);
    });

    test('seasonsSince always includes the current season', () {
      expect(seasonsSince(2026, DateTime.utc(2025, 5, 1)), [2025]);
    });
  });

  group('formatPct', () {
    test('drops the leading zero like a box score', () {
      expect(formatPct(0.75), '.750');
      expect(formatPct(2 / 3), '.667');
      expect(formatPct(0), '.000');
    });

    test('a perfect record reads 1.000', () {
      expect(formatPct(1), '1.000');
    });
  });
}
