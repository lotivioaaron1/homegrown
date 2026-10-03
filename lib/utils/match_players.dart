// lib/utils/match_players.dart

import 'firestore_helpers.dart';

/// The event's [players] who were recorded on either side of [match], in
/// event order. Anyone marked as sitting out isn't on a side, so they drop.
List<Map<String, dynamic>> playersInMatch(
    List<Map<String, dynamic>> players, Map<String, dynamic> match) {
  final played = {
    ...(match['sideA'] as List? ?? const []),
    ...(match['sideB'] as List? ?? const []),
  };
  return players.where((p) => played.contains(p['uid'])).toList();
}

/// "Warriors 84 — 90 Tigers", the same shape Record Match confirms with.
String matchLabel(Map<String, dynamic> match,
        {required String nameA, required String nameB}) =>
    '$nameA ${match['scoreA']} — ${match['scoreB']} $nameB';

/// The event's result to show: the most recently recorded of [matches], or
/// null if none. Only games recorded before the one-result rule can have more
/// than one. A match saved moments ago has no server timestamp yet, so it
/// counts as the newest.
T? latestMatch<T>(
  Iterable<T> matches, {
  required Map<String, dynamic> Function(T) data,
}) {
  T? latest;
  DateTime? latestAt;
  for (final m in matches) {
    final at = asTimestamp(data(m)['createdAt'])?.toDate();
    if (at == null) return m;
    if (latestAt == null || at.isAfter(latestAt)) {
      latest = m;
      latestAt = at;
    }
  }
  return latest;
}
