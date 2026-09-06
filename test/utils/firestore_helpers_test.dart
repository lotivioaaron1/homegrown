// test/utils/firestore_helpers_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/firestore_helpers.dart';

void main() {
  group('asTimestamp', () {
    test('returns the value when it is already a Timestamp', () {
      final ts = Timestamp.now();
      expect(asTimestamp(ts), ts);
    });

    test('returns null instead of throwing for a malformed String value', () {
      expect(() => asTimestamp('2026-08-25'), returnsNormally);
      expect(asTimestamp('2026-08-25'), isNull);
    });

    test('returns null for a missing field', () {
      expect(asTimestamp(null), isNull);
    });

    test('returns null for any other unexpected type', () {
      expect(asTimestamp(12345), isNull);
    });
  });

  group('isListableProfile', () {
    test('accepts an ordinary athlete profile', () {
      expect(
          isListableProfile({
            'uid': 'abc',
            'role': 'athlete',
            'firstName': 'Kyle',
            'lastName': 'Aguilar',
            'primarySports': ['Basketball'],
          }),
          isTrue);
    });

    test('rejects a tombstone left by in-app account deletion', () {
      expect(
          isListableProfile({
            'uid': 'abc',
            'role': 'athlete',
            'deleted': true,
            'fullName': 'Deleted user',
          }),
          isFalse);
    });

    test('accepts a profile carrying only fullName', () {
      expect(isListableProfile({'fullName': 'Mark Lotivio'}), isTrue);
    });

    test('accepts a profile carrying only a first name', () {
      expect(isListableProfile({'firstName': 'Mark', 'lastName': ''}), isTrue);
    });

    // The shape left behind when an account is deleted from the Firebase
    // console: no credential, but the profile document survives untouched.
    // Some of those never had a name written to them at all.
    test('rejects a profile with no usable name', () {
      expect(
          isListableProfile({
            'uid': 'abc',
            'role': 'athlete',
            'firstName': '',
            'lastName': '',
            'fullName': '',
            'primarySports': ['Basketball'],
          }),
          isFalse);
    });

    test('rejects a profile whose name fields are only whitespace', () {
      expect(isListableProfile({'firstName': '  ', 'fullName': ' '}), isFalse);
    });

    test('rejects an empty document', () {
      expect(isListableProfile({}), isFalse);
    });

    // Firestore enforces no schema, so a hand-edited document can hold any
    // type. These must not throw the list that is rendering them.
    test('does not throw on non-string name fields', () {
      expect(() => isListableProfile({'firstName': 42}), returnsNormally);
      expect(isListableProfile({'firstName': 42}), isFalse);
    });

    test('treats a non-boolean deleted field as not deleted', () {
      expect(isListableProfile({'deleted': 'yes', 'fullName': 'Real Person'}),
          isTrue);
    });
  });
}
