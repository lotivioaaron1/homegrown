// test/utils/bracket_view_test.dart
//
// How the bracket screen decides which rounds to show: the round being
// played, the rounds already finished, and the ones not started yet.

import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/models/bracket_slot.dart';
import 'package:homegrown/models/tournament.dart';
import 'package:homegrown/utils/bracket.dart';
import 'package:homegrown/utils/bracket_view.dart';

List<BracketSlot> _bracket(int n) => generateBracket(
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

/// Records [slotId] as won by side A and moves the winner on, the way
/// TournamentService.stageAdvance does.
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
        entrantA: s.entrantA,
        entrantB: s.entrantB,
        nextSlotId: s.nextSlotId,
        nextSlotSide: s.nextSlotSide,
        status: BracketSlot.statusCompleted,
        scoreA: 70,
        scoreB: 60,
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

List<BracketSlot> _playAll(List<BracketSlot> slots, List<String> ids) =>
    ids.fold(slots, _play);

List<RoundStage> _stages(List<BracketSlot> slots, int roundCount) =>
    roundSummaries(slots, roundCount).map((r) => r.stage).toList();

void main() {
  group('roundSummaries', () {
    test('a fresh bracket is playing its first round, the rest locked', () {
      expect(_stages(_bracket(8), 3),
          [RoundStage.current, RoundStage.locked, RoundStage.locked]);
    });

    test('counts matchups played in each round', () {
      final slots = _playAll(_bracket(8), ['r1m1', 'r1m2']);
      final quarters = roundSummaries(slots, 3).first;

      expect(quarters.played, 2);
      expect(quarters.total, 4);
    });

    // A semifinal with a team in it can be looked at (and scheduled once
    // both sides are in) before every quarterfinal is finished.
    test('opens a later round as soon as a team reaches it', () {
      final slots = _play(_bracket(8), 'r1m1');

      expect(_stages(slots, 3),
          [RoundStage.current, RoundStage.open, RoundStage.locked]);
    });

    test('moves on once every matchup in a round is decided', () {
      final slots =
          _playAll(_bracket(8), ['r1m1', 'r1m2', 'r1m3', 'r1m4']);

      expect(_stages(slots, 3),
          [RoundStage.done, RoundStage.current, RoundStage.locked]);
    });

    test('is all done after the final', () {
      final slots = _playAll(_bracket(8),
          ['r1m1', 'r1m2', 'r1m3', 'r1m4', 'r2m1', 'r2m2', 'r3m1']);

      expect(_stages(slots, 3),
          [RoundStage.done, RoundStage.done, RoundStage.done]);
    });

    // Six teams in an eight-team draw: seeds 1 and 2 get byes, which are
    // decided at creation and aren't games to play.
    test('leaves byes out of the counts', () {
      final summaries = roundSummaries(_bracket(6), 3);

      expect(summaries.first.total, 2);
      expect(summaries.first.played, 0);
      expect(summaries[1].stage, RoundStage.open);
    });

    test('titles each round in the plural', () {
      expect(roundSummaries(_bracket(8), 3).map((r) => r.title),
          ['Quarterfinals', 'Semifinals', 'Final']);
    });
  });

  group('roundTitle', () {
    test('pluralises every round but the final', () {
      expect(roundTitle(1, 4), 'Round of 16');
      expect(roundTitle(2, 4), 'Quarterfinals');
      expect(roundTitle(3, 4), 'Semifinals');
      expect(roundTitle(4, 4), 'Final');
    });
  });

  group('initialRound', () {
    test('opens on the round being played', () {
      final slots =
          _playAll(_bracket(8), ['r1m1', 'r1m2', 'r1m3', 'r1m4']);

      expect(initialRound(roundSummaries(slots, 3)), 2);
    });

    test('opens on the final once the tournament is over', () {
      final slots = _playAll(_bracket(8),
          ['r1m1', 'r1m2', 'r1m3', 'r1m4', 'r2m1', 'r2m2', 'r3m1']);

      expect(initialRound(roundSummaries(slots, 3)), 3);
    });
  });

  group('feederLabel', () {
    test('names the matchup whose winner fills an empty side', () {
      final slots = _play(_bracket(8), 'r1m1');
      final semi = slots.firstWhere((s) => s.id == 'r2m1');

      expect(feederLabel(semi, 'B', slots), 'Winner of Match 2');
    });

    test('is null for a side with nothing feeding it', () {
      final slots = _bracket(8);
      final quarter = slots.firstWhere((s) => s.id == 'r1m1');

      expect(feederLabel(quarter, 'A', slots), isNull);
    });
  });

  group('upNextNote', () {
    test('names the next locked round and what unlocks it', () {
      final slots =
          _playAll(_bracket(8), ['r1m1', 'r1m2', 'r1m3', 'r1m4']);

      expect(upNextNote(roundSummaries(slots, 3)),
          'Up next: Final. The 2 winners meet once both Semifinals are played.');
    });

    test('counts the winners of a bigger round', () {
      expect(upNextNote(roundSummaries(_bracket(8), 3)),
          'Up next: Semifinals. The 4 winners meet once all 4 Quarterfinals '
          'are played.');
    });

    test('is null when no round is still locked', () {
      final slots =
          _playAll(_bracket(8), ['r1m1', 'r1m2', 'r1m3', 'r1m4']);
      final all = _playAll(slots, ['r2m1', 'r2m2']);

      expect(upNextNote(roundSummaries(all, 3)), isNull);
    });
  });
}
