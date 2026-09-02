// lib/utils/stat_scoring.dart

/// Converts a per-sport box-score stat map into a single weighted point
/// total. `stats` uses the same per-sport shapes AddStatsScreen writes to
/// the `stats` collection (e.g. Basketball: points/assists/rebounds/
/// steals/blocks/turnovers). Missing fields are treated as zero, and the
/// result is clamped to zero and rounded to match how it's stored in
/// Firestore (`pointsAwarded`).
int calcPointsAwarded(String sport, Map<String, dynamic> stats) {
  double n(String key) => (stats[key] as num?)?.toDouble() ?? 0;

  double total;
  switch (sport) {
    case 'Basketball':
      total = (n('points') * 1.0)
          + (n('assists') * 1.5)
          + (n('rebounds') * 1.0)
          + (n('steals') * 2.0)
          + (n('blocks') * 2.0)
          - (n('turnovers') * 1.0);
      break;
    case 'Volleyball':
      total = (n('kills') * 2.0)
          + (n('aces') * 2.0)
          + (n('assists') * 1.0)
          + (n('digs') * 1.0)
          + (n('blocks') * 2.0);
      break;
    case 'Badminton':
      total = ((stats['matchWon'] == true) ? 10.0 : 0.0)
          + (n('setsWon') * 3.0)
          + (n('pointsScored') * 0.5);
      break;
    default:
      total = 0;
  }

  return total.clamp(0, double.infinity).round();
}

/// Averages each per-sport stat category across a list of games (each
/// entry the same `stats` shape used above) so a coach scouting a player
/// can see e.g. "7 rebounds/game" rather than one comparative number.
/// Badminton's boolean `matchWon` isn't directly averageable, so it's
/// reported as a derived "Win Rate %" instead. Returns an empty map for
/// no games played or an unrecognized sport.
Map<String, double> averageStats(String sport, List<Map<String, dynamic>> statsList) {
  if (statsList.isEmpty) return {};

  double avg(String key) => statsList
          .map((s) => (s[key] as num?)?.toDouble() ?? 0)
          .reduce((a, b) => a + b) /
      statsList.length;

  switch (sport) {
    case 'Basketball':
      return {
        'Points': avg('points'),
        'Assists': avg('assists'),
        'Rebounds': avg('rebounds'),
        'Steals': avg('steals'),
        'Blocks': avg('blocks'),
        'Turnovers': avg('turnovers'),
      };
    case 'Volleyball':
      return {
        'Kills': avg('kills'),
        'Aces': avg('aces'),
        'Assists': avg('assists'),
        'Digs': avg('digs'),
        'Blocks': avg('blocks'),
      };
    case 'Badminton':
      final wins = statsList.where((s) => s['matchWon'] == true).length;
      return {
        'Points Scored': avg('pointsScored'),
        'Sets Won': avg('setsWon'),
        'Win Rate %': wins / statsList.length * 100,
      };
    default:
      return {};
  }
}

/// Renders a per-game average the way both the Scout list and the athlete
/// profile sheet show it: whole numbers plain, everything else to one
/// decimal. Shared so the figure a coach sorts by in the list and the one
/// they read on the profile behind it can never disagree.
String formatStatAverage(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

/// One thing a coach can rank athletes by on the Scout screen.
///
/// [label] is the coach's word for it ("Spiking"); [statKey] is the category
/// `averageStats` emits for the same thing ("Kills"); [unit] is the short
/// form shown on an athlete card ("K").
class ScoutSkill {
  final String label;
  final String statKey;
  final String unit;

  const ScoutSkill(this.label, this.statKey, this.unit);
}

/// The skills a coach can sort by, per sport, in the order they're offered.
///
/// Every [ScoutSkill.statKey] must be a category `averageStats` produces for
/// that sport — a mismatch scores every athlete 0.0 and the sort silently
/// does nothing, so the pairing is covered by a test.
///
/// Basketball's turnovers are deliberately absent: the sort runs highest-
/// first, so offering it would rank the most careless ball-handlers at the
/// top. It stays visible on the profile sheet, which is where a negative
/// stat belongs.
const Map<String, List<ScoutSkill>> kScoutSkills = {
  'Basketball': [
    ScoutSkill('Scoring', 'Points', 'PTS'),
    ScoutSkill('Rebounding', 'Rebounds', 'REB'),
    ScoutSkill('Playmaking', 'Assists', 'AST'),
    ScoutSkill('Steals', 'Steals', 'STL'),
    ScoutSkill('Rim Protection', 'Blocks', 'BLK'),
  ],
  'Volleyball': [
    ScoutSkill('Spiking', 'Kills', 'K'),
    ScoutSkill('Serving', 'Aces', 'ACE'),
    ScoutSkill('Setting', 'Assists', 'AST'),
    ScoutSkill('Digging', 'Digs', 'DIG'),
    ScoutSkill('Blocking', 'Blocks', 'BLK'),
  ],
  'Badminton': [
    ScoutSkill('Win Rate', 'Win Rate %', '%'),
    ScoutSkill('Set Winning', 'Sets Won', 'SETS'),
    ScoutSkill('Point Scoring', 'Points Scored', 'PTS'),
  ],
};

/// One athlete's scouting line for a single sport: their per-category
/// per-game [averages] and the [games] those averages are drawn from.
///
/// The game count travels with the averages because a coach reading
/// "9.5 rebounds" needs to know whether that's across two games or twenty.
class AthleteSkillAverages {
  final Map<String, double> averages;
  final int games;

  const AthleteSkillAverages({required this.averages, required this.games});
}

/// Turns raw `stats` documents into per-athlete scouting lines for [sport],
/// keyed by athlete id, so the Scout screen can rank a whole list by one
/// skill instead of making a coach open every profile in turn.
///
/// [statDocs] takes the plain document maps as stored (`athleteId`, `sport`,
/// `stats`) rather than Firestore snapshots, which keeps this testable with
/// literals. Docs for other sports are skipped, as are docs with no
/// athlete id. Averaging is delegated to [averageStats] so a card in the
/// list and the profile sheet behind it can never disagree.
Map<String, AthleteSkillAverages> skillAveragesByAthlete(
  String sport,
  Iterable<Map<String, dynamic>> statDocs,
) {
  final gamesByAthlete = <String, List<Map<String, dynamic>>>{};

  for (final doc in statDocs) {
    if (doc['sport'] != sport) continue;
    final athleteId = doc['athleteId'] as String?;
    if (athleteId == null || athleteId.isEmpty) continue;

    final stats = (doc['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    gamesByAthlete.putIfAbsent(athleteId, () => []).add(stats);
  }

  return gamesByAthlete.map((athleteId, games) => MapEntry(
        athleteId,
        AthleteSkillAverages(
          averages: averageStats(sport, games),
          games: games.length,
        ),
      ));
}
