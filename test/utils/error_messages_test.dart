// test/utils/error_messages_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/error_messages.dart';

void main() {
  group('authErrorMessage', () {
    // The security property, not a wording assertion. Firebase's email
    // enumeration protection collapses "no such user" and "wrong password"
    // into invalid-credential; if that protection is ever turned off, the
    // other two codes start firing again and three distinct messages would
    // tell an attacker which of the two happened. Asserting the strings are
    // equal to each other — rather than merely non-empty — is what stops a
    // future edit from reopening that.
    test('does not distinguish a missing account from a wrong password', () {
      final byCode = {
        for (final code in [
          'invalid-credential',
          'wrong-password',
          'user-not-found',
        ])
          code: authErrorMessage(code),
      };

      expect(byCode.values.toSet(), hasLength(1),
          reason: 'these codes must be indistinguishable to the user, got '
              '$byCode');
      expect(byCode['invalid-credential'], isNotNull);
    });

    // The reported bug: an account created through "Continue with Google"
    // holds no password credential, so email sign-in against it can never
    // succeed. The old copy ("Invalid credentials. Please try again.") read
    // as a typo and sent those users round a retry loop.
    test('points a failed sign-in at Google Sign-In', () {
      expect(authErrorMessage('invalid-credential'), contains('Google'));
    });

    // Same root cause from the other direction: a Google user trying to
    // register the address they already hold.
    test('points a taken email at both ways back in', () {
      final message = authErrorMessage('email-already-in-use')!;
      expect(message, contains('Google'));
      expect(message, contains('signing in'));
    });

    test('keeps a distinct message for the non-credential codes', () {
      expect(authErrorMessage('too-many-requests'), contains('Too many'));
      expect(authErrorMessage('network-request-failed'), contains('Network'));
      expect(authErrorMessage('user-disabled'), contains('disabled'));
      expect(authErrorMessage('weak-password'), contains('8 characters'));
      expect(authErrorMessage('invalid-email'), contains('valid email'));
    });

    // Null rather than a baked-in sentence, so each caller can supply copy
    // that fits its screen — "Registration failed" on the register screens,
    // "Failed to send reset email" on forgot-password.
    test('returns null for an unmapped code so callers can fall back', () {
      expect(authErrorMessage('some-future-firebase-code'), isNull);
      expect(authErrorMessage(''), isNull);
    });
  });

  group('friendlyError', () {
    test('uses the caller fallback for an unmapped error', () {
      expect(
        friendlyError(Object(), fallback: 'Could not save your profile.'),
        'Could not save your profile.',
      );
    });

    test('falls back to the generic message when none is given', () {
      expect(friendlyError(null), 'Something went wrong. Please try again.');
    });
  });
}
