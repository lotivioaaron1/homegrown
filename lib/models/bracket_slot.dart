// lib/models/bracket_slot.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'tournament.dart';

/// A team as referenced from a bracket slot: identity only, no roster.
///
/// The full [TournamentEntrant] (including its player snapshot) lives once
/// on the tournament document; a slot stores just enough to draw the
/// bracket without re-reading it, and looks the entrant up by `coachId`
/// when a matchup is actually scheduled.
class SlotEntrant {
  final int seed;
  final String coachId;
  final String teamName;
  final String? teamLogoUrl;

  const SlotEntrant({
    required this.seed,
    required this.coachId,
    required this.teamName,
    this.teamLogoUrl,
  });

  factory SlotEntrant.of(TournamentEntrant e) => SlotEntrant(
        seed: e.seed,
        coachId: e.coachId,
        teamName: e.teamName,
        teamLogoUrl: e.teamLogoUrl,
      );

  Map<String, dynamic> toMap() => {
        'seed': seed,
        'coachId': coachId,
        'teamName': teamName,
        'teamLogoUrl': teamLogoUrl,
      };

  factory SlotEntrant.fromMap(Map<String, dynamic> map) => SlotEntrant(
        seed: (map['seed'] as num?)?.toInt() ?? 0,
        coachId: map['coachId'] as String? ?? '',
        teamName: map['teamName'] as String? ?? '',
        teamLogoUrl: map['teamLogoUrl'] as String?,
      );
}

/// One position in a single-elimination bracket, stored at
/// tournaments/{tid}/slots/{slotId} where slotId is 'r{round}m{slot}'.
///
/// Both numbers are 1-based, and the id is deterministic so the slot a
/// winner advances into can be computed rather than looked up — see
/// [lib/utils/bracket.dart]. Round 1 is the first round played; the last
/// round always holds exactly one slot, the final.
///
/// The subcollection is named `slots`, not `matches`, so it can never be
/// confused with the top-level `matches` collection that holds real match
/// results — a collection-group index or query on "matches" would
/// otherwise span both.
class BracketSlot {
  /// Neither side is known yet — both feed from earlier matchups.
  static const String statusAwaiting = 'awaiting';

  /// Both sides known, no event scheduled yet.
  static const String statusReady = 'ready';

  /// A child event exists for this matchup but no result is in.
  static const String statusScheduled = 'scheduled';

  /// Played, or walked over. [winnerCoachId] is set.
  static const String statusCompleted = 'completed';

  /// Only one side exists, so that team advances without playing. Only ever
  /// occurs in round 1.
  static const String statusBye = 'bye';

  final String id;

  /// Copied from the parent tournament onto every slot.
  ///
  /// This is what the security rule checks. It cannot read the parent
  /// instead: a rules `get()` sees pre-batch state, so while the whole
  /// bracket is being written in one batch the tournament document does
  /// not exist yet, and a bracket of any size would also blow the
  /// twenty-document-access ceiling a batched write is allowed.
  final String organizerId;

  final int round;
  final int slot;

  final SlotEntrant? entrantA;
  final SlotEntrant? entrantB;

  /// The slot this matchup's winner advances into, and which side of it
  /// they occupy. Null on the final.
  final String? nextSlotId;
  final String? nextSlotSide; // 'A' | 'B'

  final String status;

  /// The events/{id} spawned for this matchup, once scheduled.
  final String? eventId;

  /// The matches/{id} written when the result was recorded.
  final String? matchId;

  final int? scoreA;
  final int? scoreB;
  final String? winnerCoachId;
  final DateTime? completedAt;

  const BracketSlot({
    required this.id,
    required this.organizerId,
    required this.round,
    required this.slot,
    this.entrantA,
    this.entrantB,
    this.nextSlotId,
    this.nextSlotSide,
    this.status = statusAwaiting,
    this.eventId,
    this.matchId,
    this.scoreA,
    this.scoreB,
    this.winnerCoachId,
    this.completedAt,
  });

  bool get isFinal => nextSlotId == null;
  bool get isDecided => winnerCoachId != null;
  bool get isBye => status == statusBye;
  bool get isScheduled => status == statusScheduled;
  bool get hasBothSides => entrantA != null && entrantB != null;

  SlotEntrant? get winner {
    if (winnerCoachId == null) return null;
    if (entrantA?.coachId == winnerCoachId) return entrantA;
    if (entrantB?.coachId == winnerCoachId) return entrantB;
    return null;
  }

  Map<String, dynamic> toMap() => {
        'organizerId': organizerId,
        'round': round,
        'slot': slot,
        'entrantA': entrantA?.toMap(),
        'entrantB': entrantB?.toMap(),
        'nextSlotId': nextSlotId,
        'nextSlotSide': nextSlotSide,
        'status': status,
        'eventId': eventId,
        'matchId': matchId,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'winnerCoachId': winnerCoachId,
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      };

  factory BracketSlot.fromMap(String id, Map<String, dynamic> map) {
    SlotEntrant? entrant(Object? raw) => raw == null
        ? null
        : SlotEntrant.fromMap(Map<String, dynamic>.from(raw as Map));

    return BracketSlot(
      id: id,
      organizerId: map['organizerId'] as String? ?? '',
      round: (map['round'] as num?)?.toInt() ?? 1,
      slot: (map['slot'] as num?)?.toInt() ?? 1,
      entrantA: entrant(map['entrantA']),
      entrantB: entrant(map['entrantB']),
      nextSlotId: map['nextSlotId'] as String?,
      nextSlotSide: map['nextSlotSide'] as String?,
      status: map['status'] as String? ?? statusAwaiting,
      eventId: map['eventId'] as String?,
      matchId: map['matchId'] as String?,
      scoreA: (map['scoreA'] as num?)?.toInt(),
      scoreB: (map['scoreB'] as num?)?.toInt(),
      winnerCoachId: map['winnerCoachId'] as String?,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}
