// lib/utils/coach_todo.dart
//
// What a coach still has to do, for the to-do card on Home. Two things used
// to be invisible there: a coach with no sport set only found out two
// screens later, inside Scout, and invites they had sent left no trace while
// the roster was still empty. Kept as a plain function over the profile map,
// like organizer_todo.dart, so it can be tested without Firestore.

import 'sports.dart';
import 'team_name.dart';

/// The coach's open tasks. Each one is independent; none blocks another.
class CoachTodo {
  /// No sport on the profile, so Scout shows nobody and nobody can be
  /// invited.
  final bool needsSport;

  /// Invites the coach has sent that athletes haven't answered yet.
  final int pendingInvites;

  /// No team name, so athletes see "Coach Ana's team" instead.
  final bool needsTeamName;

  const CoachTodo({
    required this.needsSport,
    required this.pendingInvites,
    required this.needsTeamName,
  });

  bool get isEmpty => !needsSport && pendingInvites == 0 && !needsTeamName;
}

/// Builds the to-do from the coach's live `users/{uid}` [user] map (null
/// while it can't be read) and the count of their [pendingInvites].
CoachTodo coachTodo({
  required Map<String, dynamic>? user,
  required int pendingInvites,
}) =>
    CoachTodo(
      needsSport: sportsOf(user).isEmpty,
      pendingInvites: pendingInvites,
      needsTeamName:
          !hasCustomTeamName(user?['teamOrganization'] as String?),
    );

/// "1 invite waiting for a reply", "3 invites waiting for replies".
String coachInvitesLabel(int n) => n == 1
    ? '1 invite waiting for a reply'
    : '$n invites waiting for replies';
