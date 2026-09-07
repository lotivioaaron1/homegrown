// test/services/api_cache_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/services/api_cache.dart';

void main() {
  group('ApiCache', () {
    test('returns null for a key that was never stored', () {
      final cache = ApiCache<String>(ttl: const Duration(minutes: 5));

      expect(cache.get('missing'), isNull);
    });

    test('returns a stored value within its TTL', () {
      final cache = ApiCache<String>(ttl: const Duration(minutes: 5));

      cache.set('astrodome', 'Bicol University Astrodome');

      expect(cache.get('astrodome'), 'Bicol University Astrodome');
    });

    test('expires a value once the TTL has elapsed', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final cache = ApiCache<String>(
        ttl: const Duration(minutes: 5),
        clock: () => now,
      );

      cache.set('astrodome', 'Bicol University Astrodome');
      now = now.add(const Duration(minutes: 4, seconds: 59));
      expect(cache.get('astrodome'), isNotNull,
          reason: 'should still be live one second before expiry');

      now = now.add(const Duration(seconds: 2));
      expect(cache.get('astrodome'), isNull);
    });

    test('evicts the least recently used entry past maxEntries', () {
      final cache = ApiCache<String>(
        ttl: const Duration(minutes: 5),
        maxEntries: 2,
      );

      cache.set('a', 'first');
      cache.set('b', 'second');
      // Reading 'a' promotes it, so 'b' becomes the eviction candidate.
      cache.get('a');
      cache.set('c', 'third');

      expect(cache.get('a'), 'first');
      expect(cache.get('b'), isNull);
      expect(cache.get('c'), 'third');
    });

    test('overwrites an existing key rather than growing', () {
      final cache = ApiCache<String>(
        ttl: const Duration(minutes: 5),
        maxEntries: 2,
      );

      cache.set('a', 'first');
      cache.set('a', 'updated');
      cache.set('b', 'second');

      expect(cache.get('a'), 'updated');
      expect(cache.get('b'), 'second');
    });

    test('clear() empties the cache', () {
      final cache = ApiCache<String>(ttl: const Duration(minutes: 5));

      cache.set('a', 'first');
      cache.clear();

      expect(cache.get('a'), isNull);
    });

    test('stores a null-free list value without copying it', () {
      final cache = ApiCache<List<int>>(ttl: const Duration(minutes: 5));
      final value = [1, 2, 3];

      cache.set('nums', value);

      expect(cache.get('nums'), same(value));
    });
  });
}
