// test/constants/legazpi_venues_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/constants/legazpi_venues.dart';

void main() {
  group('kLegazpiVenues', () {
    test('every venue coordinate falls within Legazpi City\'s bounding box', () {
      for (final venue in kLegazpiVenues) {
        expect(venue.lat, inInclusiveRange(13.05, 13.25),
            reason: '${venue.name} latitude is outside Legazpi City');
        expect(venue.lng, inInclusiveRange(123.65, 123.85),
            reason: '${venue.name} longitude is outside Legazpi City');
      }
    });

    test('has no duplicate venue names', () {
      final names = kLegazpiVenues.map((v) => v.name).toList();
      expect(names.toSet().length, names.length);
    });

    test('includes Ibalong Centrum for Recreation', () {
      expect(kLegazpiVenues.any((v) => v.name == 'Ibalong Centrum for Recreation'),
          isTrue);
    });
  });
}
