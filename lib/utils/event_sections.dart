// lib/utils/event_sections.dart

import 'event_history.dart';

/// One heading's worth of rows on My Events' Past tab.
class EventSection<T> {
  final EventBadge badge;
  final List<T> events;
  const EventSection(this.badge, this.events);
}

/// The order the Past groups appear in: the organizer's to-do first, then
/// history, then games that never happened. Every past event is one of these
/// four, since [badgeFor] only says upcoming for a game still to come.
const _kPastOrder = [
  EventBadge.awaitingResult,
  EventBadge.completed,
  EventBadge.draft,
  EventBadge.cancelled,
];

/// The Past tab split into groups by badge, skipping empty ones. Each group
/// keeps [eventsForTab]'s most-recent-first order.
List<EventSection<T>> pastSections<T>(
  Iterable<T> events, {
  required Map<String, dynamic> Function(T) data,
  DateTime? now,
}) {
  final rows = eventsForTab(events, data: data, tab: EventTab.past, now: now);
  final sections = <EventSection<T>>[];
  for (final badge in _kPastOrder) {
    final group =
        rows.where((e) => badgeFor(data(e), now: now) == badge).toList();
    if (group.isNotEmpty) sections.add(EventSection(badge, group));
  }
  return sections;
}

/// How many games have been played but still have no result, shown on the
/// Past toggle so the organizer sees them from the Upcoming tab too.
int awaitingResultCount<T>(
  Iterable<T> events, {
  required Map<String, dynamic> Function(T) data,
  DateTime? now,
}) =>
    events
        .where((e) => badgeFor(data(e), now: now) == EventBadge.awaitingResult)
        .length;
