// lib/screens/dashboard/performance_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../constants/sport_icons.dart';
import '../../theme/app_theme.dart';
import '../../services/rating_service.dart';
import '../../services/ranking_service.dart';
import '../../utils/leaderboard_ranks.dart';
import '../../utils/stats_view.dart';
import '../../widgets/points_explainer_sheet.dart';

class PerformanceDashboardScreen extends StatefulWidget {
  const PerformanceDashboardScreen({super.key});

  @override
  State<PerformanceDashboardScreen> createState() =>
      _PerformanceDashboardScreenState();
}

class _PerformanceDashboardScreenState
    extends State<PerformanceDashboardScreen> {
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _selectedRatingSport;

  /// The sport the chart and Game History are narrowed to, or null for all.
  /// Only offered to athletes whose games span more than one sport.
  String? _statsSport;

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }

  double _toDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return 0.0;
  }

  // Memoised so pull-to-refresh and rebuilds don't re-issue the rank
  // aggregation. Keyed on points so a new score still refreshes it.
  int? _cityRankPoints;
  Future<int>? _cityRankResult;

  Future<int> _cityRankFuture(int points) {
    if (_cityRankResult == null || _cityRankPoints != points) {
      _cityRankPoints = points;
      _cityRankResult = RankingService.cityRank(points: points);
    }
    return _cityRankResult!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('stats')
                .where('athleteId', isEqualTo: uid)
                .snapshots(),
            builder: (context, statsSnap) {
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users').doc(uid).snapshots(),
                builder: (context, userSnap) {
                  if (statsSnap.connectionState == ConnectionState.waiting ||
                      userSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(
                        color: AppTheme.accent, strokeWidth: 2.5));
                  }
                  final userData = userSnap.data?.data()
                      as Map<String, dynamic>? ?? {};
                  final statsDocs = (statsSnap.data?.docs ?? [])
                      .map((d) => d.data() as Map<String, dynamic>)
                      .toList()
                    ..sort((a, b) {
                      final aT = a['createdAt'] as Timestamp?;
                      final bT = b['createdAt'] as Timestamp?;
                      if (aT == null || bT == null) return 0;
                      return bT.compareTo(aT);
                    });
                  return _buildContent(context, userData, statsDocs);
                },
              );
            },
          )),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border)),
            child: Icon(LucideIcons.chevronLeft,
                color: AppTheme.textPrimary, size: 18)),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('My Dashboard', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 18,
            fontWeight: FontWeight.w800)),
          Text('Performance Overview',
              style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        ]),
        const Spacer(),
        // Every number on this screen is Homegrown points or a match rating,
        // neither of which is self-explanatory.
        GestureDetector(
          onTap: () => showPointsExplainerSheet(context),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border)),
            child: Icon(LucideIcons.info,
                color: AppTheme.textPrimary, size: 18)),
        ),
      ]),
    );
  }

  Widget _buildContent(BuildContext context,
      Map<String, dynamic> userData,
      List<Map<String, dynamic>> stats) {
    if (stats.isEmpty) return _buildEmpty();

    final totalPts = _toInt(userData['points']);
    final gamesPlayed = stats.length;
    final avgPts = gamesPlayed > 0 ? (totalPts / gamesPlayed).round() : 0;

    // Multi-sport athletes get a sport filter over the chart and history;
    // the headline totals above stay all-sport. A filter left pointing at a
    // sport that is no longer in the list falls back to all.
    final sports = sportsPlayed(stats);
    final activeSport = sports.contains(_statsSport) ? _statsSport : null;
    final shown = filterBySport(stats, activeSport);
    final chartStats = chartGames(shown);

    return RefreshIndicator(
      color: AppTheme.accent,
      backgroundColor: AppTheme.card,
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 800));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildHeroRow(totalPts, gamesPlayed, avgPts),
          const SizedBox(height: 16),
          _buildRatingsSection(userData),
          if (sports.length > 1) ...[
            _buildSportFilter(sports, activeSport),
            const SizedBox(height: 14),
          ],
          if (chartStats.isNotEmpty) ...[
            _buildSectionTitle(
                LucideIcons.trendingUp, 'Homegrown Points per Game'),
            const SizedBox(height: 8),
            _buildChart(context, chartStats),
            const SizedBox(height: 16),
          ],
          _buildSectionTitle(LucideIcons.history, 'Game History'),
          const SizedBox(height: 8),
          _buildGameHistory(shown),
        ],
      ),
    );
  }

  // ── Hero row ──────────────────────────────
  // CHANGED: dropped the accent border/tinted-background treatment
  // on "Total Pts" — that styling reads as a selected/toggled state
  // (same pattern used for picked cards elsewhere), which is
  // confusing on a row of 4 static read-only numbers. All 4 tiles
  // now share one neutral card style; the primary metric is still
  // set apart, just by text color instead of a border.

  Widget _buildHeroRow(int totalPts, int games, int avg) {
    return FutureBuilder<int>(
      // Unranked on zero points, so there is nothing to ask Firestore — see
      // cityRankLabel.
      future: totalPts > 0 ? _cityRankFuture(totalPts) : null,
      builder: (context, snap) {
        final rank = cityRankLabel(points: totalPts, rank: snap.data);
        return Row(children: [
          Expanded(child: _HeroCard(
              value: '$totalPts', label: 'Total Pts', isAccentText: true)),
          const SizedBox(width: 8),
          Expanded(child: _HeroCard(value: rank, label: 'City Rank')),
          const SizedBox(width: 8),
          Expanded(child: _HeroCard(value: '$games', label: 'Games')),
          const SizedBox(width: 8),
          // "Avg Pts" read as a scoring average (PPG) to basketball players;
          // it is Homegrown points per game.
          Expanded(child: _HeroCard(value: '$avg', label: 'Avg / Game')),
        ]);
      },
    );
  }

  // ── Ratings ───────────────────────────────

  Widget _buildRatingsSection(Map<String, dynamic> userData) {
    final ratings = (userData['ratings'] as Map?)?.cast<String, dynamic>() ?? {};
    if (ratings.isEmpty) return const SizedBox.shrink();
    _selectedRatingSport ??= ratings.keys.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionTitle(LucideIcons.swords, 'Your Ratings'),
        const SizedBox(height: 8),
        Row(
          children: ratings.entries.map((e) {
            final sport = e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedRatingSport = sport),
                child: _RatingChip(
                  sport: sport,
                  rating: _toInt(e.value),
                  selected: _selectedRatingSport == sport,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _buildRatingTrend(_selectedRatingSport!),
      ]),
    );
  }

  Widget _buildRatingTrend(String sport) {
    return StreamBuilder<QuerySnapshot>(
      stream: RatingService.ratingHistoryStream(uid, sport),
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? []).take(6).toList().reversed.toList();
        if (docs.isEmpty) {
          return Text('No rated matches yet for this sport',
              style: TextStyle(color: AppTheme.sub, fontSize: 12));
        }
        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final entry = docs[i].data() as Map<String, dynamic>;
              final delta = _toInt(entry['delta']);
              final won = entry['result'] == 'win';
              final color = won ? AppTheme.success : AppTheme.error;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.5))),
                child: Text(
                  '${_toInt(entry['newRating'])} (${delta >= 0 ? '+' : ''}$delta)',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              );
            },
          ),
        );
      },
    );
  }

  // ── Chart ─────────────────────────────────
  // CHANGED: bottom axis now shows both the date and a truncated
  // event name (two lines) instead of generic "G1/G2/G3" labels
  // that told you nothing about which game was which.

  Widget _buildChart(BuildContext context,
      List<Map<String, dynamic>> chartStats) {
    final maxPts = chartStats
        .map((s) => _toDouble(s['pointsAwarded']))
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
      decoration: BoxDecoration(color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: BarChart(
        BarChartData(
          maxY: (maxPts * 1.35).ceilToDouble(),
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppTheme.border, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              // Room for the two label lines at their readable 10/9px sizes.
              reservedSize: 38,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= chartStats.length) return const SizedBox();
                final stat = chartStats[i];
                final ts = stat['createdAt'] as Timestamp?;
                final dateLabel =
                    ts != null ? DateFormat('MMM d').format(ts.toDate()) : '';
                final rawName = stat['eventName'] as String? ?? '';
                final nameLabel = rawName.length > 7
                    ? '${rawName.substring(0, 6)}…'
                    : rawName;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(children: [
                    Text(dateLabel, style: TextStyle(
                        color: AppTheme.sub,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
                    Text(nameLabel, style: TextStyle(
                        color: AppTheme.muted, fontSize: 9)),
                  ]),
                );
              },
            )),
          ),
          barGroups: chartStats.asMap().entries.map((e) {
            final pts = _toDouble(e.value['pointsAwarded']);
            final pct = maxPts > 0 ? pts / maxPts : 0.0;
            final color = pct >= 0.8
                ? AppTheme.accent
                : pct >= 0.5
                    ? const Color(0xFFFFD04D)
                    : const Color(0xFFFFE9A0);
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(
                toY: pts,
                width: 18,
                color: color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(5)),
              ),
            ]);
          }).toList(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.accentSurface,
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${rod.toY.toInt()} pts',
                TextStyle(
                    color: AppTheme.accentText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
  }

  // ── Sport filter ──────────────────────────
  // Same pill shape as the leaderboard's sport chips.

  Widget _buildSportFilter(List<String> sports, String? active) {
    Widget chip(String label, String? value) {
      final sel = active == value;
      return GestureDetector(
        onTap: () => setState(() => _statsSport = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? AppTheme.accentSurface : AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: sel ? AppTheme.accent : AppTheme.border,
                width: sel ? 2 : 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (value != null) ...[
              Icon(sportIcon(value), size: 14,
                  color: sel ? AppTheme.accentText : AppTheme.muted),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(
                color: sel ? AppTheme.accentText : AppTheme.muted,
                fontSize: 12,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip('All Sports', null),
        for (final s in sports) chip(s, s),
      ]),
    );
  }

  // ── Game history ──────────────────────────
  // Rows are tap-to-expand, matching the home screen's Recent Activity. Each
  // row names its sport, since an athlete's games can span more than one.

  Widget _buildGameHistory(List<Map<String, dynamic>> stats) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Column(children: stats.asMap().entries.map((e) {
        final isLast = e.key == stats.length - 1;
        // Keyed to the game itself: the sport filter reorders this list, and
        // an unkeyed row would hand its expanded state to whichever game
        // landed in its slot.
        return _GameHistoryTile(
            key: ObjectKey(e.value), data: e.value, showDivider: !isLast);
      }).toList()),
    );
  }

  // ── Empty ─────────────────────────────────

  Widget _buildEmpty() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accent)),
          child: const Center(child: Icon(LucideIcons.barChart2,
              color: AppTheme.accent, size: 34))),
        const SizedBox(height: 20),
        Text('No stats yet', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Your stats will appear here after an organizer records your game.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.6)),
        const SizedBox(height: 20),
        // The one thing an athlete can do here without waiting on anyone.
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => Get.toNamed('/profile'),
            icon: const Icon(LucideIcons.video, size: 18),
            label: const Text('Add a highlight video'),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => showPointsExplainerSheet(context),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('How do points work?',
                style: TextStyle(color: AppTheme.accentText, fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ));
  }

  Widget _buildSectionTitle(IconData icon, String title) => Row(children: [
        Icon(icon, color: AppTheme.sub, size: 15),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800)),
      ]);
}

class _HeroCard extends StatelessWidget {
  final String value, label;
  final bool isAccentText;
  const _HeroCard(
      {required this.value, required this.label, this.isAccentText = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: TextStyle(
              color: isAccentText ? AppTheme.accent : AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(
              color: AppTheme.muted, fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _RatingChip extends StatelessWidget {
  final String sport;
  final int rating;
  final bool selected;
  const _RatingChip(
      {required this.sport, required this.rating, required this.selected});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: selected ? AppTheme.accentSurface : AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppTheme.accent : AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sport[0].toUpperCase() + sport.substring(1), style: TextStyle(
              color: selected ? AppTheme.accentText : AppTheme.sub,
              fontSize: 11, fontWeight: FontWeight.w600)),
          Text('$rating', style: TextStyle(
              color: selected ? AppTheme.accentText : AppTheme.textPrimary,
              fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      );
}

/// One expandable game-history row. Collapsed shows just the event
/// name, date, and points. Tapping reveals the full stat breakdown
/// for that game — same interaction as the home screen's Recent
/// Activity tiles, so the two screens feel like one system.
class _GameHistoryTile extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool showDivider;
  const _GameHistoryTile(
      {super.key, required this.data, required this.showDivider});

  @override
  State<_GameHistoryTile> createState() => _GameHistoryTileState();
}

class _GameHistoryTileState extends State<_GameHistoryTile> {
  bool _expanded = false;

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }

  List<MapEntry<String, String>> _fullStatRows(
      String sport, Map<String, dynamic> stats) {
    switch (sport) {
      case 'Basketball':
        return [
          MapEntry('Points', '${_toInt(stats['points'])}'),
          MapEntry('Assists', '${_toInt(stats['assists'])}'),
          MapEntry('Rebounds', '${_toInt(stats['rebounds'])}'),
          MapEntry('Steals', '${_toInt(stats['steals'])}'),
          MapEntry('Blocks', '${_toInt(stats['blocks'])}'),
          MapEntry('Turnovers', '${_toInt(stats['turnovers'])}'),
        ];
      case 'Volleyball':
        return [
          MapEntry('Kills', '${_toInt(stats['kills'])}'),
          MapEntry('Aces', '${_toInt(stats['aces'])}'),
          MapEntry('Assists', '${_toInt(stats['assists'])}'),
          MapEntry('Digs', '${_toInt(stats['digs'])}'),
          MapEntry('Blocks', '${_toInt(stats['blocks'])}'),
        ];
      case 'Badminton':
        final won = stats['matchWon'] as bool? ?? false;
        return [
          MapEntry('Result', won ? 'Win' : 'Loss'),
          MapEntry('Sets Won', '${_toInt(stats['setsWon'])}'),
          MapEntry('Points Scored', '${_toInt(stats['pointsScored'])}'),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.data;
    final sport = s['sport'] as String? ?? '';
    final pts = _toInt(s['pointsAwarded']);
    final name = s['eventName'] as String? ?? 'Unknown';
    final date = s['createdAt'] as Timestamp?;
    final fmtDate =
        date != null ? DateFormat('MMM dd, yyyy').format(date.toDate()) : '';
    final statMap = (s['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    final notes = (s['notes'] as String? ?? '').trim();
    final rows = _fullStatRows(sport, statMap);

    return Container(
      decoration: BoxDecoration(
          border: Border(
              bottom: widget.showDivider
                  ? BorderSide(color: AppTheme.border)
                  : BorderSide.none)),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    // The sport as well as the date: an athlete's history
                    // can mix basketball, volleyball and badminton.
                    Row(children: [
                      Icon(sportIcon(sport), color: AppTheme.muted, size: 12),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                            [if (sport.isNotEmpty) sport,
                             if (fmtDate.isNotEmpty) fmtDate].join(' · '),
                            style: TextStyle(
                                color: AppTheme.muted, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('+$pts', style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(LucideIcons.chevronDown,
                    color: AppTheme.muted, size: 18),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.cardNested,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: rows
                        .map((r) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: AppTheme.card,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.border)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.key, style: TextStyle(
                                      color: AppTheme.sub, fontSize: 11)),
                                  Text(r.value, style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Notes', style: TextStyle(
                        color: AppTheme.sub,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(notes, style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ]),
    );
  }
}