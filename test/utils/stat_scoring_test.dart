// test/utils/stat_scoring_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/stat_scoring.dart';

void main() {
  group('calcPointsAwarded', () {
    test('calculates basketball points from the weighted stat formula', () {
      final result = calcPointsAwarded('Basketball', {
        'points': 10,
        'assists': 4,
        'rebounds': 5,
        'steals': 2,
        'blocks': 1,
        'turnovers': 3,
      });
      // 10*1 + 4*1.5 + 5*1 + 2*2 + 1*2 - 3*1 = 24
      expect(result, 24);
    });

    test('calculates volleyball points from the weighted stat formula', () {
      final result = calcPointsAwarded('Volleyball', {
        'kills': 5,
        'aces': 2,
        'assists': 3,
        'digs': 4,
        'blocks': 1,
      });
      // 5*2 + 2*2 + 3*1 + 4*1 + 1*2 = 23
      expect(result, 23);
    });

    test('calculates badminton points including the match-won bonus', () {
      final result = calcPointsAwarded('Badminton', {
        'matchWon': true,
        'setsWon': 2,
        'pointsScored': 20,
      });
      // 10 (won) + 2*3 + 20*0.5 = 26
      expect(result, 26);
    });

    test('clamps a negative total to zero', () {
      final result = calcPointsAwarded('Basketball', {
        'points': 0,
        'assists': 0,
        'rebounds': 0,
        'steals': 0,
        'blocks': 0,
        'turnovers': 10,
      });
      expect(result, 0);
    });

    test('treats missing stat fields as zero', () {
      final result = calcPointsAwarded('Basketball', {'points': 10});
      // 10*1 + 0s = 10
      expect(result, 10);
    });

    test('returns zero for an unrecognized sport', () {
      final result = calcPointsAwarded('Tennis', {'points': 10});
      expect(result, 0);
    });
  });

  group('averageStats', () {
    test('averages basketball categories across games', () {
      final result = averageStats('Basketball', [
        {'points': 10, 'assists': 2, 'rebounds': 6, 'steals': 1, 'blocks': 0, 'turnovers': 2},
        {'points': 20, 'assists': 4, 'rebounds': 8, 'steals': 3, 'blocks': 2, 'turnovers': 4},
      ]);
      expect(result['Points'], 15);
      expect(result['Assists'], 3);
      expect(result['Rebounds'], 7);
      expect(result['Steals'], 2);
      expect(result['Blocks'], 1);
      expect(result['Turnovers'], 3);
    });

    test('averages volleyball categories across games', () {
      final result = averageStats('Volleyball', [
        {'kills': 4, 'aces': 0, 'assists': 2, 'digs': 3, 'blocks': 1},
        {'kills': 6, 'aces': 2, 'assists': 4, 'digs': 5, 'blocks': 3},
      ]);
      expect(result['Kills'], 5);
      expect(result['Aces'], 1);
      expect(result['Assists'], 3);
      expect(result['Digs'], 4);
      expect(result['Blocks'], 2);
    });

    test('averages badminton categories and derives win rate from matchWon', () {
      final result = averageStats('Badminton', [
        {'pointsScored': 21, 'setsWon': 2, 'matchWon': true},
        {'pointsScored': 15, 'setsWon': 0, 'matchWon': false},
        {'pointsScored': 21, 'setsWon': 2, 'matchWon': true},
        {'pointsScored': 19, 'setsWon': 1, 'matchWon': false},
      ]);
      expect(result['Points Scored'], 19);
      expect(result['Sets Won'], 1.25);
      expect(result['Win Rate %'], 50);
    });

    test('returns an empty map for an empty games list', () {
      final result = averageStats('Basketball', []);
      expect(result, isEmpty);
    });

    test('returns an empty map for an unrecognized sport', () {
      final result = averageStats('Tennis', [
        {'points': 10},
      ]);
      expect(result, isEmpty);
    });
  });

  group('kScoutSkills', () {
    // The catalog's statKey values are looked up in averageStats' output at
    // sort time. A typo there wouldn't throw — every athlete would silently
    // score 0.0 and the skill sort would appear to do nothing — so the keys
    // are pinned to the real labels here.
    final sampleGame = {
      'Basketball': {
        'points': 1, 'assists': 1, 'rebounds': 1,
        'steals': 1, 'blocks': 1, 'turnovers': 1,
      },
      'Volleyball': {
        'kills': 1, 'aces': 1, 'assists': 1, 'digs': 1, 'blocks': 1,
      },
      'Badminton': {'pointsScored': 1, 'setsWon': 1, 'matchWon': true},
    };

    test('every skill statKey resolves to a real averageStats category', () {
      for (final entry in kScoutSkills.entries) {
        final categories = averageStats(entry.key, [sampleGame[entry.key]!]);
        for (final skill in entry.value) {
          expect(categories.keys, contains(skill.statKey),
              reason: '${entry.key} skill "${skill.label}" points at '
                  '"${skill.statKey}", which averageStats does not produce');
        }
      }
    });

    test('covers every sport the scout screen can filter by', () {
      expect(kScoutSkills.keys,
          containsAll(<String>['Basketball', 'Volleyball', 'Badminton']));
    });

    test('excludes turnovers, which are not something a coach scouts for', () {
      final basketball = kScoutSkills['Basketball']!;
      expect(basketball.map((s) => s.statKey), isNot(contains('Turnovers')));
    });
  });

  group('skillAveragesByAthlete', () {
    test('groups an athlete\'s games and averages each category', () {
      final result = skillAveragesByAthlete('Basketball', [
        {
          'athleteId': 'a1',
          'sport': 'Basketball',
          'stats': {'points': 10, 'rebounds': 6, 'assists': 2},
        },
        {
          'athleteId': 'a1',
          'sport': 'Basketball',
          'stats': {'points': 20, 'rebounds': 8, 'assists': 4},
        },
      ]);

      expect(result.keys, ['a1']);
      expect(result['a1']!.games, 2);
      expect(result['a1']!.averages['Rebounds'], 7);
      expect(result['a1']!.averages['Points'], 15);
    });

    test('keeps athletes separate', () {
      final result = skillAveragesByAthlete('Volleyball', [
        {
          'athleteId': 'a1',
          'sport': 'Volleyball',
          'stats': {'kills': 10},
        },
        {
          'athleteId': 'a2',
          'sport': 'Volleyball',
          'stats': {'kills': 4},
        },
      ]);

      expect(result['a1']!.averages['Kills'], 10);
      expect(result['a2']!.averages['Kills'], 4);
      expect(result['a1']!.games, 1);
    });

    test('ignores docs recorded for a different sport', () {
      final result = skillAveragesByAthlete('Basketball', [
        {
          'athleteId': 'a1',
          'sport': 'Basketball',
          'stats': {'rebounds': 6},
        },
        {
          'athleteId': 'a1',
          'sport': 'Volleyball',
          'stats': {'kills': 30},
        },
      ]);

      expect(result['a1']!.games, 1);
      expect(result['a1']!.averages['Rebounds'], 6);
    });

    test('skips docs with a missing or empty athleteId', () {
      final result = skillAveragesByAthlete('Basketball', [
        {
          'sport': 'Basketball',
          'stats': {'rebounds': 6},
        },
        {
          'athleteId': '',
          'sport': 'Basketball',
          'stats': {'rebounds': 6},
        },
      ]);

      expect(result, isEmpty);
    });

    test('treats a missing stats map as an all-zero game', () {
      final result = skillAveragesByAthlete('Basketball', [
        {'athleteId': 'a1', 'sport': 'Basketball'},
      ]);

      expect(result['a1']!.games, 1);
      expect(result['a1']!.averages['Rebounds'], 0);
    });

    test('returns an empty map for no docs', () {
      expect(skillAveragesByAthlete('Basketball', []), isEmpty);
    });

    test('derives badminton win rate across an athlete\'s matches', () {
      final result = skillAveragesByAthlete('Badminton', [
        {
          'athleteId': 'a1',
          'sport': 'Badminton',
          'stats': {'matchWon': true, 'setsWon': 2, 'pointsScored': 21},
        },
        {
          'athleteId': 'a1',
          'sport': 'Badminton',
          'stats': {'matchWon': false, 'setsWon': 0, 'pointsScored': 15},
        },
      ]);

      expect(result['a1']!.averages['Win Rate %'], 50);
      expect(result['a1']!.games, 2);
    });
  });
}
