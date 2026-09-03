// test/services/contact_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/services/contact_service.dart';

void main() {
  // ContactService.read itself needs a Firestore binding, but the shape of the
  // pre-split fallback is the part that has to stay correct for the whole
  // rollout window, so it lives in its own pure function.
  group('contactFromLegacyProfile', () {
    test('reads both fields off a pre-split organizer document', () {
      final contact = ContactService.contactFromLegacyProfile({
        'fullName': 'Aya Robles',
        'email': 'aya@example.com',
        'phoneNumber': '09171234567',
        'role': 'organizer',
      });
      expect(contact.email, 'aya@example.com');
      expect(contact.phoneNumber, '09171234567');
    });

    // Athletes and coaches never had a phoneNumber field at all, so the
    // fallback has to treat its absence as empty rather than throwing on a
    // null cast — the admin queue renders these alongside organizers.
    test('treats a missing phoneNumber as empty', () {
      final contact = ContactService.contactFromLegacyProfile({
        'email': 'coach@example.com',
      });
      expect(contact.email, 'coach@example.com');
      expect(contact.phoneNumber, '');
    });

    test('returns empty strings for a fully migrated document', () {
      final contact = ContactService.contactFromLegacyProfile({
        'fullName': 'Aya Robles',
        'role': 'organizer',
      });
      expect(contact.email, '');
      expect(contact.phoneNumber, '');
    });

    test('returns empty strings rather than throwing on a null profile', () {
      final contact = ContactService.contactFromLegacyProfile(null);
      expect(contact.email, '');
      expect(contact.phoneNumber, '');
    });

    // A document written by a much older build could hold a non-string in
    // either field. Denying the admin their whole queue over one malformed
    // record is worse than showing that record's contact line blank.
    test('does not throw when a field holds an unexpected type', () {
      expect(
        () => ContactService.contactFromLegacyProfile({'email': 12345}),
        returnsNormally,
      );
      expect(
          ContactService.contactFromLegacyProfile({'email': 12345}).email, '');
    });
  });
}
