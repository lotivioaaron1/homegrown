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
}
