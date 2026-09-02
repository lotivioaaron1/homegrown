// lib/services/api_cache.dart

/// A tiny in-memory LRU cache with a time-to-live, used by the three Google
/// Maps Platform services to stop repeat requests from re-billing.
///
/// Every Maps call in this app costs money per request — Places Text Search
/// most of all — and the usage patterns repeat heavily: an organizer retypes a
/// venue name after clearing the field, or taps the same spot on the map picker
/// twice. Without a cache each of those is a fresh charge.
///
/// Deliberately not a package: the whole need is "remember a handful of recent
/// answers for a few minutes," and the entries are small. Lifetime is the app
/// process — nothing is persisted, so a cold start always sees fresh data.
///
/// Only *successful* responses are ever stored. Caching a failure would turn one
/// transient network blip into minutes of a falsely broken venue search.
class ApiCache<T> {
  ApiCache({
    required this.ttl,
    this.maxEntries = 50,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration ttl;
  final int maxEntries;
  final DateTime Function() _clock;

  /// Dart's default Map preserves insertion order, which is what makes plain
  /// remove-and-reinsert enough to maintain LRU ordering without a linked list.
  final Map<String, _CacheEntry<T>> _entries = {};

  /// Returns the cached value for [key], or null if it was never stored or has
  /// aged out. A hit is promoted to most-recently-used.
  T? get(String key) {
    final entry = _entries[key];
    if (entry == null) return null;

    if (_clock().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }

    // Re-insert to move this key to the end of the insertion order.
    _entries.remove(key);
    _entries[key] = entry;
    return entry.value;
  }

  void set(String key, T value) {
    // Remove first so an overwrite refreshes position instead of leaving the
    // key at its old spot in the eviction order.
    _entries.remove(key);
    _entries[key] = _CacheEntry(value, _clock().add(ttl));

    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}

class _CacheEntry<T> {
  _CacheEntry(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;
}
