// test/widget_test.dart
//
// This file previously pumped HomegrownApp with no expectation. That test
// could never pass: HomegrownApp's initialBinding constructs AuthController,
// which touches FirebaseAuth.instance, and Firebase is initialized in main()
// rather than in the widget tree. It also asserted nothing, so even had it
// run it would have proven nothing.
//
// A genuine app-level smoke test needs Firebase mocked via
// firebase_core_platform_interface (setupFirebaseCoreMocks) plus fakes for
// Auth and Firestore — worth doing, but a larger piece of work than this
// file should carry. Until then this covers the bundled barangay snapshot,
// which is release-critical: it is what keeps registration working when
// psgc.gitlab.io is unreachable while the device is otherwise online.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/constants/legazpi_barangays_fallback.dart';

void main() {
  group('bundled Legazpi barangay snapshot', () {
    test('is present and plausibly complete', () {
      // Legazpi City has 70 barangays per the PSGC registry. A snapshot that
      // has drifted far from this is a sign the generator was edited by hand.
      expect(kLegazpiBarangaysFallback, hasLength(70));
    });

    test('has no duplicate entries', () {
      final seen = kLegazpiBarangaysFallback.toSet();
      expect(seen, hasLength(kLegazpiBarangaysFallback.length));
    });

    test('has no blank or untrimmed entries', () {
      for (final name in kLegazpiBarangaysFallback) {
        expect(name.trim(), isNotEmpty, reason: 'blank entry in snapshot');
        expect(name, equals(name.trim()), reason: 'untrimmed entry: "$name"');
      }
    });

    test('every entry carries the "Bgy. NN - " zone prefix', () {
      // The prefix is not decoration: two distinct barangays are both named
      // "Rizal Street" and the zone number is the only thing telling them
      // apart. It is also what the sort key is derived from.
      final pattern = RegExp(r'^Bgy\. \d+ - .+');
      for (final name in kLegazpiBarangaysFallback) {
        expect(pattern.hasMatch(name), isTrue,
            reason: 'missing or malformed zone prefix: "$name"');
      }
    });

    test('retains the two separately-numbered Rizal Street barangays', () {
      final rizal = kLegazpiBarangaysFallback
          .where((n) => n.contains('Rizal Street'))
          .toList();
      expect(rizal, hasLength(2));
    });

    test('preserves non-ASCII characters in barangay names', () {
      // Guards against the snapshot being regenerated through a non-UTF-8
      // pipeline, which would silently mangle Cabagñan, Bañadero and
      // Peñaranda into replacement characters.
      expect(kLegazpiBarangaysFallback.any((n) => n.contains('ñ')), isTrue);
      expect(kLegazpiBarangaysFallback.any((n) => n.contains('�')),
          isFalse);
    });
  });
}
