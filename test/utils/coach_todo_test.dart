// test/utils/coach_todo_test.dart
//
// What a coach's Home "To Do" card lists. Two gaps prompted it: a coach with
// no sport set was only told so two screens past Home, inside Scout, and
// invites a coach had sent left no trace on Home while the roster was empty.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/coach_todo.dart';

Map<String, dynamic> _coach({
  Object? sports = const ['Basketball'],
  String? team = 'Arimbay Hoopers',
}) =>
    {
      'role': 'coach',
      if (sports != null) 'primarySports': sports,
      if (team != null) 'teamOrganization': team,
    };

void main() {
  group('coachTodo', () {
    test('a set-up coach with no invites out has nothing to do', () {
      final todo = coachTodo(user: _coach(), pendingInvites: 0);
      expect(todo.needsSport, isFalse);
      expect(todo.needsTeamName, isFalse);
      expect(todo.pendingInvites, 0);
      expect(todo.isEmpty, isTrue);
    });

    test('no sports means the coach needs to choose one', () {
      final todo = coachTodo(user: _coach(sports: const []), pendingInvites: 0);
      expect(todo.needsSport, isTrue);
      expect(todo.isEmpty, isFalse);
    });

    test('a missing or malformed sports field also needs one', () {
      expect(coachTodo(user: _coach(sports: null), pendingInvites: 0)
          .needsSport, isTrue);
      expect(coachTodo(user: _coach(sports: 'Basketball'), pendingInvites: 0)
          .needsSport, isTrue);
    });

    test('a coach of two sports is set', () {
      final todo = coachTodo(
          user: _coach(sports: const ['Basketball', 'Volleyball']),
          pendingInvites: 0);
      expect(todo.needsSport, isFalse);
    });

    test('pending invites are carried through and make it non-empty', () {
      final todo = coachTodo(user: _coach(), pendingInvites: 3);
      expect(todo.pendingInvites, 3);
      expect(todo.isEmpty, isFalse);
    });

    test('a blank or whitespace team name needs naming', () {
      expect(coachTodo(user: _coach(team: null), pendingInvites: 0)
          .needsTeamName, isTrue);
      expect(coachTodo(user: _coach(team: '  '), pendingInvites: 0)
          .needsTeamName, isTrue);
    });

    test('the old "your team" placeholder needs naming too', () {
      final todo = coachTodo(user: _coach(team: 'your team'), pendingInvites: 0);
      expect(todo.needsTeamName, isTrue);
    });

    test('a missing profile asks for everything it can', () {
      final todo = coachTodo(user: null, pendingInvites: 0);
      expect(todo.needsSport, isTrue);
      expect(todo.needsTeamName, isTrue);
    });
  });

  group('coachInvitesLabel', () {
    test('singular', () {
      expect(coachInvitesLabel(1), '1 invite waiting for a reply');
    });

    test('plural', () {
      expect(coachInvitesLabel(3), '3 invites waiting for replies');
    });
  });
}
