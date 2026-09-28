// test/utils/match_lineup_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/match_lineup.dart';

Map<String, dynamic> _p(String uid, [String? team]) =>
    {'uid': uid, 'fullName': uid, if (team != null) 'team': team};

void main() {
  group('initialTeams', () {
    test('keeps each player on the team saved at event creation', () {
      expect(initialTeams([_p('a1', 'A'), _p('b1', 'B')]),
          {'a1': 'A', 'b1': 'B'});
    });

    test('treats a missing, blank or unknown team as unassigned', () {
      expect(initialTeams([_p('x'), _p('y', ''), _p('z', 'C')]),
          {'x': null, 'y': null, 'z': null});
    });

    test('skips entries with no uid', () {
      expect(initialTeams([{'fullName': 'Ghost', 'team': 'A'}, _p('a1', 'A')]),
          {'a1': 'A'});
    });
  });

  group('deriveLineup', () {
    final players = [_p('a1', 'A'), _p('b1', 'B'), _p('a2', 'A'), _p('u1')];

    test('splits the roster by team in event order', () {
      final l = deriveLineup(players, initialTeams(players), {});
      expect(l.rosterA, ['a1', 'a2']);
      expect(l.rosterB, ['b1']);
      expect(l.unassigned, ['u1']);
      expect(l.sideA, ['a1', 'a2']);
      expect(l.sideB, ['b1']);
    });

    test('drops a sat-out player from their side but keeps them listed', () {
      final l = deriveLineup(players, initialTeams(players), {'a2'});
      expect(l.rosterA, ['a1', 'a2']);
      expect(l.sideA, ['a1']);
    });

    test('never records an unassigned player', () {
      final l = deriveLineup(players, initialTeams(players), {});
      expect([...l.sideA, ...l.sideB], isNot(contains('u1')));
    });

    test('records a teamless player once they are added to a team', () {
      final teams = initialTeams(players)..['u1'] = 'B';
      final l = deriveLineup(players, teams, {});
      expect(l.sideB, ['b1', 'u1']);
      expect(l.unassigned, isEmpty);
    });

    test('ignores ids that are not in the event', () {
      final teams = initialTeams(players)..['stranger'] = 'A';
      final l = deriveLineup(players, teams, {'stranger'});
      expect(l.rosterA, ['a1', 'a2']);
    });

    test('an untouched bracket roster records every player as prefilled', () {
      final bracket = [
        _p('a1', 'A'), _p('a2', 'A'), _p('b1', 'B'), _p('b2', 'B'),
      ];
      final l = deriveLineup(bracket, initialTeams(bracket), {});
      expect(l.sideA, ['a1', 'a2']);
      expect(l.sideB, ['b1', 'b2']);
      expect(l.unassigned, isEmpty);
    });
  });

  group('recordBlockReason', () {
    final players = [_p('a1', 'A'), _p('b1', 'B')];
    final ready = deriveLineup(players, initialTeams(players), {});

    String? reason(MatchLineup l, String a, String b) =>
        recordBlockReason(l, a, b, nameA: 'Warriors', nameB: 'Tigers');

    test('allows a lineup on both sides with different scores', () {
      expect(reason(ready, '84', '90'), isNull);
    });

    test('names the team with nobody on it', () {
      // The reported event: all five players landed on one team.
      final oneSided = [for (var i = 0; i < 5; i++) _p('b$i', 'B')];
      final l = deriveLineup(oneSided, initialTeams(oneSided), {});
      expect(
          recordBlockReason(l, '84', '90', nameA: 'Team A', nameB: 'Coach'),
          'Team A needs at least one player who played');
    });

    test('counts a team whose players all sat out as empty', () {
      final l = deriveLineup(players, initialTeams(players), {'b1'});
      expect(reason(l, '84', '90'),
          'Tigers needs at least one player who played');
    });

    test('says both teams when neither has a player', () {
      final l = deriveLineup([_p('u1')], initialTeams([_p('u1')]), {});
      expect(reason(l, '84', '90'),
          'Both teams need at least one player who played');
    });

    test('reports an empty side before missing scores', () {
      final l = deriveLineup(players, initialTeams(players), {'a1'});
      expect(reason(l, '', ''),
          'Warriors needs at least one player who played');
    });

    test('treats a blank or whitespace score as missing', () {
      expect(reason(ready, '', '90'), 'Enter both scores');
      expect(reason(ready, '84', '  '), 'Enter both scores');
    });

    test('rejects a tie', () {
      expect(reason(ready, '88', '88'), "Scores can't be tied");
    });
  });
}
