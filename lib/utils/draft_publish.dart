// lib/utils/draft_publish.dart

import 'package:intl/intl.dart';

import 'event_roster_check.dart';
import 'firestore_helpers.dart';

/// Why a saved draft can't be published yet, or null when it can.
///
/// A draft can sit for weeks before it is announced, so by the time the
/// organizer taps Publish its date may have come and gone; publishing then
/// would announce a game that already happened. The team check repeats the
/// one Create Event made at step 2, since a draft was saved past that step.
String? draftPublishProblem(Map<String, dynamic> event, {DateTime? now}) {
  final date = asTimestamp(event['eventDate'])?.toDate();
  if (date == null) return 'Set a date in Edit Event before publishing.';
  if (date.isBefore(now ?? DateTime.now())) {
    return 'This date has already passed. Pick a new date in Edit Event '
        'before publishing.';
  }

  final players = (event['players'] as List? ?? const [])
      .whereType<Map>()
      .toList();
  // A player saved without a side counts as Team A, as on the event page.
  int countOf(String side) =>
      players.where((p) => (p['team'] as String? ?? 'A') == side).length;

  return teamsProblem(
    sport: asString(event['sport']),
    pickedA: asString(event['teamACoachId']).isNotEmpty,
    pickedB: asString(event['teamBCoachId']).isNotEmpty,
    countA: countOf('A'),
    countB: countOf('B'),
    nameA: _teamName(event['teamAName'], 'Team A'),
    nameB: _teamName(event['teamBName'], 'Team B'),
  );
}

/// The `event_added` notices a draft sends when it's published, one per
/// rostered player and one per head coach.
///
/// Worded exactly like the ones Create Event sends on a straight publish, so
/// an athlete can't tell which way the event went live. A coach picked for
/// both sides is notified once, and a side with no coach is skipped.
List<({String uid, String title, String body})> publishNotices(
    Map<String, dynamic> event) {
  final name = asString(event['name']).trim();
  final venue = asString(event['venue']);
  final date = asTimestamp(event['eventDate'])?.toDate();
  final label =
      date != null ? '$name on ${DateFormat('MMM dd, yyyy').format(date)}' : name;

  final notices = <({String uid, String title, String body})>[];
  final seen = <String>{};

  for (final p in (event['players'] as List? ?? const []).whereType<Map>()) {
    final uid = p['uid'];
    if (uid is! String || uid.isEmpty || !seen.add(uid)) continue;
    notices.add((
      uid: uid,
      title: "You're in an upcoming game",
      body: 'Added to $label at $venue',
    ));
  }

  final coachTeams = <String, String>{};
  for (final side in const ['A', 'B']) {
    final coachId = asString(event['team${side}CoachId']);
    if (coachId.isEmpty) continue;
    coachTeams[coachId] = _teamName(event['team${side}Name'], 'Team $side');
  }
  for (final entry in coachTeams.entries) {
    if (!seen.add(entry.key)) continue;
    notices.add((
      uid: entry.key,
      title: 'Your team has an upcoming game',
      body: '${entry.value} plays in $label at $venue',
    ));
  }

  return notices;
}

String _teamName(Object? value, String fallback) {
  final name = asString(value).trim();
  return name.isEmpty ? fallback : name;
}
