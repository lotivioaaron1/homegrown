// lib/utils/stats_view.dart

// What the Stats tab shows, as pure decisions over the athlete's `stats`
// documents (already decoded to maps and sorted newest first).
//
// Athletes can play several sports, but the tab was written for one: every
// game went into a single chart and history with nothing saying which sport it
// was. A basketball-and-volleyball athlete saw their 12-point basketball night
// and their 8-kill volleyball match as two unlabelled bars.

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
