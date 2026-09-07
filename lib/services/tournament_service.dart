// lib/services/tournament_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/bracket_slot.dart';
import '../models/tournament.dart';
import '../utils/bracket.dart';
import 'notification_service.dart';
import 'team_service.dart';

/// Thrown when a picked coach has nobody on their roster.
///
/// An entrant with no players can never finish its matchup — Record Match
/// refuses a side with zero players — so the bracket would deadlock. Caught
/// at the point of entry instead, where the organizer can still swap the
/// team out.
class EmptyEntrantRosterException implements Exception {
  final String teamName;
  const EmptyEntrantRosterException(this.teamName);
  @override
  String toString() => '$teamName has no accepted players yet.';
}

/// Creates and runs single-elimination tournaments.
///
/// Kept as static helpers, matching TeamService/RatingService rather than
/// introducing a controller: every screen that needs this wants the same
/// stateless read/write calls.
///
/// The bracket deliberately reuses the ordinary event pipeline rather than
/// duplicating it. When a matchup is scheduled it spawns a normal
/// `events/{id}` document, so Record Match, Add Stats, the Elo update and
/// the event detail screen all work on it untouched; the only additions are
/// the `tournamentId`/`tournamentSlotId` back-pointers. A tournament win
/// therefore moves an athlete's rating exactly like any other game.
class TournamentService {
  static final _db = FirebaseFirestore.instance;
  static final _tournaments = _db.collection('tournaments');
  static final _events = _db.collection('events');

  /// Bracket positions live in `slots`, not `matches`, so they can never be
  /// confused with the top-level `matches` collection of real results.
  static CollectionReference<Map<String, dynamic>> slotsOf(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('slots');

  // ── Reads ────────────────────────────────────────────

  static Stream<DocumentSnapshot<Map<String, dynamic>>> tournamentStream(
          String tournamentId) =>
      _tournaments.doc(tournamentId).snapshots();

  /// Every slot of a bracket — at most fifteen documents, so they are
  /// ordered client-side by [sortSlots] rather than paying for a composite
  /// index, the same call the home screen and Add Stats already make.
  static Stream<QuerySnapshot<Map<String, dynamic>>> slotsStream(
          String tournamentId) =>
      slotsOf(tournamentId).snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> forOrganizer(String uid) =>
      _tournaments
          .where('organizerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots();

  static List<BracketSlot> sortSlots(Iterable<BracketSlot> slots) =>
      slots.toList()
        ..sort((a, b) => a.round == b.round
            ? a.slot.compareTo(b.slot)
            : a.round.compareTo(b.round));

  static List<BracketSlot> slotsFrom(QuerySnapshot<Map<String, dynamic>> snap) =>
      sortSlots(snap.docs.map((d) => BracketSlot.fromMap(d.id, d.data())));

  // ── Building entrants ────────────────────────────────

  /// Turns a picked coach into an entrant, snapshotting their roster as it
  /// stands right now.
  ///
  /// The snapshot is the point: a bracket has to stay stable for its whole
  /// run, so an athlete joining or leaving the coach's team midway through
  /// must not silently change who is on the teamsheet for a semifinal.
  /// [seed] is assigned by the caller from the order teams were entered.
  static Future<TournamentEntrant> buildEntrant({
    required int seed,
    required String coachId,
    required String teamName,
    String coachName = '',
    String? teamLogoUrl,
  }) async {
    final rosterSnap = await TeamService.fetchRoster(coachId);
    final athleteIds = rosterSnap.docs
        .map((d) => (d.data() as Map<String, dynamic>)['athleteId'] as String)
        .toList();
    if (athleteIds.isEmpty) throw EmptyEntrantRosterException(teamName);

    // A roster is capped at TeamService.maxPlayers (15), comfortably under
    // the 30-value ceiling on whereIn, so this never needs chunking.
    final usersSnap = await _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: athleteIds)
        .get();

    return TournamentEntrant(
      seed: seed,
      coachId: coachId,
      teamName: teamName,
      coachName: coachName,
      teamLogoUrl: teamLogoUrl,
      players: usersSnap.docs.map((d) {
        final u = d.data();
        return EntrantPlayer(
          uid: d.id,
          fullName: u['fullName'] as String? ?? '',
          position: u['position'] as String? ?? '',
        );
      }).toList(),
    );
  }

  // ── Creating ─────────────────────────────────────────

  /// Writes the tournament and its entire bracket in one batch.
  ///
  /// [entrants] must be in seed order — index 0 is the top seed. Every slot
  /// of every round is created up front, including the ones whose teams are
  /// not known yet, so the organizer sees the shape of the whole
  /// competition immediately. Byes are resolved here too, in the same
  /// batch. At most sixteen entrants means at most sixteen writes, well
  /// inside the 500-write batch limit.
  static Future<String> create({
    required String organizerId,
    required String name,
    required String description,
    required String sport,
    required bool isPublic,
    required String venue,
    required String venueAddress,
    required double venueLat,
    required double venueLng,
    required String venueType,
    required List<TournamentEntrant> entrants,
  }) async {
    if (entrants.length < Tournament.minEntrants ||
        entrants.length > Tournament.maxEntrants) {
      throw ArgumentError(
          'A tournament needs ${Tournament.minEntrants}-${Tournament.maxEntrants} '
          'teams, got ${entrants.length}');
    }

    final tournamentId = const Uuid().v4();
    // Re-stamp the seeds from list order so they are always 1..N and always
    // agree with the index generateBracket reads them by.
    final seeded = [
      for (var i = 0; i < entrants.length; i++) entrants[i].copyWith(seed: i + 1)
    ];

    final tournament = Tournament(
      id: tournamentId,
      organizerId: organizerId,
      name: name,
      description: description,
      sport: sport,
      status: Tournament.statusActive,
      isPublic: isPublic,
      venue: venue,
      venueAddress: venueAddress,
      venueLat: venueLat,
      venueLng: venueLng,
      venueType: venueType,
      entrantCount: seeded.length,
      roundCount: roundCountFor(seeded.length),
      entrants: seeded,
    );

    final batch = _db.batch();
    batch.set(_tournaments.doc(tournamentId), {
      ...tournament.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (final slot in generateBracket(seeded, organizerId: organizerId)) {
      batch.set(slotsOf(tournamentId).doc(slot.id), slot.toMap());
    }
    await batch.commit();
    return tournamentId;
  }

  // ── Scheduling a matchup ─────────────────────────────

  /// Spawns the child event for a matchup and marks the slot scheduled.
  ///
  /// The event is an ordinary one in every respect, which is what lets the
  /// existing Record Match and Add Stats screens handle it. Two details
  /// matter: `eventId` must equal the document id, because the `matches`
  /// and `stats` security rules read it back to find the event's organizer;
  /// and the status must stay `'upcoming'` for the life of the tournament,
  /// because both of those screens only list upcoming events — flipping it
  /// would leave the bracket showing a winner whose ratings could never be
  /// finalized.
  static Future<String> scheduleSlot({
    required Tournament tournament,
    required BracketSlot slot,
    required DateTime kickoff,
  }) async {
    final a = tournament.entrantFor(slot.entrantA!.coachId);
    final b = tournament.entrantFor(slot.entrantB!.coachId);
    if (a == null || b == null) {
      throw StateError('Slot ${slot.id} refers to a team not in this tournament');
    }

    final eventId = const Uuid().v4();
    final players = [
      for (final p in a.players) {...p.toMap(), 'team': 'A'},
      for (final p in b.players) {...p.toMap(), 'team': 'B'},
    ];
    final label = roundLabel(slot.round, tournament.roundCount);

    final batch = _db.batch();
    batch.set(_events.doc(eventId), {
      'eventId': eventId,
      'organizerId': tournament.organizerId,
      'name': '${tournament.name} — $label: ${a.teamName} vs ${b.teamName}',
      'description': '$label of ${tournament.name}.',
      'sport': tournament.sport,
      'eventType': 'Tournament',
      'venue': tournament.venue,
      'venueAddress': tournament.venueAddress,
      'venueLat': tournament.venueLat,
      'venueLng': tournament.venueLng,
      'venueType': tournament.venueType,
      'eventDate': Timestamp.fromDate(kickoff),
      'teamAName': a.teamName,
      'teamBName': b.teamName,
      'players': players,
      'playerUids': players.map((p) => p['uid'] as String).toList(),
      'playerCount': players.length,
      'maxPlayers': null,
      'isPublic': tournament.isPublic,
      'teamACoachId': a.coachId,
      'teamBCoachId': b.coachId,
      'status': 'upcoming',
      'createdAt': FieldValue.serverTimestamp(),
      // Back-pointers. Their presence is also what tells the event detail
      // screen this event is managed by a bracket and must not be deleted.
      'tournamentId': tournament.id,
      'tournamentSlotId': slot.id,
    });

    batch.update(slotsOf(tournament.id).doc(slot.id), {
      'eventId': eventId,
      'status': BracketSlot.statusScheduled,
    });

    for (final p in players) {
      await NotificationService.create(
        userId: p['uid'] as String,
        type: 'event_added',
        title: "You're in an upcoming game",
        body: '$label of ${tournament.name} at ${tournament.venue}',
        relatedId: eventId,
        writeBatch: batch,
      );
    }

    await batch.commit();
    return eventId;
  }

  /// Puts a slot back to ready and forgets its event.
  ///
  /// Firestore cannot enforce that a child event still exists, so a slot
  /// can end up pointing at an event the organizer deleted or cancelled
  /// outside the bracket. Rather than leaving the tournament permanently
  /// stuck, the bracket screen offers this and the matchup can be
  /// scheduled again.
  static Future<void> unscheduleSlot(String tournamentId, String slotId) =>
      slotsOf(tournamentId).doc(slotId).update({
        'eventId': null,
        'status': BracketSlot.statusReady,
      });

  // ── Advancing ────────────────────────────────────────

  /// Stages the writes that settle [slot] and move its winner on.
  ///
  /// Staged onto a caller-supplied batch rather than committed here so that
  /// it lands in the very same commit as the match result it is derived
  /// from — the bracket can then never disagree with the recorded match.
  ///
  /// [nextSlot] is passed in because a batch cannot read: deciding whether
  /// the following matchup is now ready to play needs to know whether its
  /// other side is already filled, and the caller is holding every slot
  /// anyway.
  ///
  /// Advancement keys off the winner of a *pending* match, which is settled
  /// the moment a score is entered. The bracket therefore moves on
  /// immediately while the Elo update waits for per-player stats, so a
  /// sixteen-team draw is never stalled behind box scores.
  static void stageAdvance(
    WriteBatch batch, {
    required Tournament tournament,
    required BracketSlot slot,
    required BracketSlot? nextSlot,
    required String matchId,
    required int scoreA,
    required int scoreB,
    required String winnerSide, // 'A' | 'B'
  }) {
    final winner = winnerSide == 'A' ? slot.entrantA : slot.entrantB;
    if (winner == null) {
      throw StateError('Slot ${slot.id} has no team on side $winnerSide');
    }

    batch.update(slotsOf(tournament.id).doc(slot.id), {
      'matchId': matchId,
      'scoreA': scoreA,
      'scoreB': scoreB,
      'winnerCoachId': winner.coachId,
      'status': BracketSlot.statusCompleted,
      'completedAt': FieldValue.serverTimestamp(),
    });

    if (slot.nextSlotId == null || nextSlot == null) {
      // That was the final.
      batch.update(_tournaments.doc(tournament.id), {
        'championCoachId': winner.coachId,
        'championTeamName': winner.teamName,
        'status': Tournament.statusCompleted,
        'completedAt': FieldValue.serverTimestamp(),
        'hasMatchData': true,
      });
      return;
    }

    final onSideA = slot.nextSlotSide == 'A';
    final otherSideFilled =
        onSideA ? nextSlot.entrantB != null : nextSlot.entrantA != null;

    final advance = <String, dynamic>{
      onSideA ? 'entrantA' : 'entrantB': winner.toMap(),
    };
    // The following matchup can only be played once both of its teams are
    // known, and a batch cannot read to find that out — hence nextSlot.
    if (otherSideFilled) advance['status'] = BracketSlot.statusReady;
    batch.update(slotsOf(tournament.id).doc(nextSlot.id), advance);

    batch.update(_tournaments.doc(tournament.id), {'hasMatchData': true});
  }

  // ── Deleting ─────────────────────────────────────────

  /// Removes a tournament and its bracket.
  ///
  /// Firestore does not cascade, so the slots have to go explicitly or they
  /// would linger as orphans readable by any signed-in user. At most
  /// sixteen writes.
  static Future<void> delete(String tournamentId) async {
    final slots = await slotsOf(tournamentId).get();
    final batch = _db.batch();
    for (final doc in slots.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_tournaments.doc(tournamentId));
    await batch.commit();
  }
}
