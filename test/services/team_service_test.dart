// test/services/team_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/services/team_service.dart';

/// A membership doc as `teamMemberships` stores it, trimmed to the fields the
/// clash check reads.
Map<String, dynamic> membership({
  Object? coachId = 'coach_basketball',
  Object? teamName = 'Legazpi Falcons',
}) =>
    {
      'coachId': coachId,
      'athleteId': 'athlete_1',
      'teamName': teamName,
      'status': 'accepted',
    };

/// A `users/{uid}` doc, trimmed to the field `sportsOf` reads.
Map<String, dynamic> coach(List<String> sports) => {
      'role': 'coach',
      'primarySports': sports,
    };

void main() {
  group('teamNamesByCoach', () {
    test('keys each accepted membership by its coach', () {
      final result = teamNamesByCoach([
        membership(coachId: 'coach_a', teamName: 'Falcons'),
        membership(coachId: 'coach_b', teamName: 'Spikers'),
      ]);

      expect(result, {'coach_a': 'Falcons', 'coach_b': 'Spikers'});
    });

    test('skips the coach doing the asking, so a re-check is not a self-clash',
        () {
      final result = teamNamesByCoach(
        [
          membership(coachId: 'coach_a', teamName: 'Falcons'),
          membership(coachId: 'coach_b', teamName: 'Spikers'),
        ],
        excludingCoachId: 'coach_a',
      );

      expect(result, {'coach_b': 'Spikers'});
    });

    test('names a blank team generically rather than leaving a hole', () {
      final result = teamNamesByCoach([
        membership(coachId: 'coach_a', teamName: '   '),
        membership(coachId: 'coach_b', teamName: null),
        membership(coachId: 'coach_c', teamName: 42),
      ]);

      expect(result, {
        'coach_a': 'another team',
        'coach_b': 'another team',
        'coach_c': 'another team',
      });
    });

    test('trims a padded team name, since it goes straight into a sentence',
        () {
      final result =
          teamNamesByCoach([membership(teamName: '  Legazpi Falcons  ')]);

      expect(result.values.single, 'Legazpi Falcons');
    });

    test('drops rows whose coachId is missing, blank, or not a string', () {
      final result = teamNamesByCoach([
        membership(coachId: null),
        membership(coachId: ''),
        membership(coachId: 7),
        membership(coachId: 'coach_real', teamName: 'Falcons'),
      ]);

      expect(result, {'coach_real': 'Falcons'});
    });

    test('an athlete on no team yields no coaches', () {
      expect(teamNamesByCoach([]), isEmpty);
    });
  });

  group('clashingTeam', () {
    test('reports the team when the inviting coach shares its sport', () {
      final result = clashingTeam(
        {'coach_a': 'Falcons'},
        {'coach_a': coach(['Basketball'])},
        ['Basketball'],
      );

      expect(result, 'Falcons');
    });

    test('a second sport is free: one team per sport, not one team overall',
        () {
      // The athlete already plays basketball for the Falcons. A volleyball
      // coach inviting them is not a clash — they may hold one team per sport.
      final result = clashingTeam(
        {'coach_basketball': 'Falcons'},
        {'coach_basketball': coach(['Basketball'])},
        ['Volleyball'],
      );

      expect(result, isNull);
    });

    test('picks out the clashing sport from among several teams', () {
      final result = clashingTeam(
        {'coach_bball': 'Falcons', 'coach_vball': 'Spikers'},
        {
          'coach_bball': coach(['Basketball']),
          'coach_vball': coach(['Volleyball']),
        },
        ['Volleyball'],
      );

      expect(result, 'Spikers');
    });

    test('a two-sport coach clashes on either of their sports', () {
      final profiles = {
        'coach_a': coach(['Basketball', 'Volleyball'])
      };

      expect(clashingTeam({'coach_a': 'Falcons'}, profiles, ['Basketball']),
          'Falcons');
      expect(clashingTeam({'coach_a': 'Falcons'}, profiles, ['Volleyball']),
          'Falcons');
      expect(
          clashingTeam({'coach_a': 'Falcons'}, profiles, ['Badminton']), isNull);
    });

    test('an unreadable coach profile lets the invite through', () {
      // Failing open here is deliberate: blocking on a team whose sport can't
      // be identified would strand the athlete with no way to resolve it.
      final result = clashingTeam(
        {'coach_a': 'Falcons'},
        const {},
        ['Basketball'],
      );

      expect(result, isNull);
    });

    test('a coach with no sports set clashes with nobody', () {
      expect(
        clashingTeam(
          {'coach_a': 'Falcons'},
          {
            'coach_a': coach([])
          },
          ['Basketball'],
        ),
        isNull,
      );
      expect(
        clashingTeam(
          {'coach_a': 'Falcons'},
          {
            'coach_a': {'role': 'coach'}
          },
          ['Basketball'],
        ),
        isNull,
      );
    });
  });

  group('the one-team-per-sport rule end to end', () {
    // The three scenarios the feature exists to handle, run through both
    // halves the way TeamService.existingTeamForSports composes them.
    String? clashFor(
      List<Map<String, dynamic>> memberships,
      Map<String, Map<String, dynamic>> profiles,
      List<String> invitingCoachSports, {
      String? excludingCoachId,
    }) {
      final byCoach =
          teamNamesByCoach(memberships, excludingCoachId: excludingCoachId);
      if (byCoach.isEmpty) return null;
      return clashingTeam(byCoach, profiles, invitingCoachSports);
    }

    test('a second basketball coach is refused, and the team is named', () {
      final result = clashFor(
        [membership(coachId: 'coach_bball', teamName: 'Legazpi Falcons')],
        {
          'coach_bball': coach(['Basketball'])
        },
        ['Basketball'],
        excludingCoachId: 'coach_rival',
      );

      expect(result, 'Legazpi Falcons');
    });

    test('a volleyball coach may still recruit the same athlete', () {
      final result = clashFor(
        [membership(coachId: 'coach_bball', teamName: 'Legazpi Falcons')],
        {
          'coach_bball': coach(['Basketball'])
        },
        ['Volleyball'],
        excludingCoachId: 'coach_vball',
      );

      expect(result, isNull);
    });

    test('the coach who already rosters the athlete is not blocked by them',
        () {
      final result = clashFor(
        [membership(coachId: 'coach_bball', teamName: 'Legazpi Falcons')],
        {
          'coach_bball': coach(['Basketball'])
        },
        ['Basketball'],
        excludingCoachId: 'coach_bball',
      );

      expect(result, isNull);
    });
  });
}
