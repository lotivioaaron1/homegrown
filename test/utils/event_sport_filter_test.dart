// test/utils/event_sport_filter_test.dart
//
// The sport chips on My Events: which sports an organizer can filter by, and
// what each chip keeps.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/event_sport_filter.dart';

void main() {
  group('sportFilterOptions', () {
    test('joins profile and event sports in the usual sport order', () {
      expect(
          sportFilterOptions(
              organized: ['Badminton', 'Basketball'],
              eventSports: ['Volleyball']),
          ['Basketball', 'Volleyball', 'Badminton']);
    });

    // A sport with no events yet still gets a chip, so the organizer can see
    // there is nothing scheduled in it.
    test('keeps a profile sport that has no events', () {
      expect(
          sportFilterOptions(
              organized: ['Basketball', 'Volleyball'],
              eventSports: ['Basketball', 'Basketball']),
          ['Basketball', 'Volleyball']);
    });

    // An organizer who later drops a sport from their profile still has its
    // old events to look back on.
    test('adds a sport found only on events', () {
      expect(
          sportFilterOptions(
              organized: ['Basketball'], eventSports: ['Volleyball']),
          ['Basketball', 'Volleyball']);
    });

    test('drops blanks and duplicates', () {
      expect(
          sportFilterOptions(
              organized: ['Basketball', ''],
              eventSports: ['Basketball', ' ', 'Basketball']),
          ['Basketball']);
    });

    test('puts an unknown sport after the usual three, alphabetically', () {
      expect(
          sportFilterOptions(
              organized: ['Volleyball'], eventSports: ['Tennis', 'Chess']),
          ['Volleyball', 'Chess', 'Tennis']);
    });

    test('is empty with no sports anywhere', () {
      expect(sportFilterOptions(organized: [], eventSports: []), isEmpty);
    });
  });

  group('eventsForSport', () {
    final events = [
      {'name': 'hoops', 'sport': 'Basketball'},
      {'name': 'spike', 'sport': 'Volleyball'},
      {'name': 'no sport'},
    ];

    List<String> names(String? sport) =>
        eventsForSport(events, data: (e) => e, sport: sport)
            .map((e) => e['name'] as String)
            .toList();

    test('keeps only the chosen sport', () {
      expect(names('Volleyball'), ['spike']);
    });

    test('keeps everything, in order, when no sport is chosen', () {
      expect(names(null), ['hoops', 'spike', 'no sport']);
    });

    test('an event without a sport shows only when unfiltered', () {
      expect(names('Basketball'), ['hoops']);
      expect(names(null), contains('no sport'));
    });
  });
}
