// lib/utils/organizer_todo.dart
//
// What an organizer still owes, for the to-do card on Home. Running a game
// has a second half that used to be invisible: after the score is recorded,
// every player's stats still have to be entered before ratings move, and
// nothing on Home said so. Kept as a plain function over maps, like
// event_reminders.dart, so the counting can be tested without Firestore.

import 'event_history.dart';
import 'firestore_helpers.dart';

/// One kind of task: how many games need it, and the game to open first.
class TodoItem {
  final int count;
  final String nextEventId;
  final String nextEventName;
  const TodoItem({
    required this.count,
    required this.nextEventId,
    required this.nextEventName,
  });
}

/// The organizer's open tasks. A null item means nothing of that kind is
/// waiting.
class OrganizerTodo {
  /// Games whose start time has passed with no score recorded.
  final TodoItem? needsScore;

  /// Games with a score but at least one player still missing stats, so the
  /// match hasn't closed and nobody's rating has moved yet.
  final TodoItem? needsStats;

  /// Drafts nobody has been told about yet.
  final TodoItem? drafts;

  const OrganizerTodo({this.needsScore, this.needsStats, this.drafts});

  bool get isEmpty => needsScore == null && needsStats == null && drafts == null;
}

/// Builds the to-do from the organizer's [events] and their
/// [pendingMatches] (recorded, not yet finalized).
///
/// A pending match only counts while its event is in [events] and not
/// cancelled: Add Stats can't open a cancelled game, so listing it would be
/// a task with no way to do it. The game offered first in each group is the
/// one that has waited longest.
OrganizerTodo organizerTodo({
  required List<Map<String, dynamic>> events,
  required List<Map<String, dynamic>> pendingMatches,
  DateTime? now,
}) {
  final byId = <String, Map<String, dynamic>>{
    for (final e in events)
      if (e['eventId'] is String) e['eventId'] as String: e,
  };
  final statsIds = <String>{
    for (final m in pendingMatches)
      if (m['eventId'] is String) m['eventId'] as String,
  };
  return OrganizerTodo(
    needsScore:
        _item(events.where((e) => canRecordResult(e, now: now)).toList()),
    needsStats: _item([
      for (final id in statsIds)
        if (byId[id] != null && byId[id]!['status'] != 'cancelled') byId[id]!,
    ]),
    drafts: _item(events.where((e) => e['status'] == 'draft').toList()),
  );
}

TodoItem? _item(List<Map<String, dynamic>> events) {
  final usable = events.where((e) => e['eventId'] is String).toList();
  if (usable.isEmpty) return null;
  usable.sort((a, b) {
    final aT = asTimestamp(a['eventDate']);
    final bT = asTimestamp(b['eventDate']);
    if (aT == null && bT == null) return 0;
    if (aT == null) return 1;
    if (bT == null) return -1;
    return aT.compareTo(bT);
  });
  final first = usable.first;
  final name = (first['name'] as String? ?? '').trim();
  return TodoItem(
    count: usable.length,
    nextEventId: first['eventId'] as String,
    nextEventName: name.isEmpty ? 'Untitled Event' : name,
  );
}

/// "1 game needs a score", "3 games need a score".
String todoScoreLabel(int n) =>
    n == 1 ? '1 game needs a score' : '$n games need a score';

/// "1 game needs player stats", "2 games need player stats".
String todoStatsLabel(int n) =>
    n == 1 ? '1 game needs player stats' : '$n games need player stats';

/// "1 draft to publish", "2 drafts to publish".
String todoDraftsLabel(int n) =>
    n == 1 ? '1 draft to publish' : '$n drafts to publish';
