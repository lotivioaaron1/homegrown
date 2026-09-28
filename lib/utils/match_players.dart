// lib/utils/match_players.dart

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
