// lib/services/rating_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_result.dart';
import '../models/rating_history_entry.dart';
import '../utils/elo_calculator.dart';

/// Records matches (two sides of an event's roster + a final score) and,
/// once every participant's stats are in, applies the Elo/MMR update to
/// each participant's per-sport rating. Kept as static helpers, matching
/// TeamService/NotificationService's style.
class RatingService {
  static final _matches = FirebaseFirestore.instance.collection('matches');
  static final _users = FirebaseFirestore.instance.collection('users');
  static final _stats = FirebaseFirestore.instance.collection('stats');
  static final _events = FirebaseFirestore.instance.collection('events');

  static String sportKey(String sport) => sport.toLowerCase();

  /// Creates a pending match. [scoreA] and [scoreB] must differ -- none of
  /// basketball, volleyball or badminton end in a draw.
  static Future<String> recordMatch({
    required String eventId,
    required String sport,
    required List<String> sideA,
    required List<String> sideB,
    required int scoreA,
    required int scoreB,
    required String recordedBy,
  }) async {
    assert(scoreA != scoreB, 'A match cannot end in a tie');
    final winner = scoreA > scoreB ? 'A' : 'B';
    final doc = _matches.doc();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(doc, {
      'eventId': eventId,
      'sport': sport,
      'sideA': sideA,
      'sideB': sideB,
      'scoreA': scoreA,
      'scoreB': scoreB,
      'winner': winner,
      'status': 'pending',
      'recordedBy': recordedBy,
      'createdAt': FieldValue.serverTimestamp(),
      'finalizedAt': null,
    });
    // Denormalized onto the event so the Delete-event Firestore rule can
    // check "does this event have any match data" without an arbitrary
    // collection query, which security rules can't cheaply express.
    batch.update(_events.doc(eventId), {'hasMatchData': true});
    await batch.commit();
    return doc.id;
  }

  static Stream<QuerySnapshot> pendingMatchesForEvent(String eventId) =>
      _matches
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: 'pending')
          .snapshots();

  /// Whether every participant of [matchId] has a `stats` doc recorded
  /// yet. AddStatsScreen calls this after each save to know whether it's
  /// time to finalize the match.
  static Future<bool> allStatsSubmitted(
      String matchId, List<String> participants) async {
    final snap =
        await _stats.where('matchId', isEqualTo: matchId).get();
    final submitted =
        snap.docs.map((d) => d['athleteId'] as String).toSet();
    return participants.every(submitted.contains);
  }

  /// Applies the Elo update to every participant of [matchId] and marks
  /// it finalized. No-ops if the match is missing or already finalized,
  /// so it's safe to call more than once.
  static Future<void> finalizeMatch(String matchId) async {
    final matchRef = _matches.doc(matchId);

    final pendingSnap = await matchRef.get();
    if (!pendingSnap.exists) return;
    final pendingMatch =
        MatchResult.fromMap(pendingSnap.id, pendingSnap.data()!);
    if (pendingMatch.isFinalized) return;

    final statsSnap =
        await _stats.where('matchId', isEqualTo: matchId).get();
    final performanceScores = <String, double>{
      for (final d in statsSnap.docs)
        d['athleteId'] as String: (d['pointsAwarded'] as num).toDouble(),
    };

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final matchSnap = await tx.get(matchRef);
      if (!matchSnap.exists) return;
      final match = MatchResult.fromMap(matchSnap.id, matchSnap.data()!);
      if (match.isFinalized) return;

      final participants = match.allParticipants;
      final userSnaps = <String, DocumentSnapshot>{};
      for (final uid in participants) {
        userSnaps[uid] = await tx.get(_users.doc(uid));
      }

      final sport = sportKey(match.sport);
      final currentRatings = <String, int>{
        for (final entry in userSnaps.entries)
          entry.key: (((entry.value.data()
                          as Map<String, dynamic>?)?['ratings']
                      as Map?)?[sport] as num?)
                  ?.toInt() ??
              kStartingRating,
      };

      final update = calculateEloUpdate(
        sideA: match.sideA,
        sideB: match.sideB,
        currentRatings: currentRatings,
        performanceScores: performanceScores,
        winner: match.winner,
      );

      for (final uid in participants) {
        final oldRating = currentRatings[uid] ?? kStartingRating;
        final newRating = update.newRatings[uid] ?? oldRating;
        final onSideA = match.sideA.contains(uid);
        final won = (onSideA && match.winner == 'A') ||
            (!onSideA && match.winner == 'B');

        tx.update(_users.doc(uid), {'ratings.$sport': newRating});

        final history = RatingHistoryEntry(
          matchId: matchId,
          sport: match.sport,
          oldRating: oldRating,
          newRating: newRating,
          delta: update.deltas[uid] ?? 0,
          result: won ? 'win' : 'loss',
        );
        tx.set(
          _users.doc(uid).collection('ratingHistory').doc(matchId),
          {...history.toMap(), 'createdAt': FieldValue.serverTimestamp()},
        );
      }

      tx.update(matchRef, {
        'status': 'finalized',
        'finalizedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Stream<QuerySnapshot> ratingHistoryStream(String uid, String sport) =>
      _users
          .doc(uid)
          .collection('ratingHistory')
          .where('sport', isEqualTo: sport)
          .orderBy('createdAt', descending: true)
          .snapshots();
}
