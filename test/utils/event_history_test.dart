// test/utils/event_history_test.dart
//
// The bucketing and ordering behind My Events. This is the whole reason the
// logic was pulled out of my_events_screen.dart: the screen itself reaches
// FirebaseFirestore.instance and cannot be pumped, but the rule deciding
// which tab an event lands in — and in what order — is where the real bugs
// would be.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/event_history.dart';

// A fixed "now" so the tests never depend on the wall clock.
final _now = DateTime(2026, 6, 15, 12, 0);

Map<String, dynamic> _event({
  required String name,
  DateTime? date,
  String status = 'upcoming',
}) =>
    {
      'name': name,
      'status': status,
      if (date != null) 'eventDate': Timestamp.fromDate(date),
    };

List<String> _names(List<Map<String, dynamic>> events, EventTab tab) =>
    eventsForTab(events, data: (e) => e, tab: tab, now: _now)
        .map((e) => e['name'] as String)
        .toList();

void main() {
  group('eventsForTab', () {
    test('splits events either side of now', () {
      final events = [
        _event(name: 'past', date: _now.subtract(const Duration(days: 3))),
        _event(name: 'future', date: _now.add(const Duration(days: 3))),
      ];

      expect(_names(events, EventTab.upcoming), ['future']);
      expect(_names(events, EventTab.past), ['past']);
    });

    test('orders upcoming soonest first', () {
      final events = [
        _event(name: 'later', date: _now.add(const Duration(days: 9))),
        _event(name: 'sooner', date: _now.add(const Duration(days: 2))),
        _event(name: 'middle', date: _now.add(const Duration(days: 5))),
      ];

      expect(_names(events, EventTab.upcoming),
          ['sooner', 'middle', 'later']);
    });

    // The opposite direction on purpose: history is scanned newest-first.
    test('orders past most recent first', () {
      final events = [
        _event(name: 'oldest', date: _now.subtract(const Duration(days: 30))),
        _event(name: 'newest', date: _now.subtract(const Duration(days: 1))),
        _event(name: 'middle', date: _now.subtract(const Duration(days: 10))),
      ];

      expect(_names(events, EventTab.past), ['newest', 'middle', 'oldest']);
    });

    // An event created without a date is still being scheduled, so it belongs
    // with the upcoming work rather than vanishing into history.
    test('keeps an undated event in upcoming, ordered last', () {
      final events = [
        _event(name: 'undated'),
        _event(name: 'dated', date: _now.add(const Duration(days: 4))),
      ];

      expect(_names(events, EventTab.upcoming), ['dated', 'undated']);
      expect(_names(events, EventTab.past), isEmpty);
    });

    // Drafts are organizer-only everywhere else in the app, and this list is
    // the organizer's own, so they belong in it.
    test('keeps a draft in upcoming', () {
      final events = [
        _event(
            name: 'draft',
            date: _now.add(const Duration(days: 2)),
            status: 'draft'),
      ];

      expect(_names(events, EventTab.upcoming), ['draft']);
    });

    // Deliberate, and worth pinning down because it is surprising: a
    // cancelled event is not something the organizer still has to run, so it
    // leaves the Upcoming tab the moment it is cancelled rather than when its
    // date passes. This matches the home screen's existing sheet.
    test('puts a cancelled future event in past, not upcoming', () {
      final events = [
        _event(
            name: 'called off',
            date: _now.add(const Duration(days: 7)),
            status: 'cancelled'),
      ];

      expect(_names(events, EventTab.upcoming), isEmpty);
      expect(_names(events, EventTab.past), ['called off']);
    });

    // Firestore enforces no schema, so a hand-edited document can hold a
    // string where a Timestamp belongs. It must not take the list down.
    test('treats a malformed date as undated rather than throwing', () {
      final events = [
        {'name': 'broken', 'status': 'upcoming', 'eventDate': 'tomorrow'},
      ];

      expect(_names(events, EventTab.upcoming), ['broken']);
    });

    test('returns an empty list for no events', () {
      expect(_names([], EventTab.upcoming), isEmpty);
      expect(_names([], EventTab.past), isEmpty);
    });
  });

  group('badgeFor', () {
    test('reads cancelled and draft off status', () {
      expect(badgeFor(_event(name: 'a', status: 'cancelled')),
          EventBadge.cancelled);
      expect(badgeFor(_event(name: 'a', status: 'draft')), EventBadge.draft);
    });

    // The case status cannot answer: nothing ever writes 'completed', so a
    // played game still reads 'upcoming' in Firestore forever.
    test('derives completed from the date, not from status', () {
      final played = _event(
          name: 'a',
          date: _now.subtract(const Duration(days: 1)),
          status: 'upcoming');

      expect(badgeFor(played, now: _now), EventBadge.completed);
    });

    test('marks a future event upcoming', () {
      final soon = _event(name: 'a', date: _now.add(const Duration(days: 1)));

      expect(badgeFor(soon, now: _now), EventBadge.upcoming);
    });

    test('labels every badge in uppercase', () {
      expect(badgeLabel(EventBadge.upcoming), 'UPCOMING');
      expect(badgeLabel(EventBadge.completed), 'COMPLETED');
      expect(badgeLabel(EventBadge.draft), 'DRAFT');
      expect(badgeLabel(EventBadge.cancelled), 'CANCELLED');
    });
  });

  // Record Match and Add Stats: the game that just ended is the one being
  // entered, so it must come first, not sink to the bottom.
  group('eventsForResults', () {
    List<String> resultsOrder(List<Map<String, dynamic>> events) =>
        eventsForResults(events, data: (e) => e, now: _now)
            .map((e) => e['name'] as String)
            .toList();

    test('puts the most recently played game first', () {
      final events = [
        _event(name: 'last month', date: _now.subtract(const Duration(days: 30))),
        _event(name: 'yesterday', date: _now.subtract(const Duration(days: 1))),
        _event(name: 'last week', date: _now.subtract(const Duration(days: 7))),
      ];

      expect(resultsOrder(events), ['yesterday', 'last week', 'last month']);
    });

    test('lists games still to come after the played ones, soonest first', () {
      final events = [
        _event(name: 'next month', date: _now.add(const Duration(days: 30))),
        _event(name: 'yesterday', date: _now.subtract(const Duration(days: 1))),
        _event(name: 'tomorrow', date: _now.add(const Duration(days: 1))),
      ];

      expect(resultsOrder(events), ['yesterday', 'tomorrow', 'next month']);
    });

    test('an empty list stays empty', () {
      expect(resultsOrder([]), isEmpty);
    });
  });
}
