// lib/services/geocoding_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../constants/maps_config.dart';
import 'api_cache.dart';

/// Reverse-geocodes a manually tapped map point into a human-readable
/// address, used by VenueMapPickerScreen when Places search finds
/// nothing for a venue. A miss (null) is a normal, expected outcome —
/// the caller falls back to a manual label, not an error state.
class GeocodingService {
  static const _kApiKey = MapsConfig.apiKey;
  static const _kBaseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  /// The map picker geocodes on every tap, so a user nudging a pin around the
  /// same building bills once per nudge without this. Street addresses are
  /// effectively static, so the TTL can be generous.
  static final _cache = ApiCache<String>(ttl: const Duration(hours: 1));

  @visibleForTesting
  static void clearCache() => _cache.clear();

  /// Four decimal places is roughly 11 m — finer than the accuracy of a
  /// fingertip on a phone map, so two taps that a human would call "the same
  /// spot" collapse to one cache key and one charge.
  static String _cacheKey(LatLng point) =>
      '${point.latitude.toStringAsFixed(4)},'
      '${point.longitude.toStringAsFixed(4)}';

  static Future<String?> reverseGeocode(
    LatLng point, {
    http.Client? client,
  }) async {
    final key = _cacheKey(point);
    final cached = _cache.get(key);
    if (cached != null) return cached;

    final httpClient = client ?? http.Client();
    final url = Uri.parse(_kBaseUrl).replace(queryParameters: {
      'latlng': '${point.latitude},${point.longitude}',
      'key': _kApiKey,
    });

    final res = await httpClient
        .get(url, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final results = data['results'] as List;
    if (results.isEmpty) return null;

    final address = (results.first as Map<String, dynamic>)['formatted_address']
        as String?;
    // Only a real address is worth remembering. The null paths above are either
    // failures or a genuine "no address here", both rare and cheap to re-ask —
    // and caching them would mean a transient error suppressed the real answer
    // for an hour.
    if (address != null) _cache.set(key, address);
    return address;
  }
}
