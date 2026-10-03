// lib/utils/home_tournaments.dart
//
// Which of an organizer's tournaments the Tournaments card on Home shows.
// An organizer covering several sports runs one bracket per sport side by
// side, so showing only the newest one hid the others. Pure, so it's tested
// without Firebase.

import '../models/tournament.dart';

/// The tournaments Home lists, from [all] in newest-first order (as
/// TournamentService.forOrganizer returns them).
///
/// Every bracket still being played, up to [max]; the rest are a tap away
/// on View All. When none is running, the newest of any status instead, so
/// a champion just crowned stays on Home rather than the card going empty.
List<Tournament> homeTournaments(List<Tournament> all, {int max = 3}) {
  final running =
      all.where((t) => !t.isCompleted && !t.isCancelled).take(max).toList();
  if (running.isNotEmpty) return running;
  return all.take(1).toList();
}
