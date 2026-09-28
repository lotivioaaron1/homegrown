// lib/utils/event_sport_filter.dart

/// The order sports appear in everywhere else in the app.
const _kSportOrder = ['Basketball', 'Volleyball', 'Badminton'];

/// The sports a multi-sport organizer can filter My Events by: every sport on
/// their profile, since a sport with nothing scheduled yet is still theirs,
/// plus any sport they have events in, since dropping a sport from the
/// profile doesn't remove its old events. Blanks and repeats are dropped; the
/// usual three come first, anything else after them alphabetically.
List<String> sportFilterOptions({
  required List<String> organized,
  required Iterable<String> eventSports,
}) {
  final sports = {...organized, ...eventSports}
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final others = sports.where((s) => !_kSportOrder.contains(s)).toList()
    ..sort();
  return [..._kSportOrder.where(sports.contains), ...others];
}

/// The events for one sport, or all of them when [sport] is null. An event
/// with no sport set only appears unfiltered.
List<T> eventsForSport<T>(
  Iterable<T> events, {
  required Map<String, dynamic> Function(T) data,
  String? sport,
}) =>
    sport == null
        ? events.toList()
        : events.where((e) => data(e)['sport'] == sport).toList();
