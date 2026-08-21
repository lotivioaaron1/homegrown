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
