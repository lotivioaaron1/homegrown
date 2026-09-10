// test/utils/crash_classification_test.dart
//
// The split between errors Crashlytics files as crashes and errors it files as
// non-fatal. Getting this wrong in the permissive direction hides real crashes,
// so the tests pin both sides.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/crash_classification.dart';

void main() {
  group('isFatalFlutterError', () {
    test('image loading failures are not crashes', () {
      expect(isFatalFlutterError(kImageErrorLibrary), isFalse);
    });

    test('matches the library string Flutter actually uses for images', () {
      // Pinned literally so a rename of the constant cannot quietly stop
      // matching what ImageStreamCompleter reports.
      expect(isFatalFlutterError('image resource service'), isFalse);
    });

    test('build and layout errors stay fatal', () {
      expect(isFatalFlutterError('widgets library'), isTrue);
      expect(isFatalFlutterError('rendering library'), isTrue);
    });

    test('an error with no library stays fatal', () {
      expect(isFatalFlutterError(null), isTrue);
    });
  });
}
