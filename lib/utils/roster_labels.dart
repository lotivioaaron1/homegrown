// lib/utils/roster_labels.dart

// The wording on a team roster, as pure decisions.
//
// Both roster screens (the coach's My Team and an athlete's view of their
// team) used to carry the same private date helper and put "Member since" in
// front of it, which read "Member since 3d ago" for anyone recent and dropped
// the year for anyone older.

import 'package:intl/intl.dart';

/// When a member joined, in the shortest form that is still unambiguous:
/// "Joined 3d ago" for the past week, then "Joined Sep 6", with the year added
/// once the date falls in an earlier year. Empty when [date] is unknown, so
/// callers can drop the line instead of showing a dangling "Joined".
String joinedLabel(DateTime? date, {DateTime? now}) =>
    date == null ? '' : 'Joined ${_since(date, now ?? DateTime.now())}';

/// When an invite still awaiting an answer was sent, in the same form as
/// [joinedLabel]: "Invited 3d ago", "Invited Sep 6".
String invitedLabel(DateTime? date, {DateTime? now}) =>
    date == null ? '' : 'Invited ${_since(date, now ?? DateTime.now())}';

String _since(DateTime date, DateTime now) {
  final diff = now.difference(date);

  // A small negative difference is clock skew between the device and the
  // server timestamp, not a date in the future.
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  final pattern = date.year == now.year ? 'MMM d' : 'MMM d, y';
  return DateFormat(pattern).format(date);
}

/// How much room is left on a roster of [max]: "10 spots open", "1 spot open",
/// or "Roster full" at or past capacity.
String openSpotsLabel(int count, int max) {
  final open = max - count;
  if (open <= 0) return 'Roster full';
  return open == 1 ? '1 spot open' : '$open spots open';
}

/// A roster row's second line: "Point Guard · Joined Sep 6", dropping
/// whichever half is missing. Athletes without a position are common, as the
/// field is optional at sign-up.
String memberSubtitle(String? position, String joined) =>
    [position?.trim() ?? '', joined].where((s) => s.isNotEmpty).join(' · ');
