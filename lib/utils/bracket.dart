// lib/utils/bracket.dart
import '../models/bracket_slot.dart';
import '../models/tournament.dart';

/// Pure single-elimination bracket maths — no Firebase, no widgets, so the
/// awkward parts (seeding, byes, who advances where) are testable on their
/// own. Kept alongside elo_calculator.dart and stat_scoring.dart, which
/// follow the same rule.
///
/// Rounds and slots are both 1-based. Round 1 is the first round played and
/// the last round is always a single slot, the final. A slot's id is
/// 'r{round}m{slot}', which is deterministic on purpose: the slot a winner
/// advances into is computed from the current one rather than stored and
/// looked up, so the whole bracket can be written in a single batch.

/// The smallest power of two greater than or equal to [n].
int nextPowerOfTwo(int n) {
  var p = 1;
  while (p < n) {
    p <<= 1;
  }
  return p;
}

/// How many rounds a bracket of [entrantCount] teams needs, counting the
/// final. Four teams take two rounds, sixteen take four.
int roundCountFor(int entrantCount) {
  var rounds = 0;
  final size = nextPowerOfTwo(entrantCount);
  while ((1 << rounds) < size) {
    rounds++;
  }
  return rounds;
}

/// The classic recursive seeding order: the seed number occupying each
/// bracket position, top to bottom.
///
/// Start with [1, 2] and repeatedly replace each seed `s` with the pair
/// `s, n + 1 - s`, where `n` is the doubled length. For eight this gives
/// [1, 8, 4, 5, 2, 7, 3, 6], so the top two seeds can only meet in the
/// final and each round pairs the strongest surviving team with the
/// weakest.
List<int> seedOrder(int size) {
  if (size < 2) return const [1];
  var order = <int>[1, 2];
  while (order.length < size) {
    final n = order.length * 2;
    final next = <int>[];
    for (final s in order) {
      next.add(s);
      next.add(n + 1 - s);
    }
    order = next;
  }
  return order;
}

/// The document id for a bracket position.
String slotId(int round, int slot) => 'r${round}m$slot';

/// The slot a winner of `(round, slot)` advances into, or null for the
/// final. Two adjacent slots feed the same slot in the next round: the
/// odd-numbered one takes side A, the even-numbered one side B.
String? nextSlotIdFor(int round, int slot, int roundCount) =>
    round >= roundCount ? null : slotId(round + 1, (slot + 1) ~/ 2);

/// Which side of the next slot the winner of `(round, slot)` occupies.
String? nextSlotSideFor(int round, int slot, int roundCount) =>
    round >= roundCount ? null : (slot.isOdd ? 'A' : 'B');

/// Human-readable name for a round, counting back from the final.
String roundLabel(int round, int roundCount) {
  final fromEnd = roundCount - round;
  if (fromEnd == 0) return 'Final';
  if (fromEnd == 1) return 'Semifinal';
  if (fromEnd == 2) return 'Quarterfinal';
  return 'Round of ${1 << (fromEnd + 1)}';
}

/// Builds the complete bracket for [seededEntrants], which must already be
/// ordered by seed — index 0 is seed 1, the top seed.
///
/// [organizerId] is stamped onto every slot because that is what the
/// security rule checks; see [BracketSlot.organizerId] for why the rule
/// cannot read it off the parent tournament instead.
///
/// Every slot of every round is returned, including the ones whose teams
/// are not known yet, so the organizer sees the shape of the whole
/// competition from the moment it is created.
///
/// When the entrant count is not a power of two the strongest seeds get
/// round-one byes. Those are resolved here rather than left for the
/// organizer to click through: a bye slot is marked [BracketSlot.statusBye]
/// with its winner already set, and that team is placed into its round-two
/// slot in the same pass. Because the number of byes is always fewer than
/// half the bracket, byes can only ever fall in round one — never in a
/// later round, and never in the final.
List<BracketSlot> generateBracket(
  List<TournamentEntrant> seededEntrants, {
  required String organizerId,
}) {
  final n = seededEntrants.length;
  if (n < 2) {
    throw ArgumentError('A bracket needs at least 2 entrants, got $n');
  }

  final size = nextPowerOfTwo(n);
  final roundCount = roundCountFor(n);
  final order = seedOrder(size);

  // Every slot of every round, keyed by id, built empty first so that
  // placing a bye winner into the next round is a simple lookup.
  final slots = <String, _SlotDraft>{};
  for (var round = 1; round <= roundCount; round++) {
    final slotsInRound = size >> round;
    for (var slot = 1; slot <= slotsInRound; slot++) {
      final id = slotId(round, slot);
      slots[id] = _SlotDraft(
        id: id,
        organizerId: organizerId,
        round: round,
        slot: slot,
        nextSlotId: nextSlotIdFor(round, slot, roundCount),
        nextSlotSide: nextSlotSideFor(round, slot, roundCount),
      );
    }
  }

  // Round one: seed positions 2k-1 and 2k face each other. A position
  // beyond the entrant count is an empty chair, i.e. a bye for the team
  // opposite it.
  for (var slot = 1; slot <= size ~/ 2; slot++) {
    final draft = slots[slotId(1, slot)]!;
    final seedA = order[2 * slot - 2];
    final seedB = order[2 * slot - 1];
    draft.entrantA =
        seedA <= n ? SlotEntrant.of(seededEntrants[seedA - 1]) : null;
    draft.entrantB =
        seedB <= n ? SlotEntrant.of(seededEntrants[seedB - 1]) : null;
  }

  for (var slot = 1; slot <= size ~/ 2; slot++) {
    final draft = slots[slotId(1, slot)]!;
    if (draft.entrantA != null && draft.entrantB != null) {
      draft.status = BracketSlot.statusReady;
      continue;
    }
    final walkover = draft.entrantA ?? draft.entrantB;
    if (walkover == null) {
      // Unreachable while byes < size / 2, which holds for every entrant
      // count. Guarded rather than silently dropping a slot.
      throw StateError('Bracket slot ${draft.id} has no entrants');
    }
    draft.status = BracketSlot.statusBye;
    draft.winnerCoachId = walkover.coachId;
    _advance(slots, draft, walkover);
  }

  final built = slots.values.map((d) => d.build()).toList()
    ..sort((a, b) => a.round == b.round
        ? a.slot.compareTo(b.slot)
        : a.round.compareTo(b.round));
  return built;
}

/// Places [winner] into the slot [from] feeds, and marks that slot ready
/// once both of its sides are known.
void _advance(
    Map<String, _SlotDraft> slots, _SlotDraft from, SlotEntrant winner) {
  final nextId = from.nextSlotId;
  if (nextId == null) return;
  final next = slots[nextId];
  if (next == null) return;
  if (from.nextSlotSide == 'A') {
    next.entrantA = winner;
  } else {
    next.entrantB = winner;
  }
  if (next.entrantA != null && next.entrantB != null) {
    next.status = BracketSlot.statusReady;
  }
}

/// Mutable scratch type used only while generating; [build] freezes it into
/// the immutable model that actually gets stored.
class _SlotDraft {
  final String id;
  final String organizerId;
  final int round;
  final int slot;
  final String? nextSlotId;
  final String? nextSlotSide;

  SlotEntrant? entrantA;
  SlotEntrant? entrantB;
  String status = BracketSlot.statusAwaiting;
  String? winnerCoachId;

  _SlotDraft({
    required this.id,
    required this.organizerId,
    required this.round,
    required this.slot,
    required this.nextSlotId,
    required this.nextSlotSide,
  });

  BracketSlot build() => BracketSlot(
        id: id,
        organizerId: organizerId,
        round: round,
        slot: slot,
        entrantA: entrantA,
        entrantB: entrantB,
        nextSlotId: nextSlotId,
        nextSlotSide: nextSlotSide,
        status: status,
        winnerCoachId: winnerCoachId,
      );
}
