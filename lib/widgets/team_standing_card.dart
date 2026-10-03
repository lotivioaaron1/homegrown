// lib/widgets/team_standing_card.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/standings_service.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../utils/sports.dart';
import '../utils/team_standings.dart';
import 'skeleton.dart';

/// One sport's line on the card.
class TeamStandingLine {
  final String sport;
  final int season;

  /// Null when the team has no official game in [sport] this season.
  final ({TeamStanding standing, int rank, bool tied})? place;

  /// How many teams are in the table.
  final int teams;

  const TeamStandingLine({
    required this.sport,
    required this.season,
    required this.place,
    required this.teams,
  });
}

/// Where a coach's team sits this season, on the team screens (the coach's
/// My Team and an athlete's view of their team). Tapping a line opens that
/// sport's full table, which highlights the viewer's team.
///
/// Loads itself, like TeamTitlesRow. Shows a placeholder while loading and
/// nothing at all if loading fails: the standing is extra, and must never get
/// in the way of the roster below it.
class TeamStandingCard extends StatefulWidget {
  final String coachId;

  /// Space around the card, applied only when there is a card to show.
  final EdgeInsets padding;

  /// Whether a team with no official game this season still gets its
  /// "No official games yet" line. The team screens keep it, as their way
  /// into the standings; Home drops it rather than add another empty state.
  final bool showUnplayed;

  const TeamStandingCard({
    super.key,
    required this.coachId,
    this.padding = const EdgeInsets.only(top: 12),
    this.showUnplayed = true,
  });

  @override
  State<TeamStandingCard> createState() => _TeamStandingCardState();
}

class _TeamStandingCardState extends State<TeamStandingCard> {
  // Held so a rebuild of the screen around it doesn't refetch.
  late final Future<List<TeamStandingLine>> _lines = _load();

  Future<List<TeamStandingLine>> _load() async {
    final coach =
        (await TeamService.fetchMemberProfiles([widget.coachId]))[widget.coachId];
    final season = seasonOf(DateTime.now());
    final lines = await Future.wait(sportsOf(coach).map((sport) async {
      final table = computeStandings(
          await StandingsService.fetchSeasonGames(sport, season));
      return TeamStandingLine(
        sport: sport,
        season: season,
        place: placeOf(table, standingRanks(table), widget.coachId),
        teams: table.length,
      );
    }));
    return linesToShow(lines);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TeamStandingLine>>(
      future: _lines,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: widget.padding,
            // The card's own height (14 + 42 + 14), so nothing below it
            // moves when it arrives.
            child: const Shimmer(
              child: SkeletonBox(height: 70, radius: 16),
            ),
          );
        }
        final lines = snapshot.data ?? const [];
        if (snapshot.hasError || lines.isEmpty) return const SizedBox.shrink();
        // linesToShow only keeps an unplayed line when nothing was played.
        if (!widget.showUnplayed && lines.every((l) => l.place == null)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: widget.padding,
          child: TeamStandingView(
            lines: lines,
            onOpen: (sport) => Get.toNamed('/standings', arguments: sport),
          ),
        );
      },
    );
  }
}

/// The lines worth showing from one per sport the coach coaches: the sports
/// the team has played this season. When it has played none, the first
/// sport's empty line alone, so the card still points at the standings.
List<TeamStandingLine> linesToShow(List<TeamStandingLine> perSport) {
  final played = perSport.where((l) => l.place != null).toList();
  if (played.isNotEmpty) return played;
  return perSport.isEmpty ? const [] : [perSport.first];
}

/// The card itself, separate from the loading so it can be rendered in a
/// test without Firebase.
class TeamStandingView extends StatelessWidget {
  final List<TeamStandingLine> lines;
  final void Function(String sport) onOpen;

  const TeamStandingView({
    super.key,
    required this.lines,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.border)),
      child: Column(children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: AppTheme.border),
          _buildLine(lines[i]),
        ],
      ]),
    );
  }

  Widget _buildLine(TeamStandingLine line) {
    final place = line.place;
    final title = place == null
        ? 'No official games yet'
        : placeLabel(place.rank, line.teams, tied: place.tied);
    final subtitle = place == null
        ? '${line.sport} ${line.season} · See standings'
        : '${line.sport} ${line.season} · ${recordLabel(place.standing)}';

    return InkWell(
      onTap: () => onOpen(line.sport),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent)),
            child: Icon(Icons.leaderboard_rounded,
                color: AppTheme.accentText, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: place == null
                              ? AppTheme.sub
                              : AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  // Two lines allowed: on a 320dp phone the record can't
                  // share one line with the sport and season.
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                ]),
          ),
          Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
        ]),
      ),
    );
  }
}
