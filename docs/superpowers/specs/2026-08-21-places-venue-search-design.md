# Live venue search + live location for the venue locator

## Context

Homegrown's venue locator (`lib/screens/venues/venue_locator_screen.dart`) already draws real driving routes via the Google Directions API (shipped earlier this session). Verifying that fix on a device surfaced two related problems upstream of routing:

1. **Venue coordinates are unreliable.** Every event's venue is picked from `kLegazpiVenues` (`lib/constants/legazpi_venues.dart`), a hand-typed list of 21 venues with guessed lat/lng, never geocoded or verified. Two concrete failures were found: "Legazpi City Astrodome" was ~800m off from its real location, and "Ibalong Centrum for Recreation" (ICR), a real, well-known venue, wasn't in the list at all — organizers creating an ICR event had to pick an unrelated substitute, so its pin was wrong by construction. An attempt to bulk-correct the list via free-text Google Geocoding API queries proved unsafe: "Kawit Gymnasium" geocoded to a same-named town in Cavite province, 339 km away, and several other entries collapsed onto generic city-centroid or duplicate matches. Geocoding by name alone cannot be trusted for small, informally-named local venues.

2. **The user's own location marker is a one-time snapshot, not real-time.** `_getUserLocation()` calls `Geolocator.getCurrentPosition()` once in `initState()`. On the test device (an Android emulator), this single fetch returned the emulator's then-current mock GPS position and never updated again, producing a stale/wrong-looking marker on screen. Separately, the `GoogleMap` widget already has `myLocationEnabled: true`, which means the SDK's own live-updating blue dot is already present and accurate — the app's custom marker is a redundant, stale duplicate of it.

The user's stated goal, using their own phone's native Google Maps as the reference experience: real-time location tracking, and searching a venue by name (e.g. "Astrodome") to get an accurate pin and route — the same experience Google Maps itself provides, because it's backed by Google's own place database rather than a hand-typed guess.

## Goals

- Venue selection in event creation sources coordinates from Google's live place data (Places API) instead of a static, unverified catalog, for every venue including ones not previously catalogued.
- Venues Google Places doesn't index (informal barangay courts) remain creatable via a manual map-pin fallback, so no organizer loses the ability to create an event at their actual venue.
- The venue locator's "your location" marker reflects continuously live GPS instead of a one-time fetch, without duplicating the map SDK's own live blue dot.
- The route/distance/duration shown stays a deliberate, on-demand action (tap "Get Directions"), not a continuously-recalculating one — avoiding unnecessary billed Directions API calls on every GPS update, which isn't what this screen is for (it's a pre-game locator, not turn-by-turn navigation).

## Non-goals

- Turn-by-turn navigation or continuous re-routing while moving.
- Editing or migrating existing Firestore event documents (`TEST1`, `TEST 2`, `Barangay Cup 2026`, `TEST 4`) — these carry coordinates baked in at creation time from the old picker; they'll be recreated through the new flow rather than migrated in place (test/seed data plus one real event, per user decision).
- Verifying the remaining 19 legacy `kLegazpiVenues` entries against Places API data — moot once the static catalog is retired (see below).

## Architecture

### 1. `PlacesService` (new — `lib/services/places_service.dart`)

Mirrors the existing `DirectionsService` shape: a static-method wrapper with an injectable `http.Client` for testing.

```dart
class PlacesService {
  static Future<List<Venue>> searchVenues(String query, {http.Client? client}) async { ... }
}
```

Calls Places API (New) Text Search:

```
POST https://places.googleapis.com/v1/places:searchText
Headers:
  Content-Type: application/json
  X-Goog-Api-Key: <key>
  X-Goog-FieldMask: places.displayName,places.formattedAddress,places.location,places.primaryType
Body:
{
  "textQuery": "<query>, Legazpi City, Albay, Philippines",
  "locationBias": {
    "circle": { "center": { "latitude": 13.1391, "longitude": 123.7438 }, "radius": 15000 }
  }
}
```

Maps each result to a `Venue` (see below). Empty `places` array is a normal "not found" outcome, not an error — the caller (the picker sheet) uses that to offer the map-pin fallback. Non-200 HTTP or a malformed body throws `PlacesException` (same pattern as `DirectionsException`), reserved for actual service failures.

### 2. `Venue` model (renamed/moved from `LegazpiVenue` — `lib/models/venue.dart`)

Same four fields as today's `LegazpiVenue` (`name`, `address`, `lat`, `lng`, `type`) — no shape change, just relocated out of `constants/` (which CLAUDE.md defines as the home for static, non-fetched reference data — no longer an accurate description once venues come from a live API or a manual pin) into `models/` (CLAUDE.md: "plain Dart classes... no codegen"), matching how the rest of the app organizes value types. `type` is populated from the Places result's `primaryType` when available, falling back to a generic `'Venue'` string; for manually-pinned locations it's also `'Venue'` since there's no category to infer.

### 3. Manual pin fallback (new — `lib/screens/events/venue_map_picker_screen.dart`)

A small screen reusing the same `GoogleMap` widget pattern already established in `venue_locator_screen.dart`: tap anywhere to drop a marker, a "Confirm Location" button returns a `Venue` built from the tapped `LatLng`. The address field is filled by reverse-geocoding the tapped point through the Geocoding API (already enabled, already used for the Astrodome/ICR verification earlier this session); if that also returns nothing usable, the organizer types a short label themselves. Opened from a "Can't find your venue? Drop a pin" affordance shown in `_pickVenue()`'s search sheet whenever a search returns zero results.

### 4. `create_event_screen.dart` changes

- `_selectedVenue` stays typed as `Venue?` (same fields as before, just the renamed/relocated type) — Step 3's review UI and `_onPublish()`'s Firestore write (`venue`, `venueAddress`, `venueLat`, `venueLng`, `venueType`) are unchanged, since they only ever read those four fields regardless of where the `Venue` came from.
- `_pickVenue()`'s local `.where()` filter over `kLegazpiVenues` is replaced by a debounced (~400ms `Timer`) call to `PlacesService.searchVenues()`, with a loading state in the sheet while a search is in flight.
- Remove the `import '../../constants/legazpi_venues.dart';` once nothing here reads `kLegazpiVenues`.

### 5. `venue_locator_screen.dart` changes

- `_getUserLocation()`'s single `Geolocator.getCurrentPosition()` call is replaced by a `Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10))` subscription, stored as a `StreamSubscription<Position>` field, cancelled in `dispose()`. Each update sets `_userLoc` via `setState` as today.
- The custom `'user_location'` `Marker` in `_buildMarkers()` is removed — `myLocationEnabled: true` already renders the SDK's own live blue dot, so the custom marker was a redundant, staler duplicate of it. `_userLoc` remains as internal state (no longer drawn directly) and is still what `_getDirections()` uses as the route origin.
- No change to `_getDirections()`'s trigger — still only called from the "Get Directions" button tap, per the earlier decision against auto-recalculating on movement.

### 6. Retiring `kLegazpiVenues`

Once `create_event_screen.dart` no longer reads it, `kLegazpiVenues` (the list — not the `Venue`/`LegazpiVenue` type) has no remaining consumers anywhere in `lib/` (confirmed earlier this session: only `constants/legazpi_venues.dart` and `create_event_screen.dart` referenced it). It gets deleted, along with `test/constants/legazpi_venues_test.dart` (the bounding-box/no-duplicates/ICR-inclusion guardrail test added earlier this session for that exact list) and `lib/constants/legazpi_venues.dart` itself. CLAUDE.md's "Domain data" paragraph, which names `kLegazpiVenues` as the canonical example of static reference data living in `constants/`, gets updated to describe the new venue-sourcing approach instead.

## Data flow

**Creating an event:** organizer types in `_pickVenue()`'s search field → debounced `PlacesService.searchVenues()` call → results shown as before (same `ListTile` list UI) → tap selects a `Venue`, or "Drop a pin" opens the map picker → either path sets `_selectedVenue` → unchanged from here (Step 3 review, `_onPublish()` writes `venueLat`/`venueLng`/etc. to Firestore exactly as today).

**Viewing the venue locator:** `initState()` starts the position stream instead of a one-shot fetch → `_userLoc` stays current for the lifetime of the screen → tapping an event marker/list tile still calls `_getDirections(dest)` using the latest `_userLoc` as origin, unchanged from the already-shipped `DirectionsService` integration.

## Error handling

- `PlacesService.searchVenues()` returning an empty list is the expected "not found" path, not an exception — the UI branches to the map-pin affordance.
- `PlacesException` (non-200 HTTP, malformed response) surfaces as a snackbar in the picker sheet, same pattern as `DirectionsException` today — network/service failures don't silently look like "no results."
- Reverse-geocoding failure in the map picker degrades to a manual text label rather than blocking venue confirmation.
- Position stream errors (permission revoked mid-session, location services disabled) are caught the same way `_getUserLocation()` already catches them today — silently ignored, `_userLoc` simply stops updating rather than crashing the screen.

## Testing

- `test/services/places_service_test.dart` (TDD, `MockClient` from `http/testing.dart`, same pattern as `directions_service_test.dart`): request shape (query text, location bias present), successful parse into `Venue` list, empty-results case, non-200/error case. Response parsing lives inside `PlacesService` (owns the Places API JSON shape, same division of responsibility as `DirectionsService` owning the Directions API shape) so these tests are where that parsing gets covered — `Venue` itself stays a plain, already-tested-elsewhere-by-usage value class with no parsing logic of its own.
- Widget-level testing of the map-pin picker and live position stream is out of reach of this repo's current test setup (no widget test harness beyond the one broken Firebase-dependent smoke test) — verified manually instead, per this repo's existing testing conventions.

## Prerequisite / blocker

`PlacesService` cannot function until **Places API (New)** is enabled for the Google Cloud project backing this app's Maps API key (assumed `homegrown-app-b71d1`, same as the Firebase project — unconfirmed, since the key isn't explicitly tied to a project ID anywhere in this codebase). Console link: `https://console.cloud.google.com/apis/library/places-backend.googleapis.com?project=homegrown-app-b71d1`. This is a Google Cloud Console action outside this environment's reach (no console credentials, no `gcloud` CLI available) — implementation of `PlacesService` is blocked until the user confirms it's enabled.
