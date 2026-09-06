// test/constants/sport_positions_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/constants/sport_positions.dart';

void main() {
  group('positionsForSports', () {
    test('returns one sport\'s positions in catalog order', () {
      expect(positionsForSports(['Badminton']),
          ['Singles', 'Doubles', 'Mixed Doubles']);
    });

    test('pools multiple sports in kSportPositions key order, not '
        'argument order', () {
      // Volleyball is passed first but Basketball is declared first, so the
      // picker shows the same sequence no matter which chip was tapped first.
      final pooled = positionsForSports(['Volleyball', 'Basketball']);
      expect(pooled.first, 'Point Guard');
      expect(pooled, contains('Setter'));
      expect(pooled.length,
          kSportPositions['Basketball']!.length +
              kSportPositions['Volleyball']!.length);
      expect(pooled, positionsForSports(['Basketball', 'Volleyball']));
    });

    test('skips a sport with no entry rather than throwing', () {
      expect(positionsForSports(['Chess']), isEmpty);
      expect(positionsForSports(['Chess', 'Badminton']),
          kSportPositions['Badminton']);
    });

    test('returns empty for no sports', () {
      expect(positionsForSports([]), isEmpty);
    });

    test('never yields a duplicate', () {
      final all = positionsForSports(kSportPositions.keys.toList());
      expect(all.toSet().length, all.length);
    });
  });

  group('isKnownPosition', () {
    test('accepts a position belonging to a selected sport', () {
      expect(isKnownPosition('Setter', ['Volleyball']), isTrue);
    });

    test('rejects legacy free text', () {
      expect(isKnownPosition('point gaurd', ['Basketball']), isFalse);
      expect(isKnownPosition('point guard', ['Basketball']), isFalse);
      expect(isKnownPosition('PG', ['Basketball']), isFalse);
    });

    test('rejects a valid position from a sport the athlete does not play', () {
      // This is what clears an orphaned selection when a sport is unticked.
      expect(isKnownPosition('Setter', ['Basketball']), isFalse);
    });

    test('rejects a blank position', () {
      expect(isKnownPosition('', ['Basketball']), isFalse);
    });
  });

  group('isCatalogPosition', () {
    test('is true for any sport\'s position, ignoring selection', () {
      expect(isCatalogPosition('Libero'), isTrue);
      expect(isCatalogPosition('Center'), isTrue);
    });

    test('is false for legacy free text and for blanks', () {
      expect(isCatalogPosition('point gaurd'), isFalse);
      expect(isCatalogPosition(''), isFalse);
    });
  });

  group('kSportPositions', () {
    test('covers every sport the registration screens offer', () {
      expect(kSportPositions.keys,
          containsAll(['Basketball', 'Volleyball', 'Badminton']));
    });

    test('every entry is non-empty and capitalized', () {
      for (final positions in kSportPositions.values) {
        expect(positions, isNotEmpty);
        for (final p in positions) {
          expect(p.trim(), p, reason: '"$p" has stray whitespace');
          expect(p[0], p[0].toUpperCase(), reason: '"$p" is not capitalized');
        }
      }
    });
  });
}
