// lib/utils/team_standings.dart
//
// A team's record for one season, from the official games it played. Elo is
// per player, so before this a team's only record was its tournament line;
// Liga games never added up to anything for the team itself.
//
// A team is one coach in one sport — a coach may coach two sports, and the
// screen asks for one sport at a time. A season is a calendar year in
// Philippine time and is decided by when the game was played, not when its
// result was recorded. Nothing is reset or deleted at New Year: the next
// season is simply the next year's games. Pure, so it's tested without
// Firebase.

import 'event_types.dart';

/// The first season with games in it. The season picker lists none earlier.
const int kFirstSeason = 2026;

/// Philippine time is UTC+8 with no daylight saving, so a fixed offset gives
/// the exact year boundary without a timezone package.
const Duration _kManilaOffset = Duration(hours: 8);

/// The season [t] falls in: its calendar year in Manila.
int seasonOf(DateTime t) => t.toUtc().add(_kManilaOffset).year;

/// The instants [season] starts and ends at (midnight in Manila), for a
/// range query: `start` inclusive, `end` exclusive.
({DateTime start, DateTime end}) seasonBounds(int season) => (
      start: DateTime.utc(season).subtract(_kManilaOffset),
      end: DateTime.utc(season + 1).subtract(_kManilaOffset),
    );

/// Every season from [first] to the one [now] falls in, newest first. Always
/// includes the current season, even on a device whose clock says it's
/// earlier than [first].
List<int> seasonsSince(int first, DateTime now) {
  final current = seasonOf(now);
  final oldest = first < current ? first : current;
  return [for (var y = current; y >= oldest; y--) y];
}

/// One official game between two coaches' teams.
class StandingsGame {
  final String coachA;
  final String coachB;

  /// The team names the event was saved with: a fallback for when a coach's
  /// profile can't be read, since the live name comes from there.
  final String nameA;
  final String nameB;

  final int scoreA;
  final int scoreB;
  final DateTime playedAt;

  const StandingsGame({
    required this.coachA,
    required this.coachB,
    required this.nameA,
    required this.nameB,
    required this.scoreA,
    required this.scoreB,
    required this.playedAt,
  });
}

/// The game [event] and its recorded [match] make, or null when it doesn't
/// count toward standings:
///
/// * a tune-up — the same rule as Elo ([countsTowardRankings]), so a game
///   can't count for one and not the other;
/// * a cancelled event;
/// * a side with no coach (older events, singles brackets) or the same coach
///   on both sides, since a team can't be credited;
/// * a missing or tied score, or no date to place it in a season.
///
/// A match's side A is always the event's Team A, so the coach ids come from
/// the event and the scores from the match.
StandingsGame? standingsGameFrom({
  required Map<String, dynamic> event,
  required Map<String, dynamic> match,
  required DateTime? playedAt,
}) {
  if (!countsTowardRankings(_str(event['eventType']))) return null;
  if (event['status'] == 'cancelled') return null;
  if (playedAt == null) return null;

  final coachA = _str(event['teamACoachId']) ?? '';
  final coachB = _str(event['teamBCoachId']) ?? '';
  if (coachA.isEmpty || coachB.isEmpty || coachA == coachB) return null;

  final scoreA = _int(match['scoreA']);
  final scoreB = _int(match['scoreB']);
  if (scoreA == null || scoreB == null || scoreA == scoreB) return null;

  return StandingsGame(
    coachA: coachA,
    coachB: coachB,
    nameA: _str(event['teamAName']) ?? '',
    nameB: _str(event['teamBName']) ?? '',
    scoreA: scoreA,
    scoreB: scoreB,
    playedAt: playedAt,
  );
}

// Type-checked reads, so one malformed document is skipped rather than
// failing the whole table. firestore_helpers.dart has the same guards but
// imports Firestore, which this file stays free of.
String? _str(dynamic v) => v is String ? v : null;
int? _int(dynamic v) => v is num ? v.toInt() : null;

/// One team's line in the table.
class TeamStanding {
  final String coachId;

  /// The name from the team's most recent game.
  final String storedName;

  final int wins;
  final int losses;

  /// Points (sets, in badminton) scored and conceded.
  final int pointsFor;
  final int pointsAgainst;

  const TeamStanding({
    required this.coachId,
    required this.storedName,
    required this.wins,
    required this.losses,
    required this.pointsFor,
    required this.pointsAgainst,
  });

  /// No game ends in a draw, so wins and losses are every game played.
  int get played => wins + losses;

  double get winPct => played == 0 ? 0 : wins / played;

  int get diff => pointsFor - pointsAgainst;
}

/// Every team that played in [games], best first: win percentage, then wins,
/// then point difference, then name so the order never shuffles.
List<TeamStanding> computeStandings(Iterable<StandingsGame> games) {
  final wins = <String, int>{};
  final losses = <String, int>{};
  final pointsFor = <String, int>{};
  final pointsAgainst = <String, int>{};
  final names = <String, ({String name, DateTime at})>{};

  void credit(String coach, String name, int scored, int conceded,
      DateTime at) {
    final won = scored > conceded;
    wins[coach] = (wins[coach] ?? 0) + (won ? 1 : 0);
    losses[coach] = (losses[coach] ?? 0) + (won ? 0 : 1);
    pointsFor[coach] = (pointsFor[coach] ?? 0) + scored;
    pointsAgainst[coach] = (pointsAgainst[coach] ?? 0) + conceded;
    final latest = names[coach];
    if (latest == null || at.isAfter(latest.at)) {
      names[coach] = (name: name, at: at);
    }
  }

  for (final g in games) {
    credit(g.coachA, g.nameA, g.scoreA, g.scoreB, g.playedAt);
    credit(g.coachB, g.nameB, g.scoreB, g.scoreA, g.playedAt);
  }

  final table = [
    for (final coach in wins.keys)
      TeamStanding(
        coachId: coach,
        storedName: names[coach]!.name,
        wins: wins[coach]!,
        losses: losses[coach]!,
        pointsFor: pointsFor[coach]!,
        pointsAgainst: pointsAgainst[coach]!,
      ),
  ];
  table.sort((a, b) {
    final byRecord = _compareRecord(a, b);
    return byRecord != 0 ? byRecord : a.storedName.compareTo(b.storedName);
  });
  return table;
}

/// Best record first. Zero when two teams are level on every tiebreak.
int _compareRecord(TeamStanding a, TeamStanding b) {
  final byPct = b.winPct.compareTo(a.winPct);
  if (byPct != 0) return byPct;
  final byWins = b.wins.compareTo(a.wins);
  if (byWins != 0) return byWins;
  return b.diff.compareTo(a.diff);
}

/// The rank each team in a [computeStandings] table holds. Teams level on
/// every tiebreak share a rank and use up the numbers behind them (1, 1, 3),
/// the same convention as the athlete leaderboard.
List<int> standingRanks(List<TeamStanding> sorted) {
  final ranks = <int>[];
  for (var i = 0; i < sorted.length; i++) {
    final tied = i > 0 && _compareRecord(sorted[i - 1], sorted[i]) == 0;
    ranks.add(tied ? ranks[i - 1] : i + 1);
  }
  return ranks;
}

/// Win percentage as a box score shows it: `.750`, `.000`, `1.000`.
String formatPct(double pct) {
  final fixed = pct.toStringAsFixed(3);
  return fixed.startsWith('0') ? fixed.substring(1) : fixed;
}

/// Point difference with its sign: `+13`, `−18` (a true minus), `0`.
String formatDiff(int diff) =>
    diff > 0 ? '+$diff' : diff < 0 ? '−${-diff}' : '0';

/// Where [coachId]'s team sits in a [computeStandings] table, or null when it
/// hasn't played. [tied] when another team holds the same rank.
({TeamStanding standing, int rank, bool tied})? placeOf(
    List<TeamStanding> table, List<int> ranks, String coachId) {
  final i = table.indexWhere((s) => s.coachId == coachId);
  if (i < 0) return null;
  final rank = ranks[i];
  return (
    standing: table[i],
    rank: rank,
    tied: ranks.where((r) => r == rank).length > 1,
  );
}

/// "3rd of 8", or "Tied 5th of 8" when the place is shared.
String placeLabel(int rank, int teams, {bool tied = false}) {
  final place = '$rank${_ordinalSuffix(rank)} of $teams';
  return tied ? 'Tied $place' : place;
}

String _ordinalSuffix(int n) {
  // 11th, 12th and 13th break the 1st/2nd/3rd pattern, and so do 111th–113th.
  if (n % 100 >= 11 && n % 100 <= 13) return 'th';
  return switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
}

/// A team's season in one line: "3–3 · .500 · +13".
String recordLabel(TeamStanding s) =>
    '${s.wins}–${s.losses} · ${formatPct(s.winPct)} · ${formatDiff(s.diff)}';
