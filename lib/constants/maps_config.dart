// lib/constants/maps_config.dart

/// Build-time configuration for the Google Maps Platform key used by
/// PlacesService, GeocodingService and DirectionsService.
///
/// The key is supplied at build time rather than written in source, so it never
/// enters git history. Values live in dart_defines.json, which is gitignored;
/// copy dart_defines.example.json to create it.
///
///   flutter run --dart-define-from-file=dart_defines.json
///   flutter build apk --release --dart-define-from-file=dart_defines.json
///
/// Reading from a file rather than passing --dart-define inline matters more
/// than it looks: forgetting the flag builds successfully and fails only at
/// runtime, when venue search returns nothing on a real device.
///
/// This is the web-services key, restricted to Places, Geocoding and
/// Directions. The Maps SDK for Android key is separate and lives in
/// android/local.properties, because it needs a different restriction
/// (Android package plus signing certificate) that web services cannot use.
///
/// Being out of source control is the achievable win here, not secrecy from
/// the device: these are REST calls made by the app, so the key is present in
/// the built binary and can be extracted from an APK by anyone who wants it.
/// What actually bounds the damage is server-side configuration — restricting
/// the key to just the three APIs it needs and setting daily quota caps in the
/// Google Cloud console — because Places, Geocoding and Directions all bill per
/// request. The durable fix is to move these calls behind a Cloud Function so
/// the key stays on the server; `cloud_functions` and `functions/` are already
/// in the project for that.
class MapsConfig {
  static const String apiKey = String.fromEnvironment('MAPS_API_KEY');

  /// False when the app was built without --dart-define, which would otherwise
  /// surface as a confusing REQUEST_DENIED from Google rather than a missing
  /// build flag.
  static bool get isConfigured => apiKey.isNotEmpty;

  static const String missingKeyMessage =
      'Maps features are not configured in this build.';
}
