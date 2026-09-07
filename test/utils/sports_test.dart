// test/utils/sports_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/sports.dart';

void main() {
  group('sportsOf', () {
    test('reads the sports off a user doc', () {
      final result = sportsOf({
        'role': 'coach',
        'primarySports': ['Basketball', 'Volleyball'],
      });
      expect(result, ['Basketball', 'Volleyball']);
    });

    test('returns empty for a doc with no primarySports', () {
      expect(sportsOf({'role': 'coach'}), isEmpty);
    });

    test('returns empty for a null user', () {
      expect(sportsOf(null), isEmpty);
    });

    test('returns empty when primarySports is not a list', () {
      // A hand-edited Firestore doc could hold a bare string here; the
      // caller gates athlete visibility on this, so it must not throw.
      expect(sportsOf({'primarySports': 'Basketball'}), isEmpty);
    });

    test('returns empty for an explicitly empty list', () {
      expect(sportsOf({'primarySports': <String>[]}), isEmpty);
    });

    test('coerces non-string entries rather than throwing', () {
      expect(sportsOf({'primarySports': ['Basketball', 7]}),
          ['Basketball', '7']);
    });
  });

  group('sportsOverlap', () {
    test('is true when both sides share a sport', () {
      expect(sportsOverlap(['Basketball'], ['Basketball']), isTrue);
    });

    test('is true when a multi-sport athlete plays one of the coached sports',
        () {
      // The case a naive equality check would wrongly reject: a basketball
      // coach may invite someone who plays basketball and volleyball.
      expect(
          sportsOverlap(['Basketball'], ['Volleyball', 'Basketball']), isTrue);
    });

    test('is true when a multi-sport coach shares one sport', () {
      expect(sportsOverlap(['Basketball', 'Volleyball'], ['Volleyball']),
          isTrue);
    });

    test('is false for disjoint sports', () {
      expect(sportsOverlap(['Basketball'], ['Badminton']), isFalse);
    });

    test('is false when the coach has no sports set', () {
      // Guards the important failure mode: a coach whose profile predates
      // the sport field must match nobody, not everybody.
      expect(sportsOverlap([], ['Basketball']), isFalse);
    });

    test('is false when the athlete has no sports set', () {
      expect(sportsOverlap(['Basketball'], []), isFalse);
    });

    test('is false when both sides are empty', () {
      expect(sportsOverlap([], []), isFalse);
    });
  });
}
