// lib/utils/tournament_notices.dart

import 'package:intl/intl.dart';

import 'bracket.dart';

/// One notification's wording.
class Notice {
  final String title;
  final String body;
  const Notice(this.title, this.body);
}

/// What each side of a recorded bracket game is told.
class ResultNotices {
  final Notice winner;
  final Notice loser;
  const ResultNotices({required this.winner, required this.loser});
}

/// The wording sent to both teams when a bracket game in [round] (1-based, of
/// [roundCount]) is recorded. Each side reads the scoreline from its own point
/// of view, and every win is congratulated. Titles never put "is" or "are"
/// after a team name, so any name reads correctly.
ResultNotices resultNotices({
  required String tournamentName,
  required int round,
  required int roundCount,
  required String winnerTeam,
  required String loserTeam,
  required int winnerScore,
  required int loserScore,
}) {
  final won = '$winnerScore–$loserScore';
  final lost = '$loserScore–$winnerScore';

  if (round >= roundCount) {
    return ResultNotices(
      winner: Notice('Congratulations, champions of $tournamentName!',
          '$winnerTeam won the final $won against $loserTeam.'),
      loser: Notice('Runner-up in $tournamentName',
          '$loserTeam lost the final $lost to $winnerTeam.'),
    );
  }

  final thisRound = roundLabel(round, roundCount);
  return ResultNotices(
    winner: Notice(
        "Congratulations! You're in the ${roundLabel(round + 1, roundCount)}",
        '$winnerTeam beat $loserTeam $won in the $thisRound of $tournamentName.'),
    loser: Notice('Eliminated from $tournamentName',
        '$loserTeam lost $lost to $winnerTeam in the $thisRound.'),
  );
}

/// What a team is told when the organizer sets its matchup's kickoff: the
/// round, its own opponent (its own name first), when, and where.
Notice scheduledNotice({
  required int round,
  required int roundCount,
  required String team,
  required String opponent,
  required DateTime kickoff,
  required String venue,
}) {
  final when = DateFormat('EEE, MMM d · h:mm a').format(kickoff);
  final where = venue.trim().isEmpty ? '' : ' at ${venue.trim()}';
  return Notice('${roundLabel(round, roundCount)} scheduled',
      '$team vs $opponent · $when$where');
}

/// Everyone on a team who hears about its result: the coach and every player,
/// once each, skipping blank ids.
List<String> teamRecipients(String coachId, Iterable<String> playerUids) =>
    {coachId, ...playerUids}.where((uid) => uid.isNotEmpty).toList();
