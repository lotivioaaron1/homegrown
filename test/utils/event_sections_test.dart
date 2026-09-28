// test/utils/event_sections_test.dart
//
// How My Events' Past tab is grouped: games still waiting for a result first,
// then finished ones, then the ones that never happened.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/event_history.dart';
import 'package:homegrown/utils/event_sections.dart';

// A fixed "now" so the tests never depend on the wall clock.
final _now = DateTime(2026, 6, 15, 12, 0);

Map<String, dynamic> _event(
  String name, {
  int daysAgo = 1,
  String status = 'upcoming',
  bool recorded = false,
}) =>
    {
      'name': name,
      'status': status,
      'eventDate': Timestamp.fromDate(_now.subtract(Duration(days: daysAgo))),
      if (recorded) 'hasMatchData': true,
    };

List<EventSection<Map<String, dynamic>>> _sections(
        List<Map<String, dynamic>> events) =>
    pastSections(events, data: (e) => e, now: _now);

List<String> _names(EventSection<Map<String, dynamic>> section) =>
    section.events.map((e) => e['name'] as String).toList();

void main() {
  group('pastSections', () {
    test('puts games awaiting a result first, then completed, then cancelled',
        () {
      final events = [
        _event('done', recorded: true),
        _event('called off', status: 'cancelled'),
        _event('needs result'),
      ];

      expect(_sections(events).map((s) => s.badge), [
        EventBadge.awaitingResult,
        EventBadge.completed,
        EventBadge.cancelled,
      ]);
    });

    test('keeps each group most recent first', () {
      final events = [
        _event('last month', daysAgo: 30),
        _event('yesterday', daysAgo: 1),
        _event('last week', daysAgo: 7),
      ];

      expect(_names(_sections(events).single),
          ['yesterday', 'last week', 'last month']);
    });

    test('leaves out a group with nothing in it', () {
      final sections = _sections([_event('done', recorded: true)]);

      expect(sections.map((s) => s.badge), [EventBadge.completed]);
      expect(_names(sections.single), ['done']);
    });

    test('ignores games still to come', () {
      final tomorrow = {
        'name': 'tomorrow',
        'status': 'upcoming',
        'eventDate': Timestamp.fromDate(_now.add(const Duration(days: 1))),
      };

      expect(_sections([tomorrow]), isEmpty);
    });

    // A draft whose date passed without being published still lands in Past,
    // so it needs somewhere to go rather than disappearing.
    test('gives a lapsed draft its own group before cancelled', () {
      final events = [
        _event('called off', status: 'cancelled'),
        _event('never published', status: 'draft'),
      ];

      expect(_sections(events).map((s) => s.badge),
          [EventBadge.draft, EventBadge.cancelled]);
    });

    test('places every past event in exactly one group', () {
      final events = [
        _event('a'),
        _event('b', recorded: true),
        _event('c', status: 'cancelled'),
        _event('d', status: 'draft'),
        _event('e', daysAgo: 4),
      ];

      final placed = _sections(events).expand(_names).toList();

      expect(placed, unorderedEquals(['a', 'b', 'c', 'd', 'e']));
    });

    test('returns no groups for no events', () {
      expect(_sections([]), isEmpty);
    });
  });

  group('awaitingResultCount', () {
    test('counts only played games with no result', () {
      final events = [
        _event('needs result'),
        _event('also needs result', daysAgo: 5),
        _event('done', recorded: true),
        _event('called off', status: 'cancelled'),
        {
          'name': 'tomorrow',
          'status': 'upcoming',
          'eventDate': Timestamp.fromDate(_now.add(const Duration(days: 1))),
        },
      ];

      expect(awaitingResultCount(events, data: (e) => e, now: _now), 2);
    });

    test('is zero for no events', () {
      expect(awaitingResultCount(<Map<String, dynamic>>[],
              data: (e) => e, now: _now),
          0);
    });
  });
}
