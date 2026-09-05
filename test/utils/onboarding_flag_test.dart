// test/utils/onboarding_flag_test.dart
//
// Pins down the flag that decides whether a launching app shows the Get
// Started CTA or the login screen.
//
// The flag used to be written in exactly one place — splash_screen.dart, on a
// cold start that already found a signed-in user — so anyone who registered
// and signed out without ever relaunching was treated as brand new and sent
// back through onboarding. AuthController now marks it at the moment an
// account exists on the device, and this file covers the helper both sides
// share.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/onboarding_flag.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reads false on a device that has never written the flag', () async {
    expect(await isOnboardingComplete(), isFalse);
  });

  test('reads true once marked', () async {
    await markOnboardingComplete();
    expect(await isOnboardingComplete(), isTrue);
  });

  test('reads false again after clearing', () async {
    await markOnboardingComplete();
    await clearOnboardingComplete();
    expect(await isOnboardingComplete(), isFalse);
  });

  test('clearing a flag that was never set is a no-op, not a crash', () async {
    await clearOnboardingComplete();
    expect(await isOnboardingComplete(), isFalse);
  });

  test('marking twice stays true', () async {
    await markOnboardingComplete();
    await markOnboardingComplete();
    expect(await isOnboardingComplete(), isTrue);
  });

  // The key name is part of the contract, not an implementation detail:
  // it is already on real devices. Renaming it would read as "never
  // onboarded" for every existing install and march signed-out users back
  // through the intro — exactly the bug this helper was written to fix.
  // test/onboarding_screen_test.dart asserts against the same literal.
  test('writes the onboarding_complete key by that exact name', () async {
    await markOnboardingComplete();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_complete'), isTrue);
  });

  // Reading must not create the key. The splash reads it on every launch,
  // including the brand-new-user launch that is supposed to leave the device
  // looking untouched.
  test('reading does not write', () async {
    await isOnboardingComplete();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_complete'), isNull);
  });
}
