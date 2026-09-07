# Live Venue Search + Live Location Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hand-typed, unverified `kLegazpiVenues` catalog with live Google Places search (plus a manual map-pin fallback) for event venue selection, and make the venue locator's own-location marker continuously live instead of a one-time GPS snapshot.

**Architecture:** Two new Google-API-wrapping services (`PlacesService`, `GeocodingService`) follow the exact static-wrapper-with-injectable-`http.Client` shape already established by `DirectionsService`. A relocated `Venue` model (renamed from `LegazpiVenue`) is the shared value type across search results, manual pins, and the existing event-creation review UI. `create_event_screen.dart`'s venue picker sheet switches from filtering a local list to a debounced live search, with a new `VenueMapPickerScreen` as the fallback when search finds nothing. `venue_locator_screen.dart` switches from a one-shot `Geolocator.getCurrentPosition()` to a `Geolocator.getPositionStream()` subscription and drops its now-redundant custom "you are here" marker (the `GoogleMap` widget's built-in `myLocationEnabled: true` blue dot already covers that, live).

**Tech Stack:** Flutter/Dart, `http` package (already a dependency) for direct REST calls to Google Places API (New) and the Geocoding API, `geolocator` for position streaming, `google_maps_flutter` for `LatLng`/`GoogleMap`. No new pub packages needed.

**Spec:** [docs/superpowers/specs/2026-08-21-places-venue-search-design.md](../specs/2026-08-21-places-venue-search-design.md)

## Global Constraints

- Places API (New) Text Search endpoint: `POST https://places.googleapis.com/v1/places:searchText`, headers `Content-Type: application/json`, `X-Goog-Api-Key: <key>`, `X-Goog-FieldMask: places.displayName,places.formattedAddress,places.location,places.primaryType`.
- Location bias for venue search: a circle centered on `(13.1391, 123.7438)` (Legazpi City center) with radius `15000` meters.
- Geocoding API (reverse geocode) endpoint: `GET https://maps.googleapis.com/maps/api/geocode/json?latlng={lat},{lng}&key={key}` (same product/key already used by `DirectionsService`, just a different endpoint).
- Shared Maps API key for all three services: `AIzaSyANxN_-pADVGhenw5VdLZe9_O-620BAFuo` (already hardcoded and in use elsewhere in this codebase — not a new secret to provision).
- Venue search debounce: 400ms after the user stops typing before firing a request.
- Live position stream settings: `LocationAccuracy.high`, `distanceFilter: 10` (meters) — avoids rebuild spam from GPS jitter.
- The driving route/distance/duration shown on the venue locator must NOT auto-recalculate as the user's live location updates — it only refreshes when "Get Directions" is tapped, exactly as it does today.
- **Blocker:** `PlacesService` will not return real results until Places API (New) is enabled on the Google Cloud project backing this app's Maps key. Tasks 1–2's automated tests use a mocked `http.Client` and do not require this. Any task step marked "requires live Places API" is blocked until the user confirms it's enabled.

---

### Task 1: `Venue` model

**Files:**
- Create: `lib/models/venue.dart`

**Interfaces:**
- Produces: `class Venue { final String name, address, type; final double lat, lng; const Venue({required this.name, required this.address, required this.lat, required this.lng, required this.type}); }`

This is a plain value class with no behavior beyond its constructor (same shape as the `LegazpiVenue` class it replaces) — per this repo's existing precedent (`DirectionsResult`/`DirectionsException` in `lib/services/directions_service.dart` have no dedicated unit tests of their own; they're exercised through the service that constructs them), it doesn't get a standalone test file. It's covered by the tests in Task 2 (`PlacesService`, which constructs `Venue` instances from parsed API responses).

- [x] **Step 1: Create the model file**

```dart
// lib/models/venue.dart

/// A venue's identity and exact map location — whether it came from
/// a Places API search result or a manually dropped map pin.
class Venue {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String type;

  const Venue({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.type,
  });
}
```

- [x] **Step 2: Verify it compiles cleanly**

Run: `flutter analyze lib/models/venue.dart`
Expected: `No issues found!`

- [x] **Step 3: Confirm the rest of the app is unaffected**

Run: `flutter test test/services test/utils test/models test/constants`
Expected: all existing tests still pass (this file isn't referenced by anything yet).

- [x] **Step 4: Commit**

```bash
git add lib/models/venue.dart
git commit -m "Add Venue model as the shared value type for live venue sourcing"
```

---

### Task 2: `PlacesService` (TDD)

**Files:**
- Create: `lib/services/places_service.dart`
- Test: `test/services/places_service_test.dart`

**Interfaces:**
- Consumes: `Venue` (Task 1) — `Venue({required name, required address, required lat, required lng, required type})`
- Produces: `class PlacesService { static Future<List<Venue>> searchVenues(String query, {http.Client? client}); }`, `class PlacesException implements Exception { final String message; PlacesException(this.message); }`

- [x] **Step 1: Write the failing tests**

Create `test/services/places_service_test.dart`:

```dart
// test/services/places_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:homegrown/services/places_service.dart';

void main() {
  group('PlacesService.searchVenues', () {
    test('sends the query with Legazpi City appended and a 15km location bias around city center', () async {
      Map<String, dynamic>? capturedBody;
      Map<String, String>? capturedHeaders;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        capturedHeaders = request.headers;
        return http.Response('{"places": []}', 200);
      });

      await PlacesService.searchVenues('Astrodome', client: client);

      expect(capturedBody!['textQuery'], 'Astrodome, Legazpi City, Albay, Philippines');
      final bias = capturedBody!['locationBias']['circle'];
      expect(bias['center']['latitude'], 13.1391);
      expect(bias['center']['longitude'], 123.7438);
      expect(bias['radius'], 15000);
      expect(capturedHeaders!['X-Goog-Api-Key'], isNotEmpty);
      expect(capturedHeaders!['X-Goog-FieldMask'], contains('places.location'));
    });

    test('parses successful results into a list of Venue', () async {
      final client = MockClient((request) async => http.Response(jsonEncode({
        'places': [
          {
            'displayName': {'text': 'Ibalong Centrum for Recreation', 'languageCode': 'en'},
            'formattedAddress': 'Legazpi Port District, Legazpi City, Albay, Philippines',
            'location': {'latitude': 13.144195, 'longitude': 123.746363},
            'primaryType': 'stadium',
          },
        ],
      }), 200));

      final results = await PlacesService.searchVenues('ICR', client: client);

      expect(results, hasLength(1));
      expect(results.first.name, 'Ibalong Centrum for Recreation');
      expect(results.first.address, 'Legazpi Port District, Legazpi City, Albay, Philippines');
      expect(results.first.lat, 13.144195);
      expect(results.first.lng, 123.746363);
      expect(results.first.type, 'stadium');
    });

    test('returns an empty list when the response has no places key', () async {
      final client = MockClient((request) async => http.Response('{}', 200));

      final results = await PlacesService.searchVenues('a venue nobody has heard of', client: client);

      expect(results, isEmpty);
    });

    test('returns an empty list when places is an empty array', () async {
      final client = MockClient((request) async => http.Response('{"places": []}', 200));

      final results = await PlacesService.searchVenues('another obscure court', client: client);

      expect(results, isEmpty);
    });

    test('throws PlacesException on a non-200 HTTP response', () async {
      final client = MockClient((request) async => http.Response('Server error', 500));

      expect(
        () => PlacesService.searchVenues('Astrodome', client: client),
        throwsA(isA<PlacesException>()),
      );
    });

    test('falls back to "Venue" when primaryType is missing', () async {
      final client = MockClient((request) async => http.Response(jsonEncode({
        'places': [
          {
            'displayName': {'text': 'Some Court', 'languageCode': 'en'},
            'formattedAddress': 'Legazpi City, Albay, Philippines',
            'location': {'latitude': 13.14, 'longitude': 123.74},
          },
        ],
      }), 200));

      final results = await PlacesService.searchVenues('Some Court', client: client);

      expect(results.first.type, 'Venue');
    });
  });
}
```

- [x] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/places_service_test.dart`
Expected: compilation failure — `Error when reading 'lib/services/places_service.dart': The system cannot find the file specified.`

- [x] **Step 3: Write the implementation**

Create `lib/services/places_service.dart`:

```dart
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
```

- [x] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/places_service_test.dart`
Expected: `00:00 +6: All tests passed!`

- [x] **Step 5: Commit**

```bash
git add lib/services/places_service.dart test/services/places_service_test.dart
git commit -m "Add PlacesService for live Google Places venue search"
```

---

### Task 3: `GeocodingService` (TDD)

**Files:**
- Create: `lib/services/geocoding_service.dart`
- Test: `test/services/geocoding_service_test.dart`

**Interfaces:**
- Produces: `class GeocodingService { static Future<String?> reverseGeocode(LatLng point, {http.Client? client}); }` — returns the formatted address, or `null` if none could be resolved (not an exception — a soft-fail the caller falls back on).

- [x] **Step 1: Write the failing tests**

Create `test/services/geocoding_service_test.dart`:

```dart
// test/services/geocoding_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:homegrown/services/geocoding_service.dart';

const _point = LatLng(13.144195, 123.746363);

void main() {
  group('GeocodingService.reverseGeocode', () {
    test('sends the tapped point as the latlng query param', () async {
      Uri? capturedUrl;
      final client = MockClient((request) async {
        capturedUrl = request.url;
        return http.Response('{"status": "OK", "results": []}', 200);
      });

      await GeocodingService.reverseGeocode(_point, client: client);

      expect(capturedUrl!.queryParameters['latlng'], '13.144195,123.746363');
    });

    test('returns the formatted address from a successful OK response', () async {
      final client = MockClient((request) async => http.Response(
          '{"status": "OK", "results": [{"formatted_address": "Legazpi Port District, Legazpi City, Albay"}]}',
          200));

      final address = await GeocodingService.reverseGeocode(_point, client: client);

      expect(address, 'Legazpi Port District, Legazpi City, Albay');
    });

    test('returns null when status is not OK', () async {
      final client = MockClient((request) async =>
          http.Response('{"status": "ZERO_RESULTS", "results": []}', 200));

      final address = await GeocodingService.reverseGeocode(_point, client: client);

      expect(address, isNull);
    });

    test('returns null on a non-200 HTTP response', () async {
      final client = MockClient((request) async => http.Response('Server error', 500));

      final address = await GeocodingService.reverseGeocode(_point, client: client);

      expect(address, isNull);
    });

    test('returns null when results is empty despite OK status', () async {
      final client = MockClient(
          (request) async => http.Response('{"status": "OK", "results": []}', 200));

      final address = await GeocodingService.reverseGeocode(_point, client: client);

      expect(address, isNull);
    });
  });
}
```

- [x] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/geocoding_service_test.dart`
Expected: compilation failure — `lib/services/geocoding_service.dart` not found.

- [x] **Step 3: Write the implementation**

Create `lib/services/geocoding_service.dart`:

```dart
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
```

- [x] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/geocoding_service_test.dart`
Expected: `00:00 +5: All tests passed!`

- [x] **Step 5: Commit**

```bash
git add lib/services/geocoding_service.dart test/services/geocoding_service_test.dart
git commit -m "Add GeocodingService for reverse-geocoding manual venue pins"
```

---

### Task 4: `VenueMapPickerScreen`

**Files:**
- Create: `lib/screens/events/venue_map_picker_screen.dart`

**Interfaces:**
- Consumes: `Venue` (Task 1), `GeocodingService.reverseGeocode(LatLng point)` (Task 3)
- Produces: `class VenueMapPickerScreen extends StatefulWidget` — on confirm, calls `Navigator.pop(context, Venue(...))`; on cancel/back, pops with no value. Callers use `await Navigator.push<Venue>(context, MaterialPageRoute(builder: (_) => const VenueMapPickerScreen()))`.

No automated test for this file: it's a `GoogleMap`-based interactive widget, and this repo's test setup has no widget-test harness capable of exercising map taps or platform channels (the one existing widget test, `test/widget_test.dart`, already fails for unrelated Firebase-initialization reasons — see repo notes). Verified manually in Task 6's manual check instead, consistent with how this repo already handles map-widget testing (`venue_locator_screen.dart` has no widget tests either).

- [x] **Step 1: Create the screen**

```dart
// lib/screens/events/venue_map_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/venue.dart';
import '../../services/geocoding_service.dart';
import '../../theme/app_theme.dart';

const _kCenter = LatLng(13.1391, 123.7438);

/// Manual venue-pin fallback for when Places search finds nothing —
/// tap the map to set a venue's exact location, mirroring how native
/// Google Maps lets you drop a pin at an unlisted spot.
class VenueMapPickerScreen extends StatefulWidget {
  const VenueMapPickerScreen({super.key});
  @override
  State<VenueMapPickerScreen> createState() => _VenueMapPickerScreenState();
}

class _VenueMapPickerScreenState extends State<VenueMapPickerScreen> {
  LatLng? _tapped;
  String? _address;
  bool _isResolving = false;

  Future<void> _onTap(LatLng point) async {
    setState(() {
      _tapped = point;
      _address = null;
      _isResolving = true;
    });
    final address = await GeocodingService.reverseGeocode(point);
    if (!mounted) return;
    setState(() {
      _address = address;
      _isResolving = false;
    });
  }

  void _confirm() {
    if (_tapped == null) return;
    final label = _address ??
        '${_tapped!.latitude.toStringAsFixed(5)}, '
            '${_tapped!.longitude.toStringAsFixed(5)}';
    Navigator.pop(
      context,
      Venue(
        name: label,
        address: label,
        lat: _tapped!.latitude,
        lng: _tapped!.longitude,
        type: 'Venue',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: Text('Drop a Pin', style: TextStyle(color: AppTheme.textPrimary)),
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: _kCenter, zoom: 13.5),
          onTap: _onTap,
          markers: _tapped == null
              ? {}
              : {Marker(markerId: const MarkerId('tapped'), position: _tapped!)},
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                _tapped == null
                    ? "Tap the map to set this venue's location"
                    : (_isResolving
                        ? 'Looking up address...'
                        : (_address ??
                            'No address found — will use coordinates only')),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _tapped == null ? null : _confirm,
                  child: const Text('Confirm Location'),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
```

- [x] **Step 2: Verify it compiles cleanly**

Run: `flutter analyze lib/screens/events/venue_map_picker_screen.dart`
Expected: `No issues found!`

- [x] **Step 3: Commit**

```bash
git add lib/screens/events/venue_map_picker_screen.dart
git commit -m "Add VenueMapPickerScreen as the manual venue-pin fallback"
```

---

### Task 5: Wire live search + map-pin fallback into `create_event_screen.dart`

**Files:**
- Modify: `lib/screens/events/create_event_screen.dart:1-32` (imports, `_selectedVenue` field type), `:51-150` (`_pickVenue()`)

**Interfaces:**
- Consumes: `Venue` (Task 1), `PlacesService.searchVenues(String query, {http.Client? client})` (Task 2), `VenueMapPickerScreen` (Task 4)

No automated test (same reasoning as Task 4 — interactive bottom-sheet widget, no harness for it in this repo). `PlacesService`'s own logic is already covered by Task 2's tests; this task is verified by `flutter analyze` plus the manual check in Task 6.

- [x] **Step 1: Update imports and the `_selectedVenue` field type**

In `lib/screens/events/create_event_screen.dart`, replace the top of the import block:

```dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
```

with (adding `dart:async` before the `package:` imports, per Dart's import-ordering convention):

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
```

Then further down the same import block, replace:

```dart
import '../../theme/app_theme.dart';
import '../../constants/legazpi_venues.dart';
import '../../services/notification_service.dart';
```

with:

```dart
import '../../theme/app_theme.dart';
import '../../models/venue.dart';
import '../../services/notification_service.dart';
import '../../services/places_service.dart';
import 'venue_map_picker_screen.dart';
```

Replace:

```dart
  // ── Venue — now uses dropdown ─────────────
  LegazpiVenue? _selectedVenue;
```

with:

```dart
  // ── Venue — live search + manual pin ──────
  Venue? _selectedVenue;
```

- [x] **Step 2: Replace `_pickVenue()` with the live-search version**

Replace the entire `_pickVenue()` method (from `void _pickVenue() {` through its closing `}`) with:

```dart
  // ── Venue picker bottom sheet ─────────────

  void _pickVenue() {
    final search = TextEditingController();
    List<Venue> results = [];
    bool isSearching = false;
    bool hasSearched = false;
    Timer? debounce;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          Future<void> runSearch(String q) async {
            if (q.trim().isEmpty) {
              if (ctx.mounted) {
                setModal(() { results = []; hasSearched = false; });
              }
              return;
            }
            if (ctx.mounted) setModal(() => isSearching = true);
            try {
              final found = await PlacesService.searchVenues(q);
              if (ctx.mounted) {
                setModal(() {
                  results = found; isSearching = false; hasSearched = true;
                });
              }
            } catch (_) {
              if (ctx.mounted) {
                setModal(() {
                  results = []; isSearching = false; hasSearched = true;
                });
                _snack('Search Error',
                    'Could not search venues. Check internet connection.');
              }
            }
          }

          Future<void> openMapPicker() async {
            final picked = await Navigator.push<Venue>(ctx,
                MaterialPageRoute(builder: (_) => const VenueMapPickerScreen()));
            if (picked != null) {
              setState(() => _selectedVenue = picked);
              if (ctx.mounted) Navigator.pop(ctx);
            }
          }

          Widget buildResults(ScrollController ctrl) {
            if (isSearching) {
              return const Center(child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2));
            }
            if (!hasSearched) {
              return Center(child: Text('Type to search for a venue',
                  style: TextStyle(color: AppTheme.muted, fontSize: 13)));
            }
            if (results.isEmpty) {
              return Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('No venues found', style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: openMapPicker,
                    icon: Icon(Icons.add_location_alt_rounded,
                        color: AppTheme.accent),
                    label: Text("Can't find it? Drop a pin",
                        style: TextStyle(color: AppTheme.accent)),
                  ),
                ],
              ));
            }
            return ListView.builder(
              controller: ctrl,
              itemCount: results.length,
              itemBuilder: (_, i) {
                final v = results[i];
                final sel = v.name == _selectedVenue?.name;
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: sel
                          ? AppTheme.accentSurface : AppTheme.cardNested,
                      borderRadius: BorderRadius.circular(8),
                      border: sel
                          ? Border.all(color: AppTheme.accent) : null),
                    child: Icon(Icons.location_on_rounded,
                        color: sel ? AppTheme.accent : AppTheme.muted,
                        size: 18)),
                  title: Text(v.name, style: TextStyle(
                    color: sel ? AppTheme.accentText : AppTheme.textPrimary,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13)),
                  subtitle: Text(v.address, style: TextStyle(
                      color: AppTheme.muted, fontSize: 11)),
                  trailing: sel
                      ? Icon(Icons.check_circle_rounded,
                          color: AppTheme.accent, size: 20) : null,
                  onTap: () {
                    setState(() => _selectedVenue = v);
                    Navigator.pop(ctx);
                  },
                );
              },
            );
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize:     0.92,
            builder: (_, ctrl) => Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text('Select Venue', style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 16,
                    fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: search,
                  autofocus: true,
                  style: TextStyle(color: AppTheme.textPrimary),
                  onChanged: (q) {
                    debounce?.cancel();
                    debounce = Timer(
                        const Duration(milliseconds: 400), () => runSearch(q));
                  },
                  decoration: InputDecoration(
                    hintText: 'Search venue...',
                    hintStyle: TextStyle(color: AppTheme.muted),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppTheme.muted, size: 20),
                    filled: true, fillColor: AppTheme.bg,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: AppTheme.accent, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: buildResults(ctrl)),
            ]),
          );
        },
      ),
    );
  }
```

- [x] **Step 3: Verify it compiles cleanly**

Run: `flutter analyze lib/screens/events/create_event_screen.dart`
Expected: `No issues found!` (note: Step 3's review UI and `_onPublish()` read `_selectedVenue!.name/.address/.lat/.lng/.type` — identical field names on `Venue` as on the old `LegazpiVenue`, so no other part of this file needs to change.)

- [x] **Step 4: Confirm nothing else broke**

Run: `flutter test test/services test/utils test/models test/constants`
Expected: all pass (this file isn't covered by automated tests either way).

- [x] **Step 5: Manual check (requires live Places API)**

Run the app, open "Create Event," tap the venue field, type "Astrodome" and wait ~400ms — confirm real search results appear with addresses. Type something nonsensical (e.g. "zzzznotarealplace") — confirm "No venues found" and a "Can't find it? Drop a pin" button appear; tap it, tap a point on the map, confirm an address (or coordinate fallback) appears and "Confirm Location" is enabled; confirm it sets the venue and returns to the form.

- [x] **Step 6: Commit**

```bash
git add lib/screens/events/create_event_screen.dart
git commit -m "Replace static venue list with live Places search + map-pin fallback"
```

---

### Task 6: Retire `kLegazpiVenues`

**Files:**
- Delete: `lib/constants/legazpi_venues.dart`
- Delete: `test/constants/legazpi_venues_test.dart`

By this point nothing in `lib/` imports `lib/constants/legazpi_venues.dart` (Task 5 removed the only consumer). Confirm before deleting.

- [x] **Step 1: Confirm there are no remaining references**

Run (from repo root): `grep -rl "legazpi_venues" lib/ test/ --exclude="legazpi_venues.dart" --exclude="legazpi_venues_test.dart" || echo "no references found"`
Expected: `no references found`. (The two files about to be deleted both contain their own filename in a header comment, e.g. `// lib/constants/legazpi_venues.dart` — they're excluded from this search on purpose so a clean result reads unambiguously; if anything else is printed, stop and investigate before deleting.)

- [x] **Step 2: Delete the files**

```bash
git rm lib/constants/legazpi_venues.dart test/constants/legazpi_venues_test.dart
```

- [x] **Step 3: Verify the whole project still builds and tests pass**

Run: `flutter analyze`
Expected: no new errors (pre-existing lint infos unrelated to this change are fine — see repo notes; there should be zero mentions of `legazpi_venues` or `LegazpiVenue`).

Run: `flutter test test/services test/utils test/models`
Expected: all pass (note: `test/constants` no longer exists as a target — omit it here).

- [x] **Step 4: Commit**

```bash
git commit -m "Remove the static kLegazpiVenues catalog, superseded by live Places search"
```

---

### Task 7: Live location in `venue_locator_screen.dart`

**Files:**
- Modify: `lib/screens/venues/venue_locator_screen.dart` (imports already include `dart:async` and `geolocator`; add a `StreamSubscription<Position>` field, replace `_getUserLocation()`, add `dispose()`, remove the custom user marker from `_buildMarkers()`)

**Interfaces:**
- No change to any signature other tasks depend on — `_userLoc` (already used by `_getDirections()`, shipped earlier this session) keeps its type (`LatLng`) and meaning (current best-known user position); only how it's populated changes.

No automated test — position streaming needs a real or simulated location provider this repo's test setup can't drive (same class of limitation as Task 4). Verified manually.

- [x] **Step 1: Add the subscription field and start it as a stream**

Replace:

```dart
  // User location — starts at Legazpi center,
  // updated with real GPS if permission granted
  LatLng _userLoc = _kCenter;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _getUserLocation();
  }

  // ── Get real GPS location ─────────────────

  Future<void> _getUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      LocationPermission perm = permission;
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        setState(() {
          _userLoc = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (_) {
      // Falls back to Legazpi center if GPS unavailable
    }
  }
```

with:

```dart
  // User location — starts at Legazpi center,
  // continuously updated with real GPS if permission granted
  LatLng _userLoc = _kCenter;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  // ── Live GPS location ──────────────────────

  Future<void> _startLocationUpdates() async {
    try {
      final permission = await Geolocator.checkPermission();
      LocationPermission perm = permission;
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() => _userLoc = LatLng(pos.latitude, pos.longitude));
        }
      });
    } catch (_) {
      // Falls back to Legazpi center if GPS unavailable
    }
  }
```

- [x] **Step 2: Remove the now-redundant custom user marker**

In `_buildMarkers()`, remove this block (the `GoogleMap` widget already has `myLocationEnabled: true`, which draws the SDK's own live blue dot — this custom marker was a stale, one-shot duplicate of it):

```dart
    // User location marker
    markers.add(Marker(
      markerId: const MarkerId('user_location'),
      position: _userLoc,
      icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: '📍 Your Location'),
    ));

```

leaving `_buildMarkers()` ending with just `return markers;` after the event-marker loop.

- [x] **Step 3: Verify it compiles cleanly**

Run: `flutter analyze lib/screens/venues/venue_locator_screen.dart`
Expected: `No issues found!`

- [x] **Step 4: Confirm the rest of the suite is unaffected**

Run: `flutter test test/services test/utils test/models`
Expected: all pass (this screen has no automated tests either way — `DirectionsService`, which it calls, is unaffected by this change).

- [x] **Step 5: Manual check**

Run the app on a device or emulator, open the venue locator. Confirm exactly one "you are here" indicator is visible (the native blue dot), not two overlapping markers. Change the simulated/real location (e.g. `adb -s <device> emu geo fix <lng> <lat>` on an emulator) and confirm the blue dot moves without needing to reopen the screen. Tap "Get Directions" on an event — confirm it still only recalculates on tap, not continuously as location updates.

- [x] **Step 6: Commit**

```bash
git add lib/screens/venues/venue_locator_screen.dart
git commit -m "Track user location live instead of a one-shot GPS snapshot"
```

---

### Task 8: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` ("Domain data" paragraph)

- [x] **Step 1: Replace the Domain data paragraph**

Replace:

```markdown
**Domain data:** Static reference data (venue coordinates, barangay lists) lives in `lib/constants/` as plain Dart `const` lists (e.g. `kLegazpiVenues` in [lib/constants/legazpi_venues.dart](lib/constants/legazpi_venues.dart)), not fetched from Firestore.
```

with:

```markdown
**Domain data:** Static reference data lives in `lib/constants/` as plain Dart `const` values, not fetched from Firestore. Venue data is a deliberate exception: it's sourced live via `PlacesService` ([lib/services/places_service.dart](lib/services/places_service.dart), wrapping Google's Places API) when an organizer creates an event, with a manual map-pin fallback (`VenueMapPickerScreen`, using `GeocodingService` for reverse-geocoding) for venues Google doesn't index. This replaced an earlier hand-typed `kLegazpiVenues` list whose guessed coordinates proved unreliable in practice (a mid-city venue was off by hundreds of meters, and free-text geocoding of small local venues by name produced results hundreds of kilometers wrong).
```

- [x] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Update CLAUDE.md to describe live venue sourcing"
```
