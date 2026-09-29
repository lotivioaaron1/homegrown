// lib/utils/bracket_view.dart
//
// What the bracket screen shows: the round being played, the rounds already
// finished, and the ones that haven't started. Pure, like bracket.dart, so it
// can be tested without Firebase or widgets.

import '../models/bracket_slot.dart';
import 'bracket.dart';

/// Where a round stands, which decides how its step looks and whether it can
/// be opened.
enum RoundStage {
  /// Every game in it has a result.
  done,

  /// The earliest round still being played.
  current,

  /// A later round that already has a team in it, so it can be looked at,
  /// and a matchup with both teams scheduled, before the current round ends.
  open,

  /// No team has reached it yet. Shown only as a step, never as cards.
  locked,
}

/// One round's step on the stepper.
class RoundSummary {
  final int round;

  /// Singular, e.g. "Semifinal", for sentences about one game.
  final String label;

  /// Plural, e.g. "Semifinals", for the stepper and headings.
  final String title;
  final RoundStage stage;

  /// Games with a result, and games to play. Byes are decided when the
  /// bracket is made, so they count as neither.
  final int played;
  final int total;

  /// Every matchup in the round, byes included: the number of teams that
  /// come out of it.
  final int size;

  /// Whether the round also holds the battle for third (only ever the final
  /// round).
  final bool hasThirdPlace;

  const RoundSummary({
    required this.round,
    required this.label,
    required this.title,
    required this.stage,
    required this.played,
    required this.total,
    required this.size,
    this.hasThirdPlace = false,
  });
}

/// The plural name of a round: Quarterfinals, Semifinals, Final, Round of 16.
String roundTitle(int round, int roundCount) {
  final label = roundLabel(round, roundCount);
  if (label == 'Final' || label.startsWith('Round of')) return label;
  return '${label}s';
}

/// A summary per round, first to last.
List<RoundSummary> roundSummaries(List<BracketSlot> slots, int roundCount) {
  final summaries = <RoundSummary>[];
  var currentFound = false;

  for (var round = 1; round <= roundCount; round++) {
    final inRound = slots.where((s) => s.round == round).toList();
    final games = inRound.where((s) => !s.isBye).toList();
    final played = games.where((s) => s.isDecided).length;
    final hasTeam =
        inRound.any((s) => s.entrantA != null || s.entrantB != null);

    final RoundStage stage;
    if (played == games.length) {
      stage = RoundStage.done;
    } else if (!currentFound) {
      stage = RoundStage.current;
      currentFound = true;
    } else {
      stage = hasTeam ? RoundStage.open : RoundStage.locked;
    }

    summaries.add(RoundSummary(
      round: round,
      label: roundLabel(round, roundCount),
      title: roundTitle(round, roundCount),
      stage: stage,
      played: played,
      total: games.length,
      size: inRound.length,
      hasThirdPlace: inRound.any((s) => s.isThirdPlace),
    ));
  }
  return summaries;
}

/// The round the screen opens on: the one being played, or the final once
/// the tournament is over.
int initialRound(List<RoundSummary> summaries) {
  for (final s in summaries) {
    if (s.stage == RoundStage.current) return s.round;
  }
  return summaries.isEmpty ? 1 : summaries.last.round;
}

/// "Winner of Match 3" for the empty [side] of [slot], naming the matchup
/// whose winner will fill it, or "Loser of Match 1" on the battle for third;
/// null if nothing feeds that side.
String? feederLabel(BracketSlot slot, String side, List<BracketSlot> slots) {
  if (slot.isThirdPlace) {
    for (final s in slots) {
      if (s.round == slot.round - 1 &&
          !s.isThirdPlace &&
          s.nextSlotSide == side) {
        return 'Loser of Match ${s.slot}';
      }
    }
    return null;
  }
  for (final s in slots) {
    if (s.nextSlotId == slot.id && s.nextSlotSide == side) {
      return 'Winner of Match ${s.slot}';
    }
  }
  return null;
}

/// The line under the round being shown, naming the next round that hasn't
/// started and what it's waiting on. Null when no round is still locked.
String? upNextNote(List<RoundSummary> summaries) {
  final i = summaries.indexWhere((s) => s.stage == RoundStage.locked);
  if (i < 1) return null;
  final next = summaries[i];
  final before = summaries[i - 1];

  // "Round of 16" doesn't take a plural, so it's counted in games.
  final games = before.title.startsWith('Round of')
      ? '${before.title} games'
      : before.title;
  final which = switch (before.total) {
    1 => 'the ${before.label} is',
    2 => 'both $games are',
    _ => 'all ${before.total} $games are',
  };
  final third = next.hasThirdPlace ? ' The 2 losers play for third.' : '';
  return 'Up next: ${next.title}. '
      'The ${before.size} winners meet once $which played.$third';
}
