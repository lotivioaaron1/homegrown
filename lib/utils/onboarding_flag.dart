// lib/utils/onboarding_flag.dart

// Whether this device has already been through onboarding, as one owner of
// one key.
//
// SplashScreen uses this to choose between the Get Started CTA (which is the
// only route into /onboarding) and /login. The flag is deliberately about the
// *device*, not the account: before sign-in there is nothing else to go on.
//
// It is marked when an account starts existing on the device — registration or
// sign-in — rather than when the intro finishes playing. Those are different
// moments, and the difference is the bug this file was written for. Marking it
// at the end of the intro stranded anyone who watched it and then abandoned
// registration: the splash CTA is the only way back to /onboarding, so they
// were sent to /login from then on and could never see the intro again.
// Marking it only on a cold start that already found a signed-in user, which
// is what SplashScreen did on its own, had the opposite failure — someone who
// registered and signed out without ever relaunching was still "brand new" and
// got marched back through onboarding.

import 'package:shared_preferences/shared_preferences.dart';

/// The stored key. Already present on real devices, so treat it as a contract:
/// renaming it reads as "never onboarded" for every existing install.
const String kOnboardingCompleteKey = 'onboarding_complete';

/// Records that this device belongs to someone with an account.
///
/// Call it where that becomes true — after registration or a successful
/// sign-in — not when the intro finishes.
Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kOnboardingCompleteKey, true);
}

/// Whether this device has been through onboarding.
///
/// Absent means no, and reading deliberately does not write: a brand-new
/// user's first launch should leave the device looking untouched.
Future<bool> isOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kOnboardingCompleteKey) ?? false;
}

/// Forgets the flag, so the next launch offers the intro again.
///
/// Only the Settings replay shortcut needs this. Signing out must *not* call
/// it — having signed in here is exactly what makes someone a returning user.
Future<void> clearOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kOnboardingCompleteKey);
}
