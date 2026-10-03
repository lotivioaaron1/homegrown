// lib/utils/championships.dart
//
// Who a tournament title belongs to, which titles each showcase (profile
// shelf, team page, Home spotlight) lists, and what the championship page
// reports: the final standings and the champion's per-game averages. Pure,
// so it's tested without Firebase.

import 'dart:math' as math;

import '../models/bracket_slot.dart';
import '../models/tournament.dart';
import 'bracket.dart';
import 'stat_scoring.dart';

/// Whether [uid] won [t]: the champion's coach, or a player on the roster the
/// champion entered with. The roster is the snapshot taken at entry, so a
/// player who joined the team afterwards isn't credited and one who has since
/// left still is.
bool isChampion(Tournament t, String uid) {
  final coachId = t.championCoachId;
  if (!t.isCompleted || coachId == null || uid.isEmpty) return false;
  if (coachId == uid) return true;
  return t.entrantFor(coachId)?.players.any((p) => p.uid == uid) ?? false;
}

List<Tournament> _newestFirst(Iterable<Tournament> ts) => ts.toList()
  ..sort((a, b) => (b.completedAt ?? DateTime(0))
      .compareTo(a.completedAt ?? DateTime(0)));

/// The titles [uid] has won, newest first.
List<Tournament> titlesFor(Iterable<Tournament> ts, String uid) =>
    _newestFirst(ts.where((t) => isChampion(t, uid)));

/// The titles won by [coachId]'s team, newest first.
List<Tournament> teamTitles(Iterable<Tournament> ts, String coachId) =>
    _newestFirst(ts.where(
        (t) => t.isCompleted && coachId.isNotEmpty && t.championCoachId == coachId));

/// The finished tournaments [coachId]'s team played in, won or not, newest
/// first. A title counts even if its entrant can't be found, so the record
/// never shows more titles than tournaments played.
List<Tournament> tournamentsPlayed(Iterable<Tournament> ts, String coachId) =>
    _newestFirst(ts.where((t) =>
        t.isCompleted &&
        coachId.isNotEmpty &&
        (t.entrantFor(coachId) != null || t.championCoachId == coachId)));

/// A team's tournament record in one line: "3 played · 1 title".
String tournamentRecordLabel(int played, int titles) {
  if (played == 0) return 'No tournaments finished yet';
  final won = switch (titles) {
    0 => 'no titles yet',
    1 => '1 title',
    _ => '$titles titles',
  };
  return '$played played · $won';
}

/// The team [uid] played for in [t]: the entrant whose roster, as entered,
/// lists them. Null when they weren't on any.
TournamentEntrant? entrantWith(Tournament t, String uid) {
  if (uid.isEmpty) return null;
  for (final e in t.entrants) {
    if (e.players.any((p) => p.uid == uid)) return e;
  }
  return null;
}

/// The finished tournaments [uid] played in, won or not, newest first: the
/// athlete's counterpart to [tournamentsPlayed].
List<Tournament> tournamentsPlayedBy(Iterable<Tournament> ts, String uid) =>
    _newestFirst(ts.where((t) => t.isCompleted && entrantWith(t, uid) != null));

/// How [coachId]'s team finished [t]: "Champion", the runner-up places, or
/// the round it went out in ("Semifinalist", "Quarterfinalist", "Round of
/// 16"). Null when [slots] don't say, e.g. a bracket missing its results.
String? finishLabel(Tournament t, List<BracketSlot> slots, String coachId) {
  if (coachId.isEmpty) return null;
  if (t.championCoachId == coachId) return 'Champion';

  bool inSlot(BracketSlot s) =>
      s.entrantA?.coachId == coachId || s.entrantB?.coachId == coachId;

  for (final s in slots) {
    if (s.isThirdPlace && s.isDecided && inSlot(s)) {
      return s.winnerCoachId == coachId ? '2nd runner-up' : '3rd runner-up';
    }
  }

  // Single elimination: the one game the team lost is where its run ended.
  for (final s in slots) {
    if (s.isThirdPlace || s.isBye || !s.isDecided || !inSlot(s)) continue;
    if (s.winnerCoachId == coachId) continue;
    final fromEnd = t.roundCount - s.round;
    if (fromEnd == 0) return '1st runner-up';
    if (fromEnd == 1) return 'Semifinalist';
    if (fromEnd == 2) return 'Quarterfinalist';
    return roundLabel(s.round, t.roundCount);
  }
  return null;
}

/// Tournaments won in the last [days] days, newest first, for the Home
/// spotlight. [exceptOrganizer] leaves out the ones that organizer ran: their
/// own Home already names each champion on its Tournaments card.
List<Tournament> recentChampions(
  Iterable<Tournament> ts, {
  DateTime? now,
  int days = 7,
  String? exceptOrganizer,
}) {
  final since = (now ?? DateTime.now()).subtract(Duration(days: days));
  return _newestFirst(ts.where((t) =>
      t.isCompleted &&
      t.championCoachId != null &&
      t.completedAt != null &&
      t.completedAt!.isAfter(since) &&
      (exceptOrganizer == null || t.organizerId != exceptOrganizer)));
}

/// One team's finishing place.
class Standing {
  /// 1 for the champion down to 4 for the 3rd runner-up. Joint places share
  /// a number.
  final int place;
  final String label;
  final String teamName;

  /// True for the two semifinal losers while nothing separates them: there's
  /// no battle for third, or it hasn't been played.
  final bool joint;

  const Standing(this.place, this.label, this.teamName, {this.joint = false});
}

/// The top four as far as they're decided: champion and 1st runner-up from
/// the final, then 2nd and 3rd runner-up from the battle for third. Until
/// that's played (or in a bracket without one) the semifinal losers share
/// 2nd runner-up.
List<Standing> finalStandings(Tournament t, List<BracketSlot> slots) {
  SlotEntrant? winnerOf(BracketSlot s) => s.winner;
  SlotEntrant? loserOf(BracketSlot s) =>
      s.winnerCoachId == s.entrantA?.coachId ? s.entrantB : s.entrantA;

  final standings = <Standing>[];
  for (final s in slots) {
    if (s.round != t.roundCount || s.isThirdPlace || !s.isDecided) continue;
    final champion = winnerOf(s);
    final runnerUp = loserOf(s);
    if (champion != null) standings.add(Standing(1, 'Champion', champion.teamName));
    if (runnerUp != null) {
      standings.add(Standing(2, '1st runner-up', runnerUp.teamName));
    }
  }

  BracketSlot? third;
  for (final s in slots) {
    if (s.isThirdPlace) third = s;
  }
  if (third != null && third.isDecided) {
    final second = winnerOf(third);
    final fourth = loserOf(third);
    if (second != null) {
      standings.add(Standing(3, '2nd runner-up', second.teamName));
    }
    if (fourth != null) {
      standings.add(Standing(4, '3rd runner-up', fourth.teamName));
    }
    return standings;
  }

  final semis = slots
      .where((s) =>
          s.round == t.roundCount - 1 && !s.isThirdPlace && s.isDecided)
      .toList()
    ..sort((a, b) => a.slot.compareTo(b.slot));
  for (final s in semis) {
    final loser = loserOf(s);
    if (loser != null) {
      standings.add(
          Standing(3, 'Joint 2nd runner-up', loser.teamName, joint: true));
    }
  }
  return standings;
}

/// The recorded results of the games [coachId]'s team played, as match ids.
/// Byes and unplayed matchups have no `matchId`, so they drop out.
List<String> matchIdsFor(String coachId, List<BracketSlot> slots) => [
      for (final s in slots)
        if (s.isDecided &&
            s.matchId != null &&
            (s.entrantA?.coachId == coachId || s.entrantB?.coachId == coachId))
          s.matchId!,
    ];

/// A team's box score per game across a tournament.
class TeamAverages {
  /// Category to per-game value, exactly as [averageStats] names them.
  final Map<String, double> averages;

  /// The games the averages are drawn from: those with stats recorded.
  final int games;

  /// Every game the team played, so a missing box score can be called out
  /// rather than quietly dragging the average down.
  final int gamesPlayed;

  const TeamAverages({
    required this.averages,
    required this.games,
    required this.gamesPlayed,
  });
}

/// The champion's per-game team averages, from the players' [statDocs] (the
/// `stats` documents as stored). Each game's lines from the champion's
/// entered roster are added up into one team line, and those are averaged.
/// Null when there is no champion or no stats were recorded for its games.
TeamAverages? championAverages(
  Tournament t,
  List<BracketSlot> slots,
  Iterable<Map<String, dynamic>> statDocs,
) {
  final coachId = t.championCoachId;
  final champion = coachId == null ? null : t.entrantFor(coachId);
  if (champion == null) return null;

  final matchIds = matchIdsFor(champion.coachId, slots);
  final roster = {for (final p in champion.players) p.uid};

  // Keyed by athlete within each game, so a line saved twice counts once.
  final linesByMatch = <String, Map<String, Map<String, dynamic>>>{};
  for (final doc in statDocs) {
    final matchId = doc['matchId'] as String?;
    final athleteId = doc['athleteId'] as String?;
    if (!matchIds.contains(matchId) || !roster.contains(athleteId)) continue;
    linesByMatch.putIfAbsent(matchId!, () => {})[athleteId!] =
        (doc['stats'] as Map?)?.cast<String, dynamic>() ?? {};
  }
  if (linesByMatch.isEmpty) return null;

  final games = [
    for (final lines in linesByMatch.values) _teamLine(t.sport, lines.values),
  ];
  return TeamAverages(
    averages: averageStats(t.sport, games),
    games: games.length,
    gamesPlayed: matchIds.length,
  );
}

/// One game's player lines added up into the team's. Badminton partners are
/// each credited with every set their side won, so the side won the most
/// either of them has, not the sum.
Map<String, dynamic> _teamLine(
    String sport, Iterable<Map<String, dynamic>> lines) {
  final team = <String, dynamic>{};
  for (final line in lines) {
    line.forEach((key, value) {
      if (value is bool) {
        team[key] = team[key] == true || value;
      } else if (value is num) {
        final so = team[key] as num? ?? 0;
        team[key] = sport == 'Badminton' && key == 'setsWon'
            ? math.max(so, value)
            : so + value;
      }
    });
  }
  return team;
}

/// "Champion" for one title, "3× Champion" for more.
String titleCountLabel(int count) =>
    count <= 1 ? 'Champion' : '$count× Champion';
