import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/models/bracket_slot.dart';
import 'package:homegrown/models/tournament.dart';
import 'package:homegrown/utils/bracket.dart';

const _organizerId = 'org-1';

/// Entrants seeded 1..n, named after their seed so assertions read plainly.
List<TournamentEntrant> _entrants(int n) => List.generate(
      n,
      (i) => TournamentEntrant(
        seed: i + 1,
        coachId: 'coach${i + 1}',
        teamName: 'Team ${i + 1}',
        players: [EntrantPlayer(uid: 'p${i + 1}', fullName: 'Player ${i + 1}')],
      ),
    );

List<BracketSlot> _bracket(int n) =>
    generateBracket(_entrants(n), organizerId: _organizerId);

/// The seed numbers facing each other in round one, in slot order.
List<List<int?>> _firstRoundPairs(List<BracketSlot> slots) => slots
    .where((s) => s.round == 1)
    .map((s) => [s.entrantA?.seed, s.entrantB?.seed])
    .toList();

void main() {
  group('nextPowerOfTwo', () {
    test('returns n itself when n is already a power of two', () {
      expect(nextPowerOfTwo(4), 4);
      expect(nextPowerOfTwo(16), 16);
    });

    test('rounds up otherwise', () {
      expect(nextPowerOfTwo(3), 4);
      expect(nextPowerOfTwo(5), 8);
      expect(nextPowerOfTwo(12), 16);
    });
  });

  group('roundCountFor', () {
    test('counts rounds including the final', () {
      expect(roundCountFor(4), 2); // semifinals, final
      expect(roundCountFor(8), 3); // quarters, semis, final
      expect(roundCountFor(16), 4);
    });

    test('a non-power-of-two takes the same rounds as its padded size', () {
      expect(roundCountFor(5), roundCountFor(8));
      expect(roundCountFor(12), roundCountFor(16));
    });
  });

  group('seedOrder', () {
    test('produces the classic recursive order', () {
      expect(seedOrder(2), [1, 2]);
      expect(seedOrder(4), [1, 4, 2, 3]);
      expect(seedOrder(8), [1, 8, 4, 5, 2, 7, 3, 6]);
      expect(seedOrder(16),
          [1, 16, 8, 9, 4, 13, 5, 12, 2, 15, 7, 10, 3, 14, 6, 11]);
    });

    test('every seed appears exactly once', () {
      final order = seedOrder(16);
      expect(order.toSet().length, 16);
      expect(order.reduce((a, b) => a + b), 16 * 17 ~/ 2);
    });

    test('each pair sums to one more than the bracket size', () {
      // This is the property that keeps the strongest surviving team paired
      // with the weakest, and keeps seeds 1 and 2 apart until the final.
      final order = seedOrder(8);
      for (var i = 0; i < order.length; i += 2) {
        expect(order[i] + order[i + 1], 9);
      }
    });
  });

  group('slot identity and advancement', () {
    test('slot ids are deterministic', () {
      expect(slotId(1, 1), 'r1m1');
      expect(slotId(3, 12), 'r3m12');
    });

    test('adjacent slots feed the same next slot, on opposite sides', () {
      expect(nextSlotIdFor(1, 1, 3), 'r2m1');
      expect(nextSlotIdFor(1, 2, 3), 'r2m1');
      expect(nextSlotSideFor(1, 1, 3), 'A');
      expect(nextSlotSideFor(1, 2, 3), 'B');

      expect(nextSlotIdFor(1, 3, 3), 'r2m2');
      expect(nextSlotIdFor(1, 4, 3), 'r2m2');
    });

    test('the final advances nowhere', () {
      expect(nextSlotIdFor(3, 1, 3), isNull);
      expect(nextSlotSideFor(3, 1, 3), isNull);
    });
  });

  group('roundLabel', () {
    test('names the closing rounds', () {
      expect(roundLabel(3, 3), 'Final');
      expect(roundLabel(2, 3), 'Semifinal');
      expect(roundLabel(1, 3), 'Quarterfinal');
    });

    test('a four-team bracket opens at the semifinals', () {
      expect(roundLabel(1, 2), 'Semifinal');
      expect(roundLabel(2, 2), 'Final');
    });

    test('earlier rounds are named by how many teams remain', () {
      expect(roundLabel(1, 4), 'Round of 16');
      expect(roundLabel(1, 5), 'Round of 32');
      expect(roundLabel(2, 5), 'Round of 16');
    });
  });

  group('generateBracket — a power-of-two field', () {
    test('8 teams produce 4 quarterfinals, 2 semifinals and a final', () {
      final slots = _bracket(8);
      expect(slots.where((s) => s.round == 1).length, 4);
      expect(slots.where((s) => s.round == 2).length, 2);
      expect(slots.where((s) => s.round == 3).length, 1);
    });

    test('pairs teams in seed order, top against bottom', () {
      expect(_firstRoundPairs(_bracket(8)), [
        [1, 8],
        [4, 5],
        [2, 7],
        [3, 6],
      ]);
    });

    test('no byes, so every first-round slot is ready to play', () {
      final slots = _bracket(8);
      expect(slots.where((s) => s.round == 1).every((s) => s.status == BracketSlot.statusReady), isTrue);
      expect(slots.any((s) => s.isBye), isFalse);
    });

    test('later rounds wait for their feeders', () {
      final slots = _bracket(8);
      expect(
        slots.where((s) => s.round > 1).every(
            (s) => s.status == BracketSlot.statusAwaiting && !s.hasBothSides),
        isTrue,
      );
    });

    test('exactly one slot is the final', () {
      final finals = _bracket(8).where((s) => s.isFinal).toList();
      expect(finals.length, 1);
      expect(finals.single.id, 'r3m1');
    });

    test('every slot carries the organizer id the rules check', () {
      expect(_bracket(8).every((s) => s.organizerId == _organizerId), isTrue);
    });

    test('slots come back ordered by round then slot', () {
      final ids = _bracket(4).map((s) => s.id).toList();
      expect(ids, ['r1m1', 'r1m2', 'r2m1']);
    });
  });

  group('generateBracket — byes', () {
    test('3 teams: the top seed walks into the final', () {
      final slots = _bracket(3);
      expect(_firstRoundPairs(slots), [
        [1, null],
        [2, 3],
      ]);

      final bye = slots.firstWhere((s) => s.id == 'r1m1');
      expect(bye.status, BracketSlot.statusBye);
      expect(bye.winnerCoachId, 'coach1');

      // ...and is already placed in the final rather than left for the
      // organizer to click through.
      final finalSlot = slots.firstWhere((s) => s.id == 'r2m1');
      expect(finalSlot.entrantA?.seed, 1);
      expect(finalSlot.entrantB, isNull);
      expect(finalSlot.status, BracketSlot.statusAwaiting);
    });

    test('6 teams: seeds 1 and 2 sit out round one', () {
      final slots = _bracket(6);
      expect(_firstRoundPairs(slots), [
        [1, null],
        [4, 5],
        [2, null],
        [3, 6],
      ]);
      expect(
        slots.where((s) => s.isBye).map((s) => s.winnerCoachId),
        ['coach1', 'coach2'],
      );
    });

    test('5 teams: a semifinal is ready immediately when both feeders are byes',
        () {
      final slots = _bracket(5);
      // Seeds 2 and 3 both had byes, so their semifinal already has a
      // full pairing and can be scheduled straight away.
      final semi = slots.firstWhere((s) => s.id == 'r2m2');
      expect(semi.entrantA?.seed, 2);
      expect(semi.entrantB?.seed, 3);
      expect(semi.status, BracketSlot.statusReady);

      // The other semifinal still waits on the one real first-round match.
      final other = slots.firstWhere((s) => s.id == 'r2m1');
      expect(other.entrantA?.seed, 1);
      expect(other.entrantB, isNull);
      expect(other.status, BracketSlot.statusAwaiting);
    });

    test('12 teams: the top four seeds get byes', () {
      final byes = _bracket(12).where((s) => s.isBye).toList();
      expect(byes.length, 4);
      expect(
        byes.map((s) => s.winner!.seed).toList()..sort(),
        [1, 2, 3, 4],
      );
    });

    test('byes never fall outside round one, for any field size', () {
      for (var n = 2; n <= 16; n++) {
        final slots = generateBracket(_entrants(n), organizerId: _organizerId);
        expect(
          slots.where((s) => s.isBye).every((s) => s.round == 1),
          isTrue,
          reason: '$n entrants produced a bye after round one',
        );
      }
    });

    test('the number of matches actually played is always one less than the '
        'field', () {
      for (var n = 2; n <= 16; n++) {
        final slots = generateBracket(_entrants(n), organizerId: _organizerId);
        final played = slots.where((s) => !s.isBye).length;
        expect(played, n - 1, reason: 'wrong match count for $n entrants');
      }
    });

    test('every team enters the bracket exactly once', () {
      for (var n = 2; n <= 16; n++) {
        final slots = generateBracket(_entrants(n), organizerId: _organizerId);
        final seeded = slots
            .where((s) => s.round == 1)
            .expand((s) => [s.entrantA, s.entrantB])
            .whereType<SlotEntrant>()
            .map((e) => e.coachId)
            .toList();
        expect(seeded.toSet().length, n, reason: 'duplicate or missing at $n');
      }
    });
  });

  group('generateBracket — guards', () {
    test('refuses a field too small to have a bracket', () {
      expect(() => generateBracket(_entrants(1), organizerId: _organizerId),
          throwsArgumentError);
      expect(() => generateBracket(const [], organizerId: _organizerId),
          throwsArgumentError);
    });
  });

  group('BracketSlot', () {
    test('resolves its winner from the recorded coach id', () {
      final slot = _bracket(8).firstWhere((s) => s.id == 'r1m1');
      expect(slot.winner, isNull);

      final decided = BracketSlot(
        id: slot.id,
        organizerId: _organizerId,
        round: slot.round,
        slot: slot.slot,
        entrantA: slot.entrantA,
        entrantB: slot.entrantB,
        nextSlotId: slot.nextSlotId,
        nextSlotSide: slot.nextSlotSide,
        status: BracketSlot.statusCompleted,
        winnerCoachId: 'coach8',
      );
      expect(decided.winner?.seed, 8);
      expect(decided.isDecided, isTrue);
    });

    test('survives a round trip through Firestore-shaped maps', () {
      final original = _bracket(6).firstWhere((s) => s.id == 'r1m2');
      final restored = BracketSlot.fromMap(original.id, original.toMap());

      expect(restored.organizerId, original.organizerId);
      expect(restored.round, original.round);
      expect(restored.slot, original.slot);
      expect(restored.entrantA?.coachId, original.entrantA?.coachId);
      expect(restored.entrantB?.teamName, original.entrantB?.teamName);
      expect(restored.nextSlotId, original.nextSlotId);
      expect(restored.nextSlotSide, original.nextSlotSide);
      expect(restored.status, original.status);
    });
  });
}
