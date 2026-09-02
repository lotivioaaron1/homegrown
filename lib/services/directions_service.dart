// lib/services/directions_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../constants/maps_config.dart';
import 'api_cache.dart';

/// Fetches driving routes from the Google Directions API. Kept
/// separate from the venue locator screen so the request/response
/// handling can be unit-tested with an injected [http.Client].
class DirectionsService {
  static const _kApiKey = MapsConfig.apiKey;
  static const _kBaseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Tapping between venues in the locator re-requests the same routes, and
  /// these calls omit `departure_time`, so the response carries no live traffic
  /// that a short TTL would keep fresh anyway.
  static final _cache =
      ApiCache<DirectionsResult>(ttl: const Duration(minutes: 30));

  @visibleForTesting
  static void clearCache() => _cache.clear();

  /// The origin is the device's own GPS fix, which jitters by a few metres
  /// while standing still; rounding stops that jitter from re-billing an
  /// otherwise identical route.
  static String _cacheKey(LatLng origin, LatLng destination) =>
      '${origin.latitude.toStringAsFixed(4)},'
      '${origin.longitude.toStringAsFixed(4)}'
      '->${destination.latitude.toStringAsFixed(4)},'
      '${destination.longitude.toStringAsFixed(4)}';

  static Future<DirectionsResult> fetchDrivingRoute({
    required LatLng origin,
    required LatLng destination,
    http.Client? client,
  }) async {
    final key = _cacheKey(origin, destination);
    final cached = _cache.get(key);
    if (cached != null) return cached;

    final httpClient = client ?? http.Client();
    final url = Uri.parse(_kBaseUrl).replace(queryParameters: {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'driving',
      'key': _kApiKey,
    });

    final res = await httpClient
        .get(url, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw DirectionsException(
          'Directions service unavailable (HTTP ${res.statusCode}). '
          'Please try again later.');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final status = data['status'] as String?;
    if (status != 'OK') {
      throw DirectionsException(_messageForStatus(status));
    }

    final routes = data['routes'] as List;
    if (routes.isEmpty) {
      throw DirectionsException('No driving route found to this venue.');
    }

    final route = routes[0] as Map<String, dynamic>;
    final leg = (route['legs'] as List).first as Map<String, dynamic>;
    final encoded =
        (route['overview_polyline'] as Map<String, dynamic>)['points']
            as String;

    final result = DirectionsResult(
      points: _decodePolyline(encoded),
      distanceText: (leg['distance'] as Map<String, dynamic>)['text'] as String,
      durationText: (leg['duration'] as Map<String, dynamic>)['text'] as String,
    );

    // Every failure path above throws, so only a complete route is cached.
    _cache.set(key, result);
    return result;
  }

  static String _messageForStatus(String? status) {
    switch (status) {
      case 'ZERO_RESULTS':
        return 'No driving route found to this venue.';
      case 'REQUEST_DENIED':
        return 'Directions request was denied. Please contact support.';
      case 'OVER_QUERY_LIMIT':
        return 'Directions service is busy. Please try again shortly.';
      default:
        return 'Could not get directions (${status ?? 'unknown error'}).';
    }
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}

class DirectionsResult {
  final List<LatLng> points;
  final String distanceText;
  final String durationText;

  DirectionsResult({
    required this.points,
    required this.distanceText,
    required this.durationText,
  });
}

class DirectionsException implements Exception {
  final String message;
  DirectionsException(this.message);

  @override
  String toString() => 'DirectionsException: $message';
}
