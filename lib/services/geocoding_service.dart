// lib/services/geocoding_service.dart
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Reverse-geocodes a manually tapped map point into a human-readable
/// address, used by VenueMapPickerScreen when Places search finds
/// nothing for a venue. A miss (null) is a normal, expected outcome —
/// the caller falls back to a manual label, not an error state.
class GeocodingService {
  static const _kApiKey = 'AIzaSyANxN_-pADVGhenw5VdLZe9_O-620BAFuo';
  static const _kBaseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  static Future<String?> reverseGeocode(
    LatLng point, {
    http.Client? client,
  }) async {
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

    return (results.first as Map<String, dynamic>)['formatted_address']
        as String?;
  }
}
