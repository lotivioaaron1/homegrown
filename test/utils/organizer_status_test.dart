import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/organizer_status.dart';

void main() {
  group('organizerStatusCopy', () {
    test('an approved organizer has nothing to be told', () {
      expect(organizerStatusCopy('approved'), isNull);
    });

    test('pending and a missing status both read as waiting', () {
      expect(organizerStatusCopy('pending')!.title, contains('waiting'));
      expect(organizerStatusCopy(null)!.title,
          organizerStatusCopy('pending')!.title);
    });

    test('a refused organizer is never told to keep waiting', () {
      for (final status in ['rejected', 'revoked']) {
        final copy = organizerStatusCopy(status)!;
        expect(copy.title.toLowerCase(), isNot(contains('waiting')));
        expect(copy.body.toLowerCase(), isNot(contains('wait')));
      }
    });
  });

  test('isRefusedOrganizer is true only for rejected and revoked', () {
    expect(isRefusedOrganizer('rejected'), isTrue);
    expect(isRefusedOrganizer('revoked'), isTrue);
    expect(isRefusedOrganizer('pending'), isFalse);
    expect(isRefusedOrganizer('approved'), isFalse);
    expect(isRefusedOrganizer(null), isFalse);
  });
}
