// lib/services/places_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/venue.dart';
import '../constants/maps_config.dart';
import 'api_cache.dart';

/// Searches for real-world venues via Google's Places API (New) Text
/// Search, replacing the old hand-typed `kLegazpiVenues` catalog with
/// live data from Google's own place database.
class PlacesService {
  static const _kApiKey = MapsConfig.apiKey;
  static const _kBaseUrl = 'https://places.googleapis.com/v1/places:searchText';
  static const _kBiasCenterLat = 13.1391;
  static const _kBiasCenterLng = 123.7438;
  static const _kBiasRadiusMeters = 15000.0;

  /// Shortest query worth sending. One or two characters match half the city
  /// while still costing a full Text Search, so callers should treat anything
  /// shorter as "keep typing" rather than firing a request.
  static const int minQueryLength = 3;

  /// Text Search is the priciest Maps SKU in this app, and clearing then
  /// retyping a venue name is ordinary behaviour, so recent queries are worth
  /// remembering. Venues don't move; half an hour is conservative.
  static final _cache = ApiCache<List<Venue>>(ttl: const Duration(minutes: 30));

  @visibleForTesting
  static void clearCache() => _cache.clear();

  static Future<List<Venue>> searchVenues(
    String query, {
    http.Client? client,
  }) async {
    // Case and stray whitespace don't change what Google returns, so they
    // shouldn't cause a second charge.
    final cacheKey = query.trim().toLowerCase();
    final cached = _cache.get(cacheKey);
    if (cached != null) return cached;

    final httpClient = client ?? http.Client();
    final res = await httpClient
        .post(
          Uri.parse(_kBaseUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _kApiKey,
            'X-Goog-FieldMask':
                'places.displayName,places.formattedAddress,places.location,places.primaryType',
          },
          body: jsonEncode({
            'textQuery': '$query, Legazpi City, Albay, Philippines',
            'locationBias': {
              'circle': {
                'center': {
                  'latitude': _kBiasCenterLat,
                  'longitude': _kBiasCenterLng,
                },
                'radius': _kBiasRadiusMeters,
              },
            },
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw PlacesException(_messageForError(res.statusCode, res.body));
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final places = data['places'] as List?;
    // Note this is reached only on HTTP 200 — the throw above means a failed
    // request is never cached, so one network blip can't wedge venue search
    // into looking broken for the rest of the TTL.
    if (places == null) {
      _cache.set(cacheKey, const []);
      return [];
    }

    // A place with no usable name or coordinates can't be shown as a
    // search result or used as a directions destination — drop it
    // rather than inventing a placeholder name or a (0, 0) pin.
    final venues = places
        .map((p) {
          final place = p as Map<String, dynamic>;
          final displayName = place['displayName'] as Map<String, dynamic>?;
          final location = place['location'] as Map<String, dynamic>?;
          final name = displayName?['text'] as String?;
          final lat = (location?['latitude'] as num?)?.toDouble();
          final lng = (location?['longitude'] as num?)?.toDouble();
          if (name == null || name.isEmpty || lat == null || lng == null) {
            return null;
          }
          return Venue(
            name: name,
            address: place['formattedAddress'] as String? ?? '',
            lat: lat,
            lng: lng,
            type: place['primaryType'] as String? ?? 'Venue',
          );
        })
        .whereType<Venue>()
        .toList();

    _cache.set(cacheKey, venues);
    return venues;
  }

  /// Places API (New) returns a `google.rpc.Status`-shaped error body —
  /// `{"error": {"status": "...", "message": "...", "details": [{"reason": "..."}]}}`
  /// — distinct from the legacy `{"status": "..."}` shape other Google
  /// Maps Platform APIs in this app use. Logging the parsed detail (rather
  /// than just the HTTP code) is what makes a key/quota misconfiguration
  /// diagnosable instead of a bare "HTTP 403" with no further clue.
  static String _messageForError(int statusCode, String body) {
    String? status;
    String? reason;
    try {
      final error = (jsonDecode(body) as Map<String, dynamic>)['error']
          as Map<String, dynamic>?;
      status = error?['status'] as String?;
      final details = error?['details'] as List?;
      reason = details
          ?.map((d) => (d as Map<String, dynamic>)['reason'] as String?)
          .firstWhere((r) => r != null, orElse: () => null);
      debugPrint('PlacesService error: HTTP $statusCode, status=$status, '
          'reason=$reason, message=${error?['message']}');
    } catch (_) {
      debugPrint('PlacesService error: HTTP $statusCode, body=$body');
    }

    switch (status) {
      case 'PERMISSION_DENIED':
      case 'REQUEST_DENIED':
        return 'Venue search is temporarily unavailable. Drop a pin instead.';
      case 'RESOURCE_EXHAUSTED':
        return 'Venue search is busy right now. Try again shortly, or drop a pin.';
      default:
        return 'Couldn\'t search venues right now. Drop a pin instead.';
    }
  }
}

class PlacesException implements Exception {
  final String message;
  PlacesException(this.message);

  @override
  String toString() => 'PlacesException: $message';
}
