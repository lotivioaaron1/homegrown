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
}
