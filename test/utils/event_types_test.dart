// test/utils/event_types_test.dart
//
// What each event type means: a Liga game counts toward Elo and points, a
// tune-up doesn't, and events saved under the old names keep working.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/event_types.dart';

void main() {
  group('the picker', () {
    test('offers Liga game and Tune-up; tournaments come from brackets', () {
      expect(kPickableEventTypes, ['Liga game', 'Tune-up']);
    });

    test('says what each choice means', () {
      expect(eventTypeHint(kLigaGame),
          'Official game — counts toward Elo and points.');
      expect(eventTypeHint(kTuneUp),
          'Practice or exhibition — stats are kept, but no Elo or points.');
    });
  });

  group('countsTowardRankings', () {
    test('is false for a tune-up and the old Friendly', () {
      expect(countsTowardRankings('Tune-up'), isFalse);
      expect(countsTowardRankings('Friendly'), isFalse);
    });

    test('is true for Liga games, bracket games and the old League', () {
      expect(countsTowardRankings('Liga game'), isTrue);
      expect(countsTowardRankings('Tournament'), isTrue);
      expect(countsTowardRankings('League'), isTrue);
    });

    // Events from before types were required still count, as they always
    // have.
    test('is true for an event with no type', () {
      expect(countsTowardRankings(null), isTrue);
      expect(countsTowardRankings(''), isTrue);
    });
  });

  group('eventTypeLabel', () {
    test('shows the old names in the new words', () {
      expect(eventTypeLabel('Friendly'), 'Tune-up');
      expect(eventTypeLabel('League'), 'Liga game');
    });

    test('shows current names as they are', () {
      expect(eventTypeLabel('Liga game'), 'Liga game');
      expect(eventTypeLabel('Tune-up'), 'Tune-up');
      expect(eventTypeLabel('Tournament'), 'Tournament');
      expect(eventTypeLabel(null), '');
    });
  });

  group('pickableTypeFor', () {
    test('preselects the matching choice when an old event is edited', () {
      expect(pickableTypeFor('Friendly'), 'Tune-up');
      expect(pickableTypeFor('League'), 'Liga game');
      expect(pickableTypeFor('Tournament'), 'Liga game');
      expect(pickableTypeFor('Tune-up'), 'Tune-up');
      expect(pickableTypeFor('Liga game'), 'Liga game');
    });

    test('leaves the picker empty for an unknown type', () {
      expect(pickableTypeFor(null), isNull);
      expect(pickableTypeFor('Scrimmage'), isNull);
    });
  });
}
