// test/utils/event_roster_check_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/constants/event_min_players.dart';
import 'package:homegrown/constants/sport_positions.dart';
import 'package:homegrown/utils/event_roster_check.dart';

String? check({
  String sport = 'Basketball',
  bool pickedA = true,
  bool pickedB = true,
  int countA = 5,
  int countB = 5,
}) =>
    teamsProblem(
      sport: sport,
      pickedA: pickedA,
      pickedB: pickedB,
      countA: countA,
      countB: countB,
      nameA: 'Warriors',
      nameB: 'Tigers',
    );

void main() {
  test('every supported sport has a minimum per side', () {
    for (final sport in kSportPositions.keys) {
      expect(kMinPlayersPerSide[sport], isNotNull, reason: sport);
    }
  });

  group('teamsProblem', () {
    test('allows two picked teams that meet the minimum', () {
      expect(check(countA: 5, countB: 7), isNull);
    });

    test('asks for both teams when neither is picked', () {
      expect(check(pickedA: false, pickedB: false, countA: 0, countB: 0),
          'Pick a team for each side.');
    });

    test('names the side still to pick', () {
      expect(check(pickedB: false, countB: 0), 'Pick Team B before continuing.');
      expect(check(pickedA: false, countA: 0), 'Pick Team A before continuing.');
    });

    test('names a team below the sport minimum', () {
      expect(check(countA: 3),
          'Warriors has only 3 players. Basketball needs at least 5 per side.');
    });

    test('says when a picked team has no players at all', () {
      expect(check(countB: 0),
          'Tigers has no players. Basketball needs at least 5 per side.');
    });

    test('uses each sport’s own minimum', () {
      expect(check(sport: 'Volleyball', countA: 6, countB: 5),
          'Tigers has only 5 players. Volleyball needs at least 6 per side.');
      expect(check(sport: 'Badminton', countA: 1, countB: 1), isNull);
    });

    test('reads one player in the singular', () {
      expect(check(countA: 1),
          'Warriors has only 1 player. Basketball needs at least 5 per side.');
    });
  });
}
