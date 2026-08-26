// lib/services/barangay_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Fetches the live, official list of Legazpi City barangays from the
/// Philippine Standard Geographic Code (PSGC) registry, replacing the old
/// hand-typed `kLegazpiBarangays` catalog whose names were missing several
/// barangays and misspelling others.
class BarangayService {
  static const _kCityCode = '050506000'; // City of Legazpi (PSGC)
  static const _kBaseUrl =
      'https://psgc.gitlab.io/api/cities-municipalities/$_kCityCode/barangays/';

  static List<String>? _cache;

  static Future<List<String>> fetchBarangays({http.Client? client}) async {
    if (_cache != null) return _cache!;
    final httpClient = client ?? http.Client();
    final res = await httpClient
        .get(Uri.parse(_kBaseUrl))
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw BarangayException(
          'Barangay list unavailable (HTTP ${res.statusCode}). Please try again later.');
    }

    final data = jsonDecode(res.body) as List;
    final names = data
        .map((e) => (e as Map<String, dynamic>)['name'] as String)
        .toList()
      ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
    return _cache = names;
  }

  // Sort by the name after "Bgy. NN - " so the list reads A-Z by place
  // name in the UI, even though the displayed string keeps the zone prefix
  // (needed for accuracy — e.g. two distinct barangays are both named
  // "Rizal Street" and are only told apart by their zone number).
  static String _sortKey(String officialName) =>
      officialName.split(' - ').skip(1).join(' - ');

  @visibleForTesting
  static void resetCache() => _cache = null;
}

class BarangayException implements Exception {
  final String message;
  BarangayException(this.message);

  @override
  String toString() => 'BarangayException: $message';
}
