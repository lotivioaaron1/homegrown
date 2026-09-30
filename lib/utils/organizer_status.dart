// lib/utils/organizer_status.dart
//
// What an organizer's approval status means to them. Home's banner and the
// create-event and create-tournament block screens all read from here, so
// the three can't give a rejected organizer three different stories — the
// block screens used to tell everyone they "may just need to wait for
// review", including people who had already been turned down.

/// A heading and one or two sentences explaining an approval status.
class OrganizerStatusCopy {
  final String title;
  final String body;
  const OrganizerStatusCopy(this.title, this.body);
}

/// Whether an admin has turned this organizer down, as opposed to not having
/// looked yet.
bool isRefusedOrganizer(String? status) =>
    status == 'rejected' || status == 'revoked';

/// The explanation for [status], or null for an approved organizer, who has
/// nothing to be told. A missing status reads as pending: that is what every
/// organizer starts as, and older Google sign-ups never had it written.
OrganizerStatusCopy? organizerStatusCopy(String? status) => switch (status) {
      'approved' => null,
      'rejected' => const OrganizerStatusCopy(
          'Your organizer request was declined',
          "This account can't create events or brackets. Contact the app "
              'admin if you think this is a mistake.'),
      'revoked' => const OrganizerStatusCopy(
          'Your organizer access was removed',
          "This account can't create events or brackets any more. Contact "
              'the app admin for details.'),
      _ => const OrganizerStatusCopy(
          'Your account is waiting for approval',
          'An admin checks every new organizer. Creating events and brackets '
              "unlocks once you're approved, and you'll get a notification "
              'when it happens.'),
    };
