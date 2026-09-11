// test/utils/team_name_test.dart
//
// Invites used to go out as "your team" when a coach had no team name, and a
// renamed team kept its old name on every membership.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/team_name.dart';

void main() {
  group('teamDisplayName', () {
    test('uses the team name when there is one', () {
      expect(teamDisplayName(teamOrganization: 'Arimbay Hoopers',
          coachName: 'Ana Reyes'), 'Arimbay Hoopers');
    });

    test('trims it', () {
      expect(teamDisplayName(teamOrganization: '  Hoopers  '), 'Hoopers');
    });

    test('a blank name falls back to the coach', () {
      expect(teamDisplayName(teamOrganization: '', coachName: 'Ana Reyes'),
          "Coach Ana's team");
    });

    test('the old "your team" placeholder counts as blank', () {
      expect(teamDisplayName(teamOrganization: 'your team',
          coachName: 'Ana Reyes'), "Coach Ana's team");
    });

    test('with nothing at all it is just "Team"', () {
      expect(teamDisplayName(), 'Team');
    });
  });

  group('liveTeamName', () {
    test("prefers the coach's current name over the stored copy", () {
      expect(
          liveTeamName(
              coachProfile: {'teamOrganization': 'New Name'},
              storedTeamName: 'Old Name'),
          'New Name');
    });

    test('a coach who cleared the name falls back to the coach', () {
      expect(
          liveTeamName(
              coachProfile: {'teamOrganization': '', 'fullName': 'Ben Cruz'},
              storedTeamName: 'Old Name'),
          "Coach Ben's team");
    });

    test('uses the stored copy until the profile loads', () {
      expect(liveTeamName(storedTeamName: 'Old Name'), 'Old Name');
    });

    test('a stored placeholder still falls back to the coach', () {
      expect(liveTeamName(storedTeamName: 'your team', coachName: 'Ben Cruz'),
          "Coach Ben's team");
    });
  });
}
