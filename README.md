# Homegrown

A Flutter mobile app for a community athletics platform in Legazpi City, Albay,
Philippines. It connects athletes, coaches and organizers: auth and onboarding,
event creation, stats tracking, leaderboards, a venue locator and performance
dashboards, all backed by Firebase.

Android is the deployment target. The `ios/`, `web/`, `windows/`, `macos/` and
`linux/` directories exist because Flutter creates them, but none is configured
— iOS has no `GoogleService-Info.plist`, so Firebase would fail to start there.

## First-time setup

You need the Flutter SDK (3.38+) and a JDK 17 toolchain.

```
flutter pub get
```

Then create the three files that hold local secrets. None is in git, and the
app builds without them — it just fails at runtime in ways that are easy to
misread, so it is worth doing all three up front.

**1. `dart_defines.json`** — the Google Maps *web services* key, used by
`PlacesService`, `GeocodingService` and `DirectionsService`. Copy the template
and paste your key:

```
cp dart_defines.example.json dart_defines.json
```

Restrict this key to Places API (New), Geocoding API and Directions API, and
set daily quota caps on each. It is compiled into the binary and can be
extracted from an APK, so the caps are what actually bound the billing — see
the comment in [lib/constants/maps_config.dart](lib/constants/maps_config.dart).

**2. `android/local.properties`** — add the Maps *SDK for Android* key, which is
a different key with different restrictions (Android package name plus signing
certificate):

```
MAPS_API_KEY=your-android-sdk-key
```

**3. `android/key.properties`** — release signing only; skip it for development.
Copy `android/key.properties.example` and point `storeFile` at a keystore kept
**outside** the repository. Without this file, release builds fall back to the
debug key, which Play rejects and which breaks Google Sign-In.

## Commands

```
flutter run --dart-define-from-file=dart_defines.json    # run on a device
tool/build_apk.ps1                                        # release APK to sideload
flutter analyze                                           # static analysis
flutter test                                              # all tests
flutter test test/services/team_service_test.dart         # one test file
dart fix --apply                                          # auto-fix lints
dart run flutter_launcher_icons                           # regenerate app icons
```

VS Code's Run button is already wired up: every configuration in
`.vscode/launch.json` passes the `--dart-define-from-file` flag.

Build the sideloadable APK through `tool/build_apk.ps1` rather than calling
`flutter build apk` directly. The script passes `--dart-define-from-file` and
refuses to start without a key, which is the one mistake that produces an APK
that installs and runs but whose venue search, map-picker address lookup and
directions all fail — see the warning under Releasing to Google Play below.

## Releasing to Google Play

```
flutter build appbundle --release --dart-define-from-file=dart_defines.json
```

Two flags in that command fail quietly if you drop them:

- **`--dart-define-from-file`** — without it the build still succeeds, and
  `MapsConfig.apiKey` is the empty string. Venue search and the map picker's
  address lookup then fail on a real device with `REQUEST_DENIED`.
- **`appbundle`, not `apk`** — Play wants an `.aab`. An APK build is for
  sideloading onto a test device.

Before each release:

1. Bump `version:` in `pubspec.yaml`. The part before `+` is the version name,
   the part after is the version code, which must increase on every upload.
2. Confirm `flutter analyze` and `flutter test` are clean.
3. Confirm the bundle is signed with the upload key and not the debug fallback —
   `android/key.properties` must exist and its `storeFile` must resolve.
4. Register the upload keystore's SHA-1 fingerprint in the Firebase console.
   Google Sign-In fails in release builds without it, and it is the single most
   common reason a build that works in debug breaks once installed from Play.
5. Confirm the resolved `targetSdk` still meets Play's current minimum. It
   tracks the Flutter SDK rather than being pinned, so it moves with a Flutter
   upgrade rather than going stale — but that also means nothing warns you.

## Architecture

See [CLAUDE.md](CLAUDE.md) for the state management, routing, layering and
theming conventions this codebase follows.

Firebase rules and indexes live at the repository root and deploy separately
from the app:

```
firebase deploy --only firestore:rules,firestore:indexes,storage
```

`functions/` is scaffolded but exports nothing yet. It exists for moving the
Maps web-services calls behind a server, so the key stops shipping inside the
binary.
