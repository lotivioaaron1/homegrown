// lib/utils/crash_classification.dart

// Which Flutter framework errors deserve to be reported as crashes.
//
// main.dart used to hand every FlutterError to Crashlytics as fatal, so an
// avatar whose download link had gone stale was filed as a "crash" — 23 of
// them in one week, burying the one real startup crash under noise. Nothing
// about a failed image load stops the app: the widget falls back to initials
// and everything around it keeps working.

/// The `library` Flutter stamps on errors raised while fetching or decoding an
/// image — see `ImageStreamCompleter.reportError`.
const String kImageErrorLibrary = 'image resource service';

/// Whether a framework error reported under [library] should be recorded as a
/// fatal crash rather than a non-fatal one.
///
/// Takes the library string instead of `FlutterErrorDetails` so the decision
/// stays a plain function the tests can call without a Crashlytics binding.
bool isFatalFlutterError(String? library) => library != kImageErrorLibrary;
