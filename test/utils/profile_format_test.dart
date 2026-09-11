// test/utils/profile_format_test.dart
//
// Height and weight are optional at sign-up, and the card coaches see used to
// print a bare "cm" or "—cm" when they were left blank.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/profile_format.dart';

void main() {
  group('formatMeasure', () {
    test('appends the unit to a stored value', () {
      expect(formatMeasure('175', 'cm'), '175cm');
    });

    test('a missing field shows a dash, not "—cm"', () {
      expect(formatMeasure(null, 'cm'), '—');
    });

    test('an empty string shows a dash, not a bare unit', () {
      expect(formatMeasure('', 'kg'), '—');
    });

    test('whitespace counts as empty', () {
      expect(formatMeasure('   ', 'kg'), '—');
    });

    test('a number from an older document prints the same way', () {
      expect(formatMeasure(70, 'kg'), '70kg');
    });
  });
}
