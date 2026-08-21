// lib/services/team_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

/// Writes/reads coach-athlete team relationships. Kept as static helpers
/// (not a GetX controller), matching NotificationService's style, since
/// the Scout screen, Team Invites screen, and My Team screen all need the
/// exact same invite/accept/decline/remove logic.
class TeamService {
  static final _col =
      FirebaseFirestore.instance.collection('teamMemberships');

  /// Every coach's roster is capped at this many accepted players — fixed
  /// app-wide, not configurable per team.
  static const int maxPlayers = 15;

  static String inviteId(String coachId, String athleteId) =>
      '${coachId}_$athleteId';

  static Future<int> rosterCountFor(String coachId) async {
    final agg = await _col
        .where('coachId', isEqualTo: coachId)
        .where('status', isEqualTo: 'accepted')
        .count()
        .get();
    return agg.count ?? 0;
  }

  /// Coach sends (or re-sends after a decline) an invite. Overwriting the
  /// deterministic-ID doc means a duplicate tap is idempotent, not a new
  /// row. No-ops if the athlete is already an accepted member, guarding
  /// against a stale button state in the Scout profile sheet.
  static Future<void> sendInvite({
    required String coachId,
    required String coachName,
    required String teamName,
    required String athleteId,
    required String athleteName,
    String? athletePhotoUrl,
  }) async {
    final ref = _col.doc(inviteId(coachId, athleteId));
    final existing = await ref.get();
    if (existing.exists && existing.data()?['status'] == 'accepted') return;

    if (await rosterCountFor(coachId) >= maxPlayers) {
      throw const TeamFullException();
    }

    await ref.set({
      'coachId': coachId,
      'athleteId': athleteId,
      'coachName': coachName,
      'teamName': teamName,
      'athleteName': athleteName,
      'athletePhotoUrl': athletePhotoUrl,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
    });

    await NotificationService.create(
      userId: athleteId,
      type: 'team_invite',
      title: 'New Team Invite',
      body: '$coachName invited you to join $teamName',
      relatedId: ref.id,
    );
  }

  /// Accepts an invite, then — if this was the last open roster slot —
  /// notifies every other athlete still pending on the same coach so
  /// nobody is left wondering. Those invites are left as 'pending' rather
  /// than deleted: security rules only let a coach or the invited athlete
  /// delete a given invite doc (see firestore.rules), and this call runs
  /// under the *accepting athlete's* session, who is neither for anyone
  /// else's invite. The coach can still cancel the leftovers manually from
  /// My Team, and the capacity check below already blocks any of them
  /// from being accepted into a team that's already full.
  static Future<void> acceptInvite(String inviteId) async {
    final ref = _col.doc(inviteId);
    final invite = await ref.get();
    final data = invite.data();
    final coachId = data?['coachId'] as String?;
    if (coachId == null) return;

    if (await rosterCountFor(coachId) >= maxPlayers) {
      throw const TeamFullException();
    }

    await ref.update({
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    if (await rosterCountFor(coachId) >= maxPlayers) {
      await _notifyLeftoverPendingInvites(
        coachId: coachId,
        teamName: data?['teamName'] as String? ?? 'This team',
        excludingInviteId: inviteId,
      );
    }
  }

  static Future<void> _notifyLeftoverPendingInvites({
    required String coachId,
    required String teamName,
    required String excludingInviteId,
  }) async {
    final leftover = await _col
        .where('coachId', isEqualTo: coachId)
        .where('status', isEqualTo: 'pending')
        .get();
    for (final doc in leftover.docs) {
      if (doc.id == excludingInviteId) continue;
      final athleteId = doc.data()['athleteId'] as String?;
      if (athleteId == null) continue;
      await NotificationService.create(
        userId: athleteId,
        type: 'team_full',
        title: 'Team Now Full',
        body: '$teamName just reached its roster limit. Your invite is '
            'still pending, but there may not be room until a spot opens '
            'up.',
      );
    }
  }

  static Future<void> declineInvite(String inviteId) =>
      _col.doc(inviteId).delete();

  static Future<void> cancelInvite(String inviteId) =>
      _col.doc(inviteId).delete();

  static Future<void> removeMember(String inviteId) =>
      _col.doc(inviteId).delete();

  static Future<void> leaveTeam(String inviteId) =>
      _col.doc(inviteId).delete();

  static Stream<QuerySnapshot> streamRoster(String coachId) => _col
      .where('coachId', isEqualTo: coachId)
      .where('status', isEqualTo: 'accepted')
      .snapshots();

  static Stream<QuerySnapshot> streamSentPending(String coachId) => _col
      .where('coachId', isEqualTo: coachId)
      .where('status', isEqualTo: 'pending')
      .snapshots();

  static Stream<QuerySnapshot> streamReceivedPending(String athleteId) =>
      _col
          .where('athleteId', isEqualTo: athleteId)
          .where('status', isEqualTo: 'pending')
          .snapshots();

  static Stream<QuerySnapshot> streamAthleteTeams(String athleteId) => _col
      .where('athleteId', isEqualTo: athleteId)
      .where('status', isEqualTo: 'accepted')
      .snapshots();

  /// Live status of one coach-athlete pair, used by the Scout profile
  /// sheet's Invite button so it flips state reactively after tapping
  /// Invite, without closing/reopening the sheet.
  static Stream<DocumentSnapshot> streamMembershipStatus(
          String coachId, String athleteId) =>
      _col.doc(inviteId(coachId, athleteId)).snapshots();
}

/// Thrown by [TeamService.sendInvite]/[TeamService.acceptInvite] when a
/// coach's roster is already at [TeamService.maxPlayers].
class TeamFullException implements Exception {
  const TeamFullException();
}
