// lib/utils/match_lineup.dart

/// Each player's starting side from the team saved at event creation:
/// 'A' or 'B', or null when the event never assigned one (older events).
Map<String, String?> initialTeams(List<Map<String, dynamic>> players) => {
      for (final p in players)
        if (p['uid'] is String)
          p['uid'] as String:
              (p['team'] == 'A' || p['team'] == 'B') ? p['team'] as String : null,
    };

/// Who is on each side of a match, and who actually played.
class MatchLineup {
  final List<String> rosterA;
  final List<String> rosterB;
  final List<String> unassigned;

  /// The players recorded for each side: the roster minus anyone sat out.
  final List<String> sideA;
  final List<String> sideB;

  const MatchLineup({
    required this.rosterA,
    required this.rosterB,
    required this.unassigned,
    required this.sideA,
    required this.sideB,
  });
}

/// Groups the event's [players] by [teamOf], in event order. Ids in
/// [teamOf] or [satOut] that aren't in the event are ignored.
MatchLineup deriveLineup(
  List<Map<String, dynamic>> players,
  Map<String, String?> teamOf,
  Set<String> satOut,
) {
  final rosterA = <String>[];
  final rosterB = <String>[];
  final unassigned = <String>[];
  for (final p in players) {
    final uid = p['uid'];
    if (uid is! String) continue;
    switch (teamOf[uid]) {
      case 'A':
        rosterA.add(uid);
      case 'B':
        rosterB.add(uid);
      default:
        unassigned.add(uid);
    }
  }
  return MatchLineup(
    rosterA: rosterA,
    rosterB: rosterB,
    unassigned: unassigned,
    sideA: rosterA.where((u) => !satOut.contains(u)).toList(),
    sideB: rosterB.where((u) => !satOut.contains(u)).toList(),
  );
}

/// Why the result can't be recorded yet, or null when it can. The first
/// failing rule wins: an empty side, then a missing score, then a tie.
String? recordBlockReason(
  MatchLineup lineup,
  String scoreA,
  String scoreB, {
  required String nameA,
  required String nameB,
}) {
  final emptyA = lineup.sideA.isEmpty;
  final emptyB = lineup.sideB.isEmpty;
  if (emptyA && emptyB) return 'Both teams need at least one player who played';
  if (emptyA) return '$nameA needs at least one player who played';
  if (emptyB) return '$nameB needs at least one player who played';

  final a = int.tryParse(scoreA.trim());
  final b = int.tryParse(scoreB.trim());
  if (a == null || b == null) return 'Enter both scores';
  if (a == b) return "Scores can't be tied";
  return null;
}
