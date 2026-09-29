// lib/utils/championships.dart
//
// Who a tournament title belongs to, and which titles each showcase (profile
// shelf, team page, Home spotlight) lists. Pure, so it's tested without
// Firebase.

import '../models/bracket_slot.dart';
import '../models/tournament.dart';

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

/// Tournaments won in the last [days] days, newest first, for the Home
/// spotlight.
List<Tournament> recentChampions(
  Iterable<Tournament> ts, {
  DateTime? now,
  int days = 7,
}) {
  final since = (now ?? DateTime.now()).subtract(Duration(days: days));
  return _newestFirst(ts.where((t) =>
      t.isCompleted &&
      t.championCoachId != null &&
      t.completedAt != null &&
      t.completedAt!.isAfter(since)));
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

/// "Champion" for one title, "3× Champion" for more.
String titleCountLabel(int count) =>
    count <= 1 ? 'Champion' : '$count× Champion';
