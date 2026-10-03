// test/utils/sport_rating_test.dart
//
// The profile sheet shows each sport's Elo beside its averages, and has to
// tell "never rated" apart from a real rating of exactly 1000.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/sport_rating.dart';

void main() {
  group('sportRating', () {
    test('returns the rating stored for the sport', () {
      expect(sportRating({'basketball': 1040}, 'basketball'), 1040);
    });

    test('finds the lowercase key from a display name', () {
      expect(sportRating({'volleyball': 987}, 'Volleyball'), 987);
    });

    test('truncates a rating stored as a double', () {
      expect(sportRating({'badminton': 1012.8}, 'Badminton'), 1012);
    });

    test('a rating of exactly the starting value still counts as rated', () {
      expect(sportRating({'basketball': 1000}, 'Basketball'), 1000);
    });

    test('a sport with no rating is null, not the starting rating', () {
      expect(sportRating({'basketball': 1040}, 'Volleyball'), isNull);
    });

    test('an athlete with no ratings map is null', () {
      expect(sportRating(null, 'Basketball'), isNull);
    });

    test('a non-numeric value is null', () {
      expect(sportRating({'basketball': 'high'}, 'Basketball'), isNull);
    });
  });
}
