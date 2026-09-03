// test/utils/auth_routing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/auth_routing.dart';

void main() {
  group('landingRoute', () {
    test('a verified athlete lands on home', () {
      expect(
        landingRoute(
            role: 'athlete', emailVerified: true, hasPasswordProvider: true),
        kRouteHome,
      );
    });

    test('an unverified password user is sent to the verification screen', () {
      expect(
        landingRoute(
            role: 'athlete', emailVerified: false, hasPasswordProvider: true),
        kRouteVerifyEmail,
      );
    });

    test('every non-admin role is gated the same way', () {
      for (final role in ['athlete', 'coach', 'organizer', '']) {
        expect(
          landingRoute(
              role: role, emailVerified: false, hasPasswordProvider: true),
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
            role: 'athlete', emailVerified: false, hasPasswordProvider: false),
        kRouteHome,
      );
    });

    test('an admin lands on the approval queue', () {
      expect(
        landingRoute(
            role: 'admin', emailVerified: true, hasPasswordProvider: true),
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
            role: 'admin', emailVerified: false, hasPasswordProvider: true),
        kRouteAdmin,
      );
    });
  });
}
