// lib/utils/event_history.dart

import 'firestore_helpers.dart';

/// Which half of the organizer's event list is being shown.
enum EventTab {
  /// Games still to come, soonest first — the order the list is actually
  /// scanned in when deciding what to prepare for next.
  upcoming,

  /// Games already played, most recent first, for the same reason in reverse.
  past,
}

/// Splits a set of event documents into one tab's worth of rows, ordered.
///
/// Kept out of the screen and free of Firestore's query types — [data] pulls
/// the raw map out of whatever the caller is holding — so the bucketing and
/// the sort can be unit-tested with plain maps, which is the whole reason this
/// project's testable logic lives under `lib/utils/`.
///
/// The bucket comes from [isEventUpcoming], not from the `status` field:
/// `status` is written once at creation and never updated when a game is
/// actually played, so a finished event still reads 'upcoming' forever. The
/// one thing `status` does own is cancellation, which [isEventUpcoming]
/// already folds in — which is why a cancelled event lands in Past even when
/// its date has not arrived yet. That matches the "View All Events" sheet on
/// the home screen, and is deliberate: a cancelled game is not something the
/// organizer still has to run.
///
/// Drafts stay in Upcoming. They are organizer-only everywhere in the app, and
/// an undated draft is one still being scheduled rather than one that never
/// happened.
List<T> eventsForTab<T>(
  Iterable<T> events, {
  required Map<String, dynamic> Function(T) data,
  required EventTab tab,
  DateTime? now,
}) {
  final showPast = tab == EventTab.past;

  final rows = events
      .where((e) => isEventUpcoming(data(e), now: now) != showPast)
      .toList();

  rows.sort((a, b) {
    final aT = asTimestamp(data(a)['eventDate']);
    final bT = asTimestamp(data(b)['eventDate']);
    // An undated draft has no place on the timeline, so it sorts last in
    // either direction rather than jumping to the head of the list.
    if (aT == null && bT == null) return 0;
    if (aT == null) return 1;
    if (bT == null) return -1;
    return showPast ? bT.compareTo(aT) : aT.compareTo(bT);
  });

  return rows;
}

/// Every event in the order an organizer looks for it when entering results:
/// games already played, most recent first — the one that just ended is almost
/// always the one being recorded — then games still to come, soonest first.
///
/// Record Match and Add Stats used to list these unsorted or oldest first under
/// an "Upcoming" heading, which put the game that had just been played at the
/// bottom of a list that claimed it wasn't there. Their queries already drop
/// drafts and cancelled events, so this only orders.
List<T> eventsForResults<T>(
  Iterable<T> events, {
  required Map<String, dynamic> Function(T) data,
  DateTime? now,
}) =>
    [
      ...eventsForTab(events, data: data, tab: EventTab.past, now: now),
      ...eventsForTab(events, data: data, tab: EventTab.upcoming, now: now),
    ];

/// Whether a match result has been recorded for this event. RatingService
/// sets `hasMatchData` in the same write that records the match.
bool hasResult(Map<String, dynamic> event) => event['hasMatchData'] == true;

/// Whether Record Match may take a result for this event: a real game whose
/// start time has passed and that has no result yet. The one-result part is
/// also enforced by the Firestore rules.
bool canRecordResult(Map<String, dynamic> event, {DateTime? now}) {
  final status = event['status'];
  if (status == 'draft' || status == 'cancelled') return false;
  return !isEventUpcoming(event, now: now) && !hasResult(event);
}

/// The badge an event row carries, derived the same way the bucket is.
enum EventBadge { upcoming, awaitingResult, completed, draft, cancelled }

/// The badge for one event document.
///
/// Cancelled and draft are read off `status`. A game is completed only once
/// its result is recorded; a past game without one is awaiting its result.
EventBadge badgeFor(Map<String, dynamic> event, {DateTime? now}) {
  if (event['status'] == 'cancelled') return EventBadge.cancelled;
  if (event['status'] == 'draft') return EventBadge.draft;
  if (hasResult(event)) return EventBadge.completed;
  return isEventUpcoming(event, now: now)
      ? EventBadge.upcoming
      : EventBadge.awaitingResult;
}

/// The uppercase label shown in the pill.
String badgeLabel(EventBadge badge) => switch (badge) {
      EventBadge.upcoming => 'UPCOMING',
      EventBadge.awaitingResult => 'AWAITING RESULT',
      EventBadge.completed => 'COMPLETED',
      EventBadge.draft => 'DRAFT',
      EventBadge.cancelled => 'CANCELLED',
    };
