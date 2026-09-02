// lib/services/team_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'notification_service.dart';
import '../utils/sports.dart';

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
  ///
  /// [coachSports] and [athleteSports] must overlap: a basketball coach
  /// can't recruit a badminton player. Both are passed in rather than
  /// re-read here because every caller already holds the two profiles.
  /// Scout won't surface a mismatched athlete in the first place and
  /// firestore.rules rejects the write outright — this check exists so the
  /// coach sees a sentence instead of a raw permission error.
  static Future<void> sendInvite({
    required String coachId,
    required String coachName,
    required String teamName,
    required String athleteId,
    required String athleteName,
    required List<String> coachSports,
    required List<String> athleteSports,
    String? athletePhotoUrl,
  }) async {
    if (!sportsOverlap(coachSports, athleteSports)) {
      throw const SportMismatchException();
    }

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

  /// One-time roster fetch for event creation, where a live stream isn't
  /// needed — same query as [streamRoster], just a single `.get()`.
  static Future<QuerySnapshot> fetchRoster(String coachId) => _col
      .where('coachId', isEqualTo: coachId)
      .where('status', isEqualTo: 'accepted')
      .get();

  /// Uploads a team logo for [coachId], overwriting any previous one at the
  /// same path so Storage doesn't accumulate old logos every time a coach
  /// changes it. Kept here rather than in StorageService since this is a
  /// team concern, not the personal-avatar one that class owns.
  static Future<String> uploadTeamLogo(String coachId, File file) async {
    final ref =
        FirebaseStorage.instance.ref().child('team_logos/$coachId/logo.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

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

  /// Reads the live `users/{uid}` doc for each of [uids], keyed by uid.
  ///
  /// A membership doc carries `athleteName` and `athletePhotoUrl`, but those
  /// are copies taken at invite time: an athlete who changes their avatar
  /// afterwards keeps showing the old one anywhere the membership doc is
  /// rendered straight through. Anything displaying a member's *current*
  /// identity — or a field the membership doc never had, like `position` —
  /// should come through here instead.
  ///
  /// `whereIn` accepts at most 30 values, so this chunks. With [maxPlayers] at
  /// 15, a full roster plus its coach is still a single round trip.
  static Future<Map<String, Map<String, dynamic>>> fetchMemberProfiles(
      Iterable<String> uids) async {
    final ids = uids.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};

    final profiles = <String, Map<String, dynamic>>{};
    for (var i = 0; i < ids.length; i += 30) {
      final end = i + 30 < ids.length ? i + 30 : ids.length;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: ids.sublist(i, end))
          .get();
      for (final doc in snap.docs) {
        profiles[doc.id] = doc.data();
      }
    }
    return profiles;
  }

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

/// Thrown by [TeamService.sendInvite] when the coach and the athlete share
/// no sport — a coach recruits for the sports they coach, nothing else.
class SportMismatchException implements Exception {
  const SportMismatchException();
}

/// A member's *current* display identity, as opposed to the copy frozen into
/// their membership doc when the invite was sent.
class MemberIdentity {
  final String name;
  final String? photoUrl;

  const MemberIdentity({required this.name, this.photoUrl});
}

/// Resolves one live `users/{uid}` doc — as returned by
/// [TeamService.fetchMemberProfiles] — into the name and photo to display.
///
/// [profile] being null (the doc is unreadable, or hasn't loaded yet) or
/// carrying blank fields falls back to the membership doc's invite-time
/// snapshot, so a roster row never renders empty while hydrating.
MemberIdentity resolveMemberIdentity(
  Map<String, dynamic>? profile, {
  required String fallbackName,
  String? fallbackPhotoUrl,
}) {
  if (profile == null) {
    return MemberIdentity(name: fallbackName, photoUrl: fallbackPhotoUrl);
  }

  // `firstName`/`lastName` win over `fullName`. Both are set by every
  // registration path, but only the name parts were maintained by Edit
  // Profile for most of the app's life, so a doc last saved before that was
  // fixed still carries the pre-rename `fullName`. Preferring the parts
  // renders those docs correctly without a backfill; `fullName` remains the
  // fallback for any doc that only ever had it.
  final full = (profile['fullName'] as String? ?? '').trim();
  final first = (profile['firstName'] as String? ?? '').trim();
  final last = (profile['lastName'] as String? ?? '').trim();
  final joined = '$first $last'.trim();
  final name = joined.isNotEmpty
      ? joined
      : (full.isNotEmpty ? full : fallbackName);

  final photo = (profile['photoUrl'] as String? ?? '').trim();

  return MemberIdentity(
    name: name,
    photoUrl: photo.isNotEmpty ? photo : fallbackPhotoUrl,
  );
}
