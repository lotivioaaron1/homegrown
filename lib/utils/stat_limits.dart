// lib/utils/stat_limits.dart
//
// What a stat line may not exceed. A player can't score more than their
// team did, so Add Stats caps the one stat that's part of the recorded final
// score: basketball points, which teammates share, and badminton sets won,
// which both partners on a side win together. Volleyball's box score has no
// stat that adds up to the result, so it isn't capped.

import 'dart:math' as math;

/// The limit on one player's capped stat for the selected match.
class ScoreCap {
  /// The key in the stats map: `points` or `setsWon`.
  final String statKey;

  final String teamName;
  final int teamScore;

  /// Already saved for teammates on the same side. Only counted when
  /// [shared].
  final int teammatesTotal;

  /// Whether teammates share [teamScore] between them (basketball points)
  /// or each can reach it on their own (badminton sets).
  final bool shared;

  const ScoreCap({
    required this.statKey,
    required this.teamName,
    required this.teamScore,
    required this.teammatesTotal,
    required this.shared,
  });

  /// The most this player can be given.
  int get remaining =>
      shared ? math.max(0, teamScore - teammatesTotal) : teamScore;
}

/// Which side of [match] [athleteId] played on: 'A', 'B', or null.
String? _sideOf(Map<String, dynamic> match, String athleteId) {
  if ((match['sideA'] as List? ?? const []).contains(athleteId)) return 'A';
  if ((match['sideB'] as List? ?? const []).contains(athleteId)) return 'B';
  return null;
}

/// The cap for [athleteId]'s stat line in [match], or null when [sport]
/// isn't capped or they didn't play. [enteredByAthlete] is each athlete's
/// already-saved capped stat for this match.
ScoreCap? scoreCapFor({
  required String sport,
  required Map<String, dynamic> match,
  required String athleteId,
  required String nameA,
  required String nameB,
  required Map<String, int> enteredByAthlete,
}) {
  final String statKey;
  final bool shared;
  switch (sport) {
    case 'Basketball':
      statKey = 'points';
      shared = true;
    case 'Badminton':
      statKey = 'setsWon';
      shared = false;
    default:
      return null;
  }

  final side = _sideOf(match, athleteId);
  if (side == null) return null;

  final teammates =
      (match[side == 'A' ? 'sideA' : 'sideB'] as List? ?? const [])
          .where((uid) => uid != athleteId);
  final teammatesTotal =
      teammates.fold<int>(0, (sum, uid) => sum + (enteredByAthlete[uid] ?? 0));

  return ScoreCap(
    statKey: statKey,
    teamName: side == 'A' ? nameA : nameB,
    teamScore: (match[side == 'A' ? 'scoreA' : 'scoreB'] as num?)?.toInt() ?? 0,
    teammatesTotal: teammatesTotal,
    shared: shared,
  );
}

/// Why [value] can't be saved, or null if it can.
String? scoreCapError(ScoreCap cap, int value) {
  if (value > cap.teamScore) {
    return cap.shared
        ? '${cap.teamName} scored ${cap.teamScore}, so no player can have '
            'more than ${cap.teamScore} points.'
        : "${cap.teamName} won ${cap.teamScore} sets, so Sets Won can't be "
            'more than ${cap.teamScore}.';
  }
  if (cap.shared && value > cap.remaining) {
    return 'Only ${cap.remaining} of ${_possessive(cap.teamName)} '
        '${cap.teamScore} '
        'points are left: ${cap.teammatesTotal} are already entered for '
        'teammates.';
  }
  return null;
}

/// "Rockets'" for a name ending in s, "Coach's" otherwise.
String _possessive(String name) =>
    name.endsWith('s') ? "$name'" : "$name's";

/// The line shown under the stats while typing, saying how much is allowed.
String scoreCapHint(ScoreCap cap) {
  if (!cap.shared) return '${cap.teamName} won ${cap.teamScore} sets';
  final entered = cap.teammatesTotal > 0
      ? ', ${cap.teammatesTotal} entered for teammates'
      : '';
  return 'Up to ${cap.remaining} points · '
      '${cap.teamName} scored ${cap.teamScore}$entered';
}

/// Whether [athleteId]'s side won [match], or null if they were on neither
/// side.
bool? matchWonFor(Map<String, dynamic> match, String athleteId) {
  final side = _sideOf(match, athleteId);
  return side == null ? null : match['winner'] == side;
}
