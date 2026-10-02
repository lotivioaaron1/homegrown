// lib/widgets/standings_table.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/team_name.dart';
import '../utils/team_standings.dart';

// Fixed widths for the number columns, shared by the header and every row so
// they line up. Sized so the table fits a 320dp phone with no sideways
// scroll; the team name takes whatever is left and ellipsizes.
const double _kRankW = 22;
const double _kWinW = 24;
const double _kLossW = 24;
const double _kPctW = 40;
const double _kDiffW = 36;

/// The standings card: a header row and one row per team, as the Standings
/// screen lays it out. Separate from the screen so it can be rendered in a
/// test without Firebase.
class StandingsTable extends StatelessWidget {
  /// Best first, from [computeStandings].
  final List<TeamStanding> table;

  /// From [standingRanks], one per entry in [table].
  final List<int> ranks;

  /// Each coach's live `users` doc, for the team's current name and logo.
  /// A coach missing here falls back to the name the team last played under.
  final Map<String, Map<String, dynamic>> coaches;

  /// Coach ids whose rows are the viewer's own team.
  final Set<String> myTeams;

  /// A row was tapped: the coach, their doc if loaded, and the name shown.
  final void Function(String coachId, Map<String, dynamic>? coach, String name)
      onOpen;

  const StandingsTable({
    super.key,
    required this.table,
    required this.ranks,
    required this.coaches,
    required this.myTeams,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Clipped so a row's ink ripple stops at the rounded corners.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        _buildHeader(),
        for (var i = 0; i < table.length; i++)
          _buildRow(
            standing: table[i],
            rank: ranks[i],
            coach: coaches[table[i].coachId],
            isLast: i == table.length - 1,
          ),
      ]),
    );
  }

  Widget _buildHeader() {
    Widget label(String text, double width) => SizedBox(
          width: width,
          child: Text(text, textAlign: TextAlign.right, style: _headerStyle),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        SizedBox(width: _kRankW, child: Text('#', style: _headerStyle)),
        const SizedBox(width: 6),
        Expanded(child: Text('TEAM', style: _headerStyle)),
        label('W', _kWinW),
        label('L', _kLossW),
        label('PCT', _kPctW),
        label('+/-', _kDiffW),
      ]),
    );
  }

  TextStyle get _headerStyle => TextStyle(
      color: AppTheme.muted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1);

  Widget _buildRow({
    required TeamStanding standing,
    required int rank,
    required Map<String, dynamic>? coach,
    required bool isLast,
  }) {
    final name =
        liveTeamName(coachProfile: coach, storedTeamName: standing.storedName);
    final logoUrl = coach?['teamLogoUrl'] as String?;
    final isMine = myTeams.contains(standing.coachId);
    final diff = standing.diff;
    final diffText = diff > 0
        ? '+$diff'
        : diff < 0
            ? '−${-diff}'
            : '0';
    final pct = formatPct(standing.winPct);

    final initials = Center(
        child: Text(_initials(name),
            style: TextStyle(
                color: isMine ? AppTheme.buttonFg : AppTheme.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800)));

    Widget number(String text, double width,
            {Color? color, bool bold = false}) =>
        SizedBox(
          width: width,
          // One line, always: a number too wide for its column (a four-digit
          // +/-) clips a pixel rather than breaking the row onto two lines.
          child: Text(text,
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                  color: color ?? AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        );

    void open() => onOpen(standing.coachId, coach, name);

    // One spoken summary per row instead of six loose numbers. Excluding the
    // children drops the InkWell's tap action too, so it's given back here.
    return Semantics(
      button: true,
      excludeSemantics: true,
      onTap: open,
      label: 'Rank $rank, $name${isMine ? ', your team' : ''}, '
          '${standing.wins} wins, ${standing.losses} losses, '
          'win percentage $pct, point difference $diffText',
      child: Material(
        color: isMine
            ? AppTheme.accentSurface.withValues(alpha: 0.5)
            : Colors.transparent,
        // The divider rides on the Material so the ink covers the whole row.
        shape:
            isLast ? null : Border(bottom: BorderSide(color: AppTheme.border)),
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              SizedBox(
                width: _kRankW,
                child: Text('$rank',
                    style: TextStyle(
                        color: isMine ? AppTheme.accent : AppTheme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              const SizedBox(width: 6),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isMine
                            ? [AppTheme.accent, AppTheme.accent2]
                            : [AppTheme.cardNested, AppTheme.cardNested]),
                    borderRadius: BorderRadius.circular(9),
                    border: isMine
                        ? Border.all(color: AppTheme.accent, width: 1.5)
                        : null),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: logoUrl != null && logoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: logoUrl,
                          fit: BoxFit.cover,
                          width: 32,
                          height: 32,
                          memCacheWidth: 100,
                          placeholder: (_, __) => initials,
                          errorWidget: (_, __, ___) => initials)
                      : initials,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: isMine
                                  ? AppTheme.accentText
                                  : AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      if (isMine) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('YOUR TEAM',
                              style: TextStyle(
                                  color: AppTheme.buttonFg,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ]),
              ),
              number('${standing.wins}', _kWinW, bold: true),
              number('${standing.losses}', _kLossW),
              number(pct, _kPctW, color: AppTheme.sub),
              // The sign carries the meaning; the colour only reinforces it.
              number(diffText, _kDiffW,
                  color: diff > 0
                      ? AppTheme.successText
                      : diff < 0
                          ? AppTheme.errorText
                          : AppTheme.muted),
            ]),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }
}
