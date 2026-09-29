// test/utils/third_place_test.dart
//
// The battle for third place: who fills it, what it's called, and what each
// side is told.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/models/bracket_slot.dart';
import 'package:homegrown/models/tournament.dart';
import 'package:homegrown/utils/bracket.dart';
import 'package:homegrown/utils/bracket_view.dart';
import 'package:homegrown/utils/tournament_notices.dart';

List<BracketSlot> _bracket(int n) {
  final slots = generateBracket(
    List.generate(
      n,
      (i) => TournamentEntrant(
        seed: i + 1,
        coachId: 'coach${i + 1}',
        teamName: 'Team ${i + 1}',
        players: [EntrantPlayer(uid: 'p${i + 1}', fullName: 'P${i + 1}')],
      ),
    ),
    organizerId: 'org',
  );
  return [
    ...slots,
    thirdPlaceSlotFor(slots, roundCountFor(n), organizerId: 'org'),
  ];
}

/// Records [slotId] as won by side A and moves the winner on, as
/// TournamentService.stageAdvance does (the loser is placed separately, by
/// rebuilding the third-place slot).
List<BracketSlot> _play(List<BracketSlot> slots, String slotId) {
  final played = slots.firstWhere((s) => s.id == slotId);
  final winner = played.entrantA!;
  return slots.map((s) {
    if (s.id == slotId) {
      return BracketSlot(
        id: s.id,
        organizerId: s.organizerId,
        round: s.round,
        slot: s.slot,
        isThirdPlace: s.isThirdPlace,
        entrantA: s.entrantA,
        entrantB: s.entrantB,
        nextSlotId: s.nextSlotId,
        nextSlotSide: s.nextSlotSide,
        status: BracketSlot.statusCompleted,
        winnerCoachId: winner.coachId,
      );
    }
    if (s.id == played.nextSlotId) {
      final a = played.nextSlotSide == 'A' ? winner : s.entrantA;
      final b = played.nextSlotSide == 'B' ? winner : s.entrantB;
      return BracketSlot(
        id: s.id,
        organizerId: s.organizerId,
        round: s.round,
        slot: s.slot,
        entrantA: a,
        entrantB: b,
        nextSlotId: s.nextSlotId,
        nextSlotSide: s.nextSlotSide,
        status: a != null && b != null
            ? BracketSlot.statusReady
            : BracketSlot.statusAwaiting,
      );
    }
    return s;
  }).toList();
}

BracketSlot _third(List<BracketSlot> slots, int roundCount) =>
    thirdPlaceSlotFor(slots.where((s) => !s.isThirdPlace).toList(), roundCount,
        organizerId: 'org');

void main() {
  group('thirdPlaceSlotFor', () {
    test('sits in the final round as slot 2, empty at the start', () {
      final third = _bracket(8).last;

      expect(third.id, 'r3m2');
      expect(third.round, 3);
      expect(third.isThirdPlace, isTrue);
      expect(third.isFinal, isFalse);
      expect(third.nextSlotId, isNull);
      expect(third.entrantA, isNull);
      expect(third.entrantB, isNull);
      expect(third.status, BracketSlot.statusAwaiting);
    });

    test('takes the loser of each semifinal on that semifinal\'s side', () {
      var slots = _bracket(8);
      slots = ['r1m1', 'r1m2', 'r1m3', 'r1m4', 'r2m1'].fold(slots, _play);
      final afterOne = _third(slots, 3);

      // Semifinal 1 was seed 1 against seed 4; seed 1 won.
      expect(afterOne.entrantA?.seed, 4);
      expect(afterOne.entrantB, isNull);
      expect(afterOne.status, BracketSlot.statusAwaiting);

      final afterBoth = _third(_play(slots, 'r2m2'), 3);
      expect(afterBoth.entrantB?.seed, 3);
      expect(afterBoth.status, BracketSlot.statusReady);
    });

    // Four teams: the semifinals are the opening round.
    test('works when the semifinals are round 1', () {
      final slots = ['r1m1', 'r1m2'].fold(_bracket(4), _play);
      final third = _third(slots, 2);

      expect(third.id, 'r2m2');
      expect(third.entrantA?.seed, 4);
      expect(third.entrantB?.seed, 3);
      expect(third.status, BracketSlot.statusReady);
    });

    test('survives a round trip through Firestore', () {
      final third = _bracket(8).last;
      final back = BracketSlot.fromMap(third.id, third.toMap());

      expect(back.isThirdPlace, isTrue);
      expect(BracketSlot.fromMap('r1m1', _bracket(8).first.toMap()).isThirdPlace,
          isFalse);
    });
  });

  group('slotLabel', () {
    test('names the battle for third, and every other slot by its round', () {
      final slots = _bracket(8);

      expect(slotLabel(slots.last, 3), 'Battle for third');
      expect(slotLabel(slots.firstWhere((s) => s.id == 'r3m1'), 3), 'Final');
      expect(slotLabel(slots.first, 3), 'Quarterfinal');
    });
  });

  group('bracket view with a battle for third', () {
    test('says whose loss fills each side', () {
      final slots = _bracket(8);
      final third = slots.last;

      expect(feederLabel(third, 'A', slots), 'Loser of Match 1');
      expect(feederLabel(third, 'B', slots), 'Loser of Match 2');
    });

    test('marks the final round as holding it', () {
      final summaries = roundSummaries(_bracket(8), 3);

      expect(summaries.last.hasThirdPlace, isTrue);
      expect(summaries.first.hasThirdPlace, isFalse);
    });

    test('counts it among the final round\'s games', () {
      final summaries = roundSummaries(_bracket(8), 3);

      expect(summaries.last.total, 2);
    });

    test('mentions it in the up-next line', () {
      final slots =
          ['r1m1', 'r1m2', 'r1m3', 'r1m4'].fold(_bracket(8), _play);

      expect(upNextNote(roundSummaries(slots, 3)),
          'Up next: Final. The 2 winners meet once both Semifinals are '
          'played. The 2 losers play for third.');
    });
  });

  group('notices', () {
    test('tells a semifinal loser they play for third', () {
      final n = resultNotices(
        tournamentName: 'Mayon Cup',
        round: 2,
        roundCount: 3,
        winnerTeam: 'Rawis Rockets',
        loserTeam: 'Bitano Bulls',
        winnerScore: 84,
        loserScore: 70,
        thirdPlaceNext: true,
      ).loser;

      expect(n.title, 'Battle for third next');
      expect(n.body,
          "Bitano Bulls lost 70–84 to Rawis Rockets in the Semifinal. "
          "You'll play for third place.");
    });

    test('still eliminates a semifinal loser when there is no battle', () {
      final n = resultNotices(
        tournamentName: 'Mayon Cup',
        round: 2,
        roundCount: 3,
        winnerTeam: 'Rawis Rockets',
        loserTeam: 'Bitano Bulls',
        winnerScore: 84,
        loserScore: 70,
      ).loser;

      expect(n.title, 'Eliminated from Mayon Cup');
    });

    test('congratulates the 2nd runner-up and names the 3rd', () {
      final n = thirdPlaceNotices(
        tournamentName: 'Mayon Cup',
        winnerTeam: 'Bitano Bulls',
        loserTeam: 'Taysan Titans',
        winnerScore: 60,
        loserScore: 55,
      );

      expect(n.winner.title, 'Congratulations, 2nd runner-up in Mayon Cup!');
      expect(n.winner.body,
          'Bitano Bulls won the battle for third 60–55 against Taysan Titans.');
      expect(n.loser.title, '3rd runner-up in Mayon Cup');
      expect(n.loser.body,
          'Taysan Titans lost the battle for third 55–60 to Bitano Bulls.');
      // Not mistaken for the champion's notice by the bell.
      expect(isChampionNotice(n.winner.title), isFalse);
    });

    test('names the battle for third when it is scheduled', () {
      final n = scheduledNotice(
        round: 3,
        roundCount: 3,
        stage: 'Battle for third',
        team: 'Bitano Bulls',
        opponent: 'Taysan Titans',
        kickoff: DateTime(2026, 9, 29, 17, 30),
        venue: '',
      );

      expect(n.title, 'Battle for third scheduled');
    });
  });
}
