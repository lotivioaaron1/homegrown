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

    final clash = await existingTeamForSports(athleteId, coachSports,
        excludingCoachId: coachId);
    if (clash != null) throw AlreadyOnTeamException(clash);

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

  /// The team [athleteId] already plays for in any of [sports], or null when
  /// they are free to join one.
  ///
  /// An athlete has at most one team per sport: a basketball player belongs to
  /// one basketball team, though someone who also plays volleyball may have a
  /// volleyball coach as well. A membership doc records no sport of its own, so
  /// the sport is read off each existing coach's profile — unambiguous now that
  /// a coach handles exactly one sport.
  ///
  /// [excludingCoachId] skips the coach doing the asking, so a coach
  /// re-checking an athlete they already roster isn't reported as a clash with
  /// themselves.
  ///
  /// Two reads, and only on invite or accept — never per Scout card, which
  /// would put a query behind every row in the list.
  static Future<String?> existingTeamForSports(
    String athleteId,
    List<String> sports, {
    String? excludingCoachId,
  }) async {
    if (sports.isEmpty || athleteId.isEmpty) return null;

    final accepted = await _col
        .where('athleteId', isEqualTo: athleteId)
        .where('status', isEqualTo: 'accepted')
        .get();

    final byCoach = teamNamesByCoach(accepted.docs.map((d) => d.data()),
        excludingCoachId: excludingCoachId);
    if (byCoach.isEmpty) return null;

    final coaches = await fetchMemberProfiles(byCoach.keys);
    return clashingTeam(byCoach, coaches, sports);
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
  ///
  /// Throws [AlreadyOnTeamException] if the athlete already plays for another
  /// team in this coach's sport.
  static Future<void> acceptInvite(String inviteId) async {
    final ref = _col.doc(inviteId);
    final invite = await ref.get();
    final data = invite.data();
    final coachId = data?['coachId'] as String?;
    final athleteId = data?['athleteId'] as String?;
    if (coachId == null || athleteId == null) return;

    // The check that actually holds the one-team-per-sport rule. Two coaches
    // can both invite before either invite is answered, so an athlete can be
    // sitting on conflicting pending invites that sendInvite had no way to
    // refuse at the time — this is the last point where it can be caught.
    final coachDoc =
        await FirebaseFirestore.instance.collection('users').doc(coachId).get();
    final clash = await existingTeamForSports(
        athleteId, sportsOf(coachDoc.data()),
        excludingCoachId: coachId);
    if (clash != null) throw AlreadyOnTeamException(clash);

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

/// Thrown by [TeamService.sendInvite]/[TeamService.acceptInvite] when the
/// athlete already plays for another team in the same sport.
///
/// One athlete, one team per sport. An athlete who plays two sports may still
/// have a coach for each; they just can't hold two basketball teams at once.
class AlreadyOnTeamException implements Exception {
  /// The team they already belong to, so the message can name it.
  final String teamName;
  const AlreadyOnTeamException(this.teamName);
}

/// Maps each coach an athlete currently plays for to the team name to use when
/// naming the clash, given that athlete's accepted membership docs.
///
/// [excludingCoachId] drops the coach doing the asking, so a coach re-checking
/// an athlete they already roster is never reported as clashing with
/// themselves.
///
/// A membership whose `teamName` is missing, blank, or — Firestore enforcing no
/// schema — not a string at all still has to be nameable, since the value goes
/// straight into a sentence shown to the user. Those degrade to a generic
/// phrase rather than leaving a hole in the message.
Map<String, String> teamNamesByCoach(
  Iterable<Map<String, dynamic>> acceptedMemberships, {
  String? excludingCoachId,
}) {
  final byCoach = <String, String>{};
  for (final data in acceptedMemberships) {
    final coachId = data['coachId'];
    if (coachId is! String || coachId.isEmpty) continue;
    if (coachId == excludingCoachId) continue;

    final rawName = data['teamName'];
    final teamName = rawName is String ? rawName.trim() : '';
    byCoach[coachId] = teamName.isNotEmpty ? teamName : 'another team';
  }
  return byCoach;
}

/// The team from [teamNameByCoach] whose coach coaches any of [sports], or null
/// when the athlete is free to join one.
///
/// A membership doc records no sport of its own, so the sport comes off each
/// coach's live `users/{uid}` profile in [coachProfiles] — unambiguous now that
/// a coach handles exactly one sport. A coach whose profile is missing from the
/// map (unreadable, or deleted) contributes no sports and so never clashes,
/// which is the safe direction: it lets an invite through rather than blocking
/// one on a team that can't be identified.
String? clashingTeam(
  Map<String, String> teamNameByCoach,
  Map<String, Map<String, dynamic>> coachProfiles,
  List<String> sports,
) {
  for (final entry in teamNameByCoach.entries) {
    if (sportsOverlap(sportsOf(coachProfiles[entry.key]), sports)) {
      return entry.value;
    }
  }
  return null;
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
