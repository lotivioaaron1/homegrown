// lib/utils/event_recipients.dart

/// Everyone who should hear about an event: its rostered players plus the two
/// team coaches.
///
/// Coaches live on the event as `teamACoachId` / `teamBCoachId` and are
/// deliberately kept out of `playerUids` — that array is what drives the
/// athlete's "my games" query and `playerCount`, so putting a coach in it
/// would make them show up as a player. That's why the notification audience
/// has to be assembled here instead of read from one field.
///
/// The result is deduplicated, so a coach who happens to be picked for both
/// sides of the same event is notified once, and ids that are missing or
/// empty (an event with only one team picked) are skipped.
List<String> eventAudienceUids(Map<String, dynamic> event) {
  final uids = <String>{};
  for (final uid in (event['playerUids'] as List? ?? const [])) {
    if (uid is String && uid.isNotEmpty) uids.add(uid);
  }
  for (final key in const ['teamACoachId', 'teamBCoachId']) {
    final coachId = event[key];
    if (coachId is String && coachId.isNotEmpty) uids.add(coachId);
  }
  return uids.toList();
}
