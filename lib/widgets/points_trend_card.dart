// lib/widgets/points_trend_card.dart

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../utils/stats_view.dart';

/// How many games the line plots. A line holds far more points than the
/// bars it replaced did (six, each with a two-line label), and ten still
/// leaves a comfortable touch target per game on a small phone.
const int kTrendWindow = 10;

/// The athlete's Homegrown points over their recent games, on the
/// performance dashboard: the latest game as a headline with how it compares
/// to their average before it, over a line of the last [kTrendWindow] games.
///
/// Touching the line puts the game under the finger into the headline
/// instead of a floating tooltip: in a chart this short, a tooltip big enough
/// for an event name like "asd — Quarterfinal: Bitano Bulls vs Team Test"
/// covered the very point being read.
///
/// [games] is the dashboard's list as it stands after the sport filter —
/// `stats` documents decoded to maps, newest first.
class PointsTrendCard extends StatefulWidget {
  final List<Map<String, dynamic>> games;

  const PointsTrendCard({super.key, required this.games});

  @override
  State<PointsTrendCard> createState() => _PointsTrendCardState();
}

class _PointsTrendCardState extends State<PointsTrendCard> {
  /// Index into the plotted games of the one being touched, if any.
  int? _touched;

  void _onTouch(int? index) {
    if (index == _touched) return;
    if (index != null) HapticFeedback.selectionClick();
    setState(() => _touched = index);
  }

  @override
  Widget build(BuildContext context) {
    final games = widget.games;
    if (games.isEmpty) return const SizedBox.shrink();
    final trend = lastGameTrend(games);
    final shown = chartGames(games, count: kTrendWindow);
    // The sport filter can shrink the window while a finger is still down.
    final touched = _touched != null && _touched! < shown.length
        ? shown[_touched!]
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        touched != null
            ? _TouchedHeader(game: touched)
            : _Header(latest: gamePoints(games.first), trend: trend),
        if (shown.length < 2)
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text('Your trend line appears after your next game.',
                style: TextStyle(color: AppTheme.sub, fontSize: 12)),
          )
        else ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: _TrendLine(
                shown: shown,
                totalGames: games.length,
                best: bestGame(games),
                onTouch: _onTouch),
          ),
          // The axis numbers start past G1 once the window slides, which on
          // its own reads like missing data.
          if (games.length > shown.length) ...[
            const SizedBox(height: 6),
            Text('Your last ${shown.length} of ${games.length} games',
                style: TextStyle(color: AppTheme.muted, fontSize: 11)),
          ],
        ],
      ]),
    );
  }
}

/// The big number and its caption, shared by both headers so swapping one
/// for the other never changes the card's height and nudges the chart under
/// the athlete's finger.
class _Headline extends StatelessWidget {
  final int points;
  final String caption;

  const _Headline({required this.points, required this.caption});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$points',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1)),
        const SizedBox(height: 6),
        Text(caption,
            style: TextStyle(
                color: AppTheme.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      ]);
}

class _Header extends StatelessWidget {
  final int latest;
  final LastGameTrend? trend;

  const _Header({required this.latest, required this.trend});

  @override
  Widget build(BuildContext context) {
    final percent = trend?.percent;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _Headline(points: latest, caption: 'PTS · LAST GAME')),
      if (percent != null)
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _TrendPill(percent: percent),
          const SizedBox(height: 6),
          Text('vs your avg of ${trend!.previousAvg}',
              style: TextStyle(color: AppTheme.sub, fontSize: 11)),
        ]),
    ]);
  }
}

/// The headline while a finger is on the line: that game's points and date,
/// with the event name where the trend pill sits.
class _TouchedHeader extends StatelessWidget {
  final Map<String, dynamic> game;

  const _TouchedHeader({required this.game});

  @override
  Widget build(BuildContext context) {
    final ts = game['createdAt'];
    final date = ts is Timestamp
        ? DateFormat('MMM d').format(ts.toDate()).toUpperCase()
        : '';
    final name = (game['eventName'] as String? ?? '').trim();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Headline(
          points: gamePoints(game),
          caption: date.isEmpty ? 'PTS' : 'PTS · $date'),
      const SizedBox(width: 16),
      Expanded(
        child: Text(name,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35)),
      ),
    ]);
  }
}

/// Up, down or level, always with an arrow so the colour is never the only
/// thing saying which.
class _TrendPill extends StatelessWidget {
  final int percent;

  const _TrendPill({required this.percent});

  @override
  Widget build(BuildContext context) {
    final up = percent > 0;
    final level = percent == 0;
    final fg = level
        ? AppTheme.sub
        : up
            ? AppTheme.successText
            : AppTheme.errorText;
    final bg = level
        ? AppTheme.cardNested
        : up
            ? AppTheme.successSurface
            : AppTheme.errorSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            level
                ? LucideIcons.minus
                : up
                    ? LucideIcons.trendingUp
                    : LucideIcons.trendingDown,
            color: fg,
            size: 13),
        const SizedBox(width: 4),
        Text(level ? 'On par' : '${percent.abs()}%',
            style: TextStyle(
                color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _TrendLine extends StatelessWidget {
  /// The plotted games, oldest first.
  final List<Map<String, dynamic>> shown;

  /// Every game in scope, so the axis can number the plotted ones as the
  /// athlete's 16th to 25th game rather than restarting at 1.
  final int totalGames;

  /// Highlighted on the line when it falls inside the window.
  final Map<String, dynamic>? best;

  /// The index into [shown] under the athlete's finger, or null on release.
  final ValueChanged<int?> onTouch;

  const _TrendLine({
    required this.shown,
    required this.totalGames,
    required this.best,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    final last = shown.length - 1;
    final bestIndex = shown.indexWhere((g) => identical(g, best));
    final peak = shown.map(gamePoints).reduce(math.max);
    final yStep = _niceStep(math.max(peak * 1.15, 10) / 3);
    final maxY = (math.max(peak * 1.15, 10) / yStep).ceil() * yStep;
    final line = AppTheme.accentText;

    String gameLabel(int i) => 'G${totalGames - last + i}';

    return LineChart(
      LineChartData(
        // Half a game of room either side, so the end dots and the first
        // and last axis labels aren't cut by the edge of the plot.
        minX: -0.4,
        maxX: last + 0.4,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yStep,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppTheme.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: yStep,
              getTitlesWidget: (value, meta) {
                if (value % yStep != 0) return const SizedBox.shrink();
                return Text('${value.toInt()}',
                    style: TextStyle(color: AppTheme.muted, fontSize: 10));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                // The padded ends land on fractions; only whole games label.
                if (value != value.roundToDouble()) {
                  return const SizedBox.shrink();
                }
                final i = value.toInt();
                if (i < 0 || i > last) return const SizedBox.shrink();
                // Past six games every other label, counted back from the
                // newest so the latest game is always named.
                if (shown.length > 6 && (last - i).isOdd) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(gameLabel(i),
                      style: TextStyle(
                          color: AppTheme.sub,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i <= last; i++)
                FlSpot(i.toDouble(), gamePoints(shown[i]).toDouble()),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            // A curve between a big game and a tune-up's zero would
            // otherwise swing below the axis.
            preventCurveOverShooting: true,
            barWidth: 2.5,
            isStrokeCapRound: true,
            color: line,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.accent.withValues(alpha: 0.25),
                  AppTheme.accent.withValues(alpha: 0),
                ],
              ),
            ),
            dotData: FlDotData(
              getDotPainter: (spot, _, __, i) {
                // The newest game is solid; the best one is a ring, so it
                // reads as marked rather than as another data point.
                if (i == last) {
                  return FlDotCirclePainter(
                      radius: 5,
                      color: line,
                      strokeWidth: 2,
                      strokeColor: AppTheme.card);
                }
                if (i == bestIndex) {
                  return FlDotCirclePainter(
                      radius: 5,
                      color: AppTheme.card,
                      strokeWidth: 2.5,
                      strokeColor: line);
                }
                return FlDotCirclePainter(
                    radius: 3,
                    color: line,
                    strokeWidth: 1.5,
                    strokeColor: AppTheme.card);
              },
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          // Nearest game within a finger's width, not a pinpoint on the dot.
          touchSpotThreshold: 24,
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: AppTheme.border, strokeWidth: 1.5),
                FlDotData(
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 6,
                      color: line,
                      strokeWidth: 2,
                      strokeColor: AppTheme.card),
                ),
              ),
          ],
          // The card's headline shows the touched game, so no tooltip box:
          // fl_chart draws nothing when every item is null.
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [for (final _ in spots) null],
          ),
          touchCallback: (event, response) {
            final spots = response?.lineBarSpots;
            onTouch(event.isInterestedForInteractions &&
                    spots != null &&
                    spots.isNotEmpty
                ? spots.first.spotIndex
                : null);
          },
        ),
      ),
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
}

/// A gridline step of 1, 2 or 5 times a power of ten, so the axis reads
/// 0 / 50 / 100 rather than 0 / 40.25 / 80.5.
double _niceStep(double raw) {
  final magnitude =
      math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final n = raw / magnitude;
  final step = n <= 1
      ? 1
      : n <= 2
          ? 2
          : n <= 5
              ? 5
              : 10;
  return step * magnitude;
}
