// lib/services/places_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/venue.dart';

/// Searches for real-world venues via Google's Places API (New) Text
/// Search, replacing the old hand-typed `kLegazpiVenues` catalog with
/// live data from Google's own place database.
class PlacesService {
  static const _kApiKey = 'AIzaSyANxN_-pADVGhenw5VdLZe9_O-620BAFuo';
  static const _kBaseUrl = 'https://places.googleapis.com/v1/places:searchText';
  static const _kBiasCenterLat = 13.1391;
  static const _kBiasCenterLng = 123.7438;
  static const _kBiasRadiusMeters = 15000.0;

  static Future<List<Venue>> searchVenues(
    String query, {
    http.Client? client,
  }) async {
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
      throw PlacesException(
          'Venue search unavailable (HTTP ${res.statusCode}). Please try again later.');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final places = data['places'] as List?;
    if (places == null) return [];

    return places.map((p) {
      final place = p as Map<String, dynamic>;
      final displayName = place['displayName'] as Map<String, dynamic>?;
      final location = place['location'] as Map<String, dynamic>?;
      return Venue(
        name: displayName?['text'] as String? ?? 'Unknown venue',
        address: place['formattedAddress'] as String? ?? '',
        lat: (location?['latitude'] as num?)?.toDouble() ?? 0.0,
        lng: (location?['longitude'] as num?)?.toDouble() ?? 0.0,
        type: place['primaryType'] as String? ?? 'Venue',
      );
    }).toList();
  }
}

class PlacesException implements Exception {
  final String message;
  PlacesException(this.message);

  @override
  String toString() => 'PlacesException: $message';
}
