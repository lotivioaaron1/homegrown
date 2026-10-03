// lib/utils/organizer_breakdown.dart

import '../models/tournament.dart';
import 'event_history.dart';
import 'event_sport_filter.dart';

/// One line of a breakdown: a label and how many fall under it.
class BreakdownRow {
  final String label;
  final int count;
  const BreakdownRow(this.label, this.count);
}

/// What sits behind the Events Created total on an organizer's profile.
class EventBreakdown {
  final int total;
  final List<BreakdownRow> byStatus;
  final List<BreakdownRow> bySport;

  /// Games the organizer created themselves, as opposed to [tournamentGames],
  /// which a bracket wrote for them. Both count towards Events Created.
  final int scheduled;
  final int tournamentGames;

  const EventBreakdown({
    required this.total,
    required this.byStatus,
    required this.bySport,
    required this.scheduled,
    required this.tournamentGames,
  });
}

/// What sits behind the Tournaments Run total on an organizer's profile.
class TournamentBreakdown {
  final int total;
  final List<BreakdownRow> byStatus;
  final List<BreakdownRow> bySport;

  const TournamentBreakdown({
    required this.total,
    required this.byStatus,
    required this.bySport,
  });
}

const _kNoSport = 'No sport';

/// Status groups in the order My Events lists them, upcoming first.
const _kEventStatusOrder = [
  (EventBadge.upcoming, 'Upcoming'),
  (EventBadge.awaitingResult, 'Awaiting result'),
  (EventBadge.completed, 'Completed'),
  (EventBadge.draft, 'Draft'),
  (EventBadge.cancelled, 'Cancelled'),
];

/// Counts an organizer's events by status, sport, and whether a bracket made
/// them.
///
/// Status comes from [badgeFor], never from the `status` field — that field
/// still says 'upcoming' after a game is played — so the groups and numbers
/// match My Events. Every bracket game is an event document too, which is why
/// Events Created can be larger than the number of games an organizer
/// remembers creating; [EventBreakdown.tournamentGames] is that difference.
///
/// Empty groups are left out, and an event with no sport is counted as
/// "No sport", so every section adds up to [EventBreakdown.total].
EventBreakdown eventBreakdown(Iterable<Map<String, dynamic>> events,
    {DateTime? now}) {
  final list = events.toList();

  final badges = <EventBadge, int>{};
  var tournamentGames = 0;
  for (final e in list) {
    final badge = badgeFor(e, now: now);
    badges[badge] = (badges[badge] ?? 0) + 1;
    if (e['tournamentId'] != null) tournamentGames++;
  }

  return EventBreakdown(
    total: list.length,
    byStatus: [
      for (final (badge, label) in _kEventStatusOrder)
        if ((badges[badge] ?? 0) > 0) BreakdownRow(label, badges[badge]!),
    ],
    bySport: _bySport(list),
    scheduled: list.length - tournamentGames,
    tournamentGames: tournamentGames,
  );
}

/// Counts an organizer's tournaments by status and sport.
///
/// Status is labelled the way the Tournaments list labels it: completed,
/// cancelled, and everything else — active or draft — "In progress".
TournamentBreakdown tournamentBreakdown(
    Iterable<Map<String, dynamic>> tournaments) {
  final list = tournaments.toList();

  var completed = 0, cancelled = 0;
  for (final t in list) {
    if (t['status'] == Tournament.statusCompleted) {
      completed++;
    } else if (t['status'] == Tournament.statusCancelled) {
      cancelled++;
    }
  }
  final inProgress = list.length - completed - cancelled;

  return TournamentBreakdown(
    total: list.length,
    byStatus: [
      if (inProgress > 0) BreakdownRow('In progress', inProgress),
      if (completed > 0) BreakdownRow('Completed', completed),
      if (cancelled > 0) BreakdownRow('Cancelled', cancelled),
    ],
    bySport: _bySport(list),
  );
}

/// Counts by sport in the app's usual sport order, with "No sport" last.
List<BreakdownRow> _bySport(List<Map<String, dynamic>> docs) {
  final counts = <String, int>{};
  for (final d in docs) {
    final raw = (d['sport'] as String? ?? '').trim();
    final sport = raw.isEmpty ? _kNoSport : raw;
    counts[sport] = (counts[sport] ?? 0) + 1;
  }
  final order = sportFilterOptions(
      organized: const [],
      eventSports: counts.keys.where((s) => s != _kNoSport));
  return [
    for (final s in order) BreakdownRow(s, counts[s]!),
    if (counts.containsKey(_kNoSport))
      BreakdownRow(_kNoSport, counts[_kNoSport]!),
  ];
}
