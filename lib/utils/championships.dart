// lib/utils/championships.dart
//
// Who a tournament title belongs to, and which titles each showcase (profile
// shelf, team page, Home spotlight) lists. Pure, so it's tested without
// Firebase.

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

/// "Champion" for one title, "3× Champion" for more.
String titleCountLabel(int count) =>
    count <= 1 ? 'Champion' : '$count× Champion';
