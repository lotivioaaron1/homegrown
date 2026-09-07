// lib/services/barangay_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/legazpi_barangays_fallback.dart';

/// The outcome of a barangay lookup: the names, plus whether they came from
/// the live PSGC registry or the bundled offline snapshot. Callers use
/// [isOffline] to tell the user the list may be stale — never to block them,
/// since registration cannot proceed without a barangay.
class BarangayResult {
  final List<String> names;
  final bool isOffline;

  const BarangayResult(this.names, {required this.isOffline});
}

/// Supplies the list of Legazpi City barangays for selection UI.
///
/// Prefers the live Philippine Standard Geographic Code (PSGC) registry,
/// which replaced a hand-typed catalog that was missing several barangays
/// and misspelling others. Falls back to a generated offline snapshot of
/// that same registry when the fetch fails.
///
/// The fallback is not about the user being offline — NoInternetOverlay
/// already gates the whole app on a DNS check, so a fully offline user
/// never reaches this picker. It covers the narrower case where general
/// internet works but this one host does not: psgc.gitlab.io is a free
/// GitLab Pages site with no SLA, and it sits on the critical path of
/// every registration. An outage, a 5xx, a slow response past the timeout,
/// or a captive portal would otherwise dead-end signup entirely.
class BarangayService {
  static const _kCityCode = '050506000'; // City of Legazpi (PSGC)
  static const _kBaseUrl =
      'https://psgc.gitlab.io/api/cities-municipalities/$_kCityCode/barangays/';

  /// Kept short deliberately: this request sits in front of a bottom sheet
  /// the user is waiting on, and a usable offline list is a better outcome
  /// than a longer stall for a marginally fresher one.
  static const _kTimeout = Duration(seconds: 6);

  static BarangayResult? _cache;

  static Future<BarangayResult> fetchBarangays({http.Client? client}) async {
    final cached = _cache;
    // Only a live result is cached for good. An offline result is retried on
    // the next open, so the list self-heals once connectivity returns.
    if (cached != null && !cached.isOffline) return cached;

    try {
      final httpClient = client ?? http.Client();
      final res = await httpClient.get(Uri.parse(_kBaseUrl)).timeout(_kTimeout);

      if (res.statusCode != 200) {
        throw BarangayException(
            'Barangay list unavailable (HTTP ${res.statusCode}).');
      }

      final data = jsonDecode(res.body) as List;
      final names = data
          .map((e) => (e as Map<String, dynamic>)['name'] as String)
          .toList();

      // An empty 200 is a registry-side problem, not a valid answer; treat it
      // as a failure so the user still gets a usable list.
      if (names.isEmpty) {
        throw BarangayException('Barangay list came back empty.');
      }

      return _cache = BarangayResult(_sorted(names), isOffline: false);
    } catch (e) {
      debugPrint(
          'BarangayService: live PSGC fetch failed ($e); using bundled snapshot.');
      return _cache = BarangayResult(
        _sorted(kLegazpiBarangaysFallback),
        isOffline: true,
      );
    }
  }

  // Sort by the name after "Bgy. NN - " so the list reads A-Z by place name
  // in the UI, even though the displayed string keeps the zone prefix
  // (needed for accuracy — e.g. two distinct barangays are both named
  // "Rizal Street" and are only told apart by their zone number).
  static List<String> _sorted(List<String> names) =>
      List<String>.of(names)..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));

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
