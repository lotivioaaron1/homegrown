// test/utils/registration_rollback_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/registration_rollback.dart';

void main() {
  group('withRegistrationRollback', () {
    test('leaves the account alone when the writes succeed', () async {
      var deleted = false;
      await withRegistrationRollback(
        writes: () async {},
        deleteAccount: () async => deleted = true,
      );
      expect(deleted, isFalse);
    });

    // The whole point: a half-registered account whose profile writes failed
    // must not survive, or the person can never register that email again —
    // their retry fails with 'email-already-in-use' against an account that
    // has no usable profile behind it.
    test('deletes the account when a write fails', () async {
      var deleted = false;
      await expectLater(
        withRegistrationRollback(
          writes: () async => throw StateError('permission denied'),
          deleteAccount: () async => deleted = true,
        ),
        throwsA(isA<StateError>()),
      );
      expect(deleted, isTrue);
    });

    test('rethrows the original failure, not a rollback failure', () async {
      // If cleanup also fails there is nothing more the app can do, but the
      // error the user sees must still describe what actually went wrong
      // rather than the janitor tripping on the way out.
      await expectLater(
        withRegistrationRollback(
          writes: () async => throw StateError('the real cause'),
          deleteAccount: () async => throw Exception('cleanup also failed'),
        ),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', 'the real cause')),
      );
    });

    test('runs the writes exactly once', () async {
      var calls = 0;
      await withRegistrationRollback(
        writes: () async => calls++,
        deleteAccount: () async {},
      );
      expect(calls, 1);
    });
  });
}
