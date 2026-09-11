// lib/utils/leaderboard_ranks.dart

// How ranks are numbered and shown, as pure decisions.
//
// Ties share a rank (1, 2, 2, 4), which is the conventional reading and the
// one RankingService.cityRank already uses. What changed is athletes who have
// never been scored: they used to be ranked too, and because they all sit on
// the same value they all tied for first. With no stats recorded anywhere,
// every athlete in the city was told "City Rank #1" on zero points, and the
// leaderboard podium was three #1s. An athlete with nothing recorded is now
// unranked instead — shown as "—" and kept off the podium.

/// The City Rank as shown on Home, the dashboard and Settings.
///
/// [rank] is the result of RankingService.cityRank, or null while it loads.
/// An athlete on zero points is unranked whatever the query would say.
String cityRankLabel({required int points, int? rank}) {
  if (points <= 0) return '—';
  return rank == null ? '#—' : '#$rank';
}

/// Ranks for a board already sorted best-first, one entry per item: the rank
/// it holds, or null when [isUnranked] says it has not earned one.
///
/// Equal values share a rank and consume the numbers behind them. Unranked
/// items neither receive a number nor use one up, so a board of
/// `[50, unranked, 40]` reads 1, —, 2. Callers are expected to sort unranked
/// items last, but a stray one in the middle still does not shift the rest.
List<int?> assignRanks<T>(
  List<T> sorted, {
  required num Function(T item) valueOf,
  bool Function(T item)? isUnranked,
}) {
  final ranks = <int?>[];
  var rankedSoFar = 0;
  int? previousRank;
  num? previousValue;

  for (final item in sorted) {
    if (isUnranked?.call(item) ?? false) {
      ranks.add(null);
      continue;
    }
    rankedSoFar++;
    final value = valueOf(item);
    final rank = (previousValue != null && value == previousValue)
        ? previousRank!
        : rankedSoFar;
    ranks.add(rank);
    previousRank = rank;
    previousValue = value;
  }
  return ranks;
}
