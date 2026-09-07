// test/utils/auth_routing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/auth_routing.dart';

void main() {
  group('landingRoute', () {
    test('a verified athlete lands on home', () {
      expect(
        landingRoute(
            role: 'athlete',
            emailVerified: true,
            hasPasswordProvider: true,
            suspended: false),
        kRouteHome,
      );
    });

    test('an unverified password user is sent to the verification screen', () {
      expect(
        landingRoute(
            role: 'athlete',
            emailVerified: false,
            hasPasswordProvider: true,
            suspended: false),
        kRouteVerifyEmail,
      );
    });

    test('every non-admin role is gated the same way', () {
      for (final role in ['athlete', 'coach', 'organizer', '']) {
        expect(
          landingRoute(
              role: role,
              emailVerified: false,
              hasPasswordProvider: true,
              suspended: false),
          kRouteVerifyEmail,
          reason: 'role "$role" should be gated on verification',
        );
      }
    });

    // Google accounts arrive with emailVerified already true, but a Google-only
    // account has no password credential to verify, so sendEmailVerification on
    // one is meaningless. Never strand such a user on a screen whose only
    // action cannot help them.
    test('a Google user is never sent to verify, even if unverified', () {
      expect(
        landingRoute(
            role: 'athlete',
            emailVerified: false,
            hasPasswordProvider: false,
            suspended: false),
        kRouteHome,
      );
    });

    test('an admin lands on the approval queue', () {
      expect(
        landingRoute(
            role: 'admin',
            emailVerified: true,
            hasPasswordProvider: true,
            suspended: false),
        kRouteAdmin,
      );
    });

    // The super-admin exists only because someone hand-set role:'admin' in the
    // Firestore console, so there is no attacker path that gains admin without
    // console access already. Gating them on verification would risk locking
    // the single administrative account out of its own approval queue for no
    // security gain.
    test('an unverified admin still reaches the queue rather than being locked out',
        () {
      expect(
        landingRoute(
            role: 'admin',
            emailVerified: false,
            hasPasswordProvider: true,
            suspended: false),
        kRouteAdmin,
      );
    });

    // ── Suspension ────────────────────────────────────────────

    test('a suspended user is held on the suspended screen', () {
      expect(
        landingRoute(
            role: 'athlete',
            emailVerified: true,
            hasPasswordProvider: true,
            suspended: true),
        kRouteSuspended,
      );
    });

    test('suspension applies to every non-admin role', () {
      for (final role in ['athlete', 'coach', 'organizer', '']) {
        expect(
          landingRoute(
              role: role,
              emailVerified: true,
              hasPasswordProvider: true,
              suspended: true),
          kRouteSuspended,
          reason: 'role "$role" should be held when suspended',
        );
      }
    });

    // Suspension is lifted from the admin console, so an admin who somehow
    // carried the flag would be the one person unable to reach the screen that
    // clears it. Same argument as the verification bypass above.
    test('a suspended admin still reaches the console rather than being locked out',
        () {
      expect(
        landingRoute(
            role: 'admin',
            emailVerified: true,
            hasPasswordProvider: true,
            suspended: true),
        kRouteAdmin,
      );
    });

    // Both gates are dead ends, but only one of them names the actual reason
    // the account cannot proceed. Verifying an email does nothing for a
    // suspended user, so sending them there would be a false instruction.
    test('suspension takes precedence over an unverified email', () {
      expect(
        landingRoute(
            role: 'athlete',
            emailVerified: false,
            hasPasswordProvider: true,
            suspended: true),
        kRouteSuspended,
      );
    });
  });
}
