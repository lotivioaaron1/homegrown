// lib/utils/stats_view.dart

// What the Stats tab shows, as pure decisions over the athlete's `stats`
// documents (already decoded to maps and sorted newest first).
//
// Athletes can play several sports, but the tab was written for one: every
// game went into a single chart and history with nothing saying which sport it
// was. A basketball-and-volleyball athlete saw their 12-point basketball night
// and their 8-kill volleyball match as two unlabelled bars.

import 'stat_scoring.dart';

/// The order sports are listed in everywhere else in the app.
const List<String> _kSportOrder = ['Basketball', 'Volleyball', 'Badminton'];

/// The distinct sports in [stats]: known sports in the app's usual order,
/// then any unrecognised ones in the order they first appear.
///
/// The Stats tab only offers a sport filter when this has more than one
/// entry — a single-sport athlete has nothing to choose between.
List<String> sportsPlayed(List<Map<String, dynamic>> stats) {
  final seen = <String>[];
  for (final s in stats) {
    final sport = (s['sport'] as String? ?? '').trim();
    if (sport.isNotEmpty && !seen.contains(sport)) seen.add(sport);
  }
  return [
    ..._kSportOrder.where(seen.contains),
    ...seen.where((s) => !_kSportOrder.contains(s)),
  ];
}

/// [stats] narrowed to one [sport], or all of them when [sport] is null.
/// Keeps the input's order.
List<Map<String, dynamic>> filterBySport(
    List<Map<String, dynamic>> stats, String? sport) {
  if (sport == null) return stats;
  return stats.where((s) => s['sport'] == sport).toList();
}

/// The games the points chart draws: the [count] most recent, oldest first,
/// so time runs left to right.
///
/// [stats] arrives newest first. The chart used to take
/// `stats.reversed.take(count)`, which is the *oldest* games — so from the
/// seventh game on, an athlete's recent games fell off their own chart.
List<Map<String, dynamic>> chartGames(List<Map<String, dynamic>> stats,
    {int count = 6}) {
  return stats.take(count).toList().reversed.toList();
}

/// A game's Homegrown points, which Firestore may hand back as a double.
int gamePoints(Map<String, dynamic> game) =>
    (game['pointsAwarded'] as num?)?.toInt() ?? 0;

/// The newest game against the athlete's average before it.
typedef LastGameTrend = ({int latest, int previousAvg, int? percent});

/// The trend card's headline: how the most recent game in [stats] compares
/// with the games before it. Null with fewer than two games — there is
/// nothing to compare against yet.
///
/// [LastGameTrend.percent] is measured against the exact average, so it can
/// differ by a point from one worked out by hand from the rounded
/// [LastGameTrend.previousAvg]. It is null when that average rounds to zero:
/// tune-ups earn no points, so an athlete can have nothing but zeros behind
/// them, and a percentage of nothing is meaningless.
LastGameTrend? lastGameTrend(List<Map<String, dynamic>> stats) {
  if (stats.length < 2) return null;
  final latest = gamePoints(stats.first);
  final earlier = stats.skip(1).map(gamePoints);
  final avg = earlier.reduce((a, b) => a + b) / earlier.length;
  final previousAvg = avg.round();
  return (
    latest: latest,
    previousAvg: previousAvg,
    percent: previousAvg == 0 ? null : ((latest - avg) / avg * 100).round(),
  );
}

/// The game in [stats] that earned the most points, the more recent one on a
/// tie.
///
/// Null for fewer than two games, since the best of one game is just that
/// game, and when nothing has scored, since a tune-up's zero is no one's best.
Map<String, dynamic>? bestGame(List<Map<String, dynamic>> stats) {
  if (stats.length < 2) return null;
  var best = stats.first;
  // Strictly greater, and [stats] is newest first, so a tie keeps the newer.
  for (final game in stats.skip(1)) {
    if (gamePoints(game) > gamePoints(best)) best = game;
  }
  return gamePoints(best) > 0 ? best : null;
}

/// A one-line box score for a single game, in the sport's own numbers rather
/// than Homegrown points — "28 PTS · 6 REB · 4 AST" means something to a
/// player that "+105" doesn't. Empty for a sport it doesn't know.
String boxScoreLine(String sport, Map<String, dynamic> stats) {
  int n(String key) => (stats[key] as num?)?.toInt() ?? 0;
  switch (sport) {
    case 'Basketball':
      return '${n('points')} PTS · ${n('rebounds')} REB · ${n('assists')} AST';
    case 'Volleyball':
      return '${n('kills')} K · ${n('aces')} ACE · ${n('digs')} DIG';
    case 'Badminton':
      final sets = n('setsWon');
      return '${stats['matchWon'] == true ? 'Win' : 'Loss'}'
          ' · $sets ${sets == 1 ? 'set' : 'sets'}'
          ' · ${n('pointsScored')} pts';
    default:
      return '';
  }
}

/// One tile of the dashboard's per-game averages.
typedef StatAverage = ({String label, String value});

/// The athlete's per-game box-score averages for [sport] across [stats]: the
/// first four categories in Scout's order (Badminton only has three).
///
/// Built on [averageStats] and [formatStatAverage], so the figures an athlete
/// sees here are the ones a coach sees about them in Scout. Tune-ups count:
/// they earn no points, but the box score is still real.
List<StatAverage> boxScoreAverages(
    String sport, List<Map<String, dynamic>> stats) {
  final averages = averageStats(sport, [
    for (final game in stats)
      (game['stats'] as Map?)?.cast<String, dynamic>() ?? {},
  ]);
  if (averages.isEmpty) return const [];
  return [
    for (final skill in (kScoutSkills[sport] ?? const <ScoutSkill>[]).take(4))
      if (averages[skill.statKey] case final value?)
        skill.statKey == 'Win Rate %'
            ? (label: 'Win rate', value: '${value.round()}%')
            : (
                label: '${_sentenceCase(skill.statKey)} / game',
                value: formatStatAverage(value),
              ),
  ];
}

/// "Points Scored" → "Points scored".
String _sentenceCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
