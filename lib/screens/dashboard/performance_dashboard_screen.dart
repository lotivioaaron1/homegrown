// lib/screens/dashboard/performance_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class PerformanceDashboardScreen extends StatelessWidget {
  const PerformanceDashboardScreen({super.key});

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  int _toInt(dynamic v) {
    if (v is int)    return v;
    if (v is double) return v.toInt();
    return 0;
  }

  double _toDouble(dynamic v) {
    if (v is int)    return v.toDouble();
    if (v is double) return v;
    return 0.0;
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
                      userSnap.connectionState  == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(
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
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textPrimary, size: 16)),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('My Dashboard', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 18,
            fontWeight: FontWeight.w800)),
          Text('Performance Overview',
              style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _buildContent(BuildContext context,
      Map<String, dynamic> userData,
      List<Map<String, dynamic>> stats) {
    if (stats.isEmpty) return _buildEmpty();

    final totalPts    = _toInt(userData['points']);
    final gamesPlayed = stats.length;
    final avgPts      = gamesPlayed > 0
        ? (totalPts / gamesPlayed).round() : 0;

    final sportTotals = <String, int>{};
    for (final s in stats) {
      final sport = s['sport'] as String? ?? 'Unknown';
      final pts   = _toDouble(s['pointsAwarded']).round();
      sportTotals[sport] = (sportTotals[sport] ?? 0) + pts;
    }

    final chartStats = stats.reversed.take(6).toList().reversed.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Hero row with real rank
        _buildHeroRow(totalPts, gamesPlayed, avgPts),
        const SizedBox(height: 16),
        if (chartStats.isNotEmpty) ...[
          _buildSectionTitle('📈 Points Per Game'),
          const SizedBox(height: 8),
          _buildChart(context, chartStats),
          const SizedBox(height: 16),
        ],
        if (sportTotals.isNotEmpty) ...[
          _buildSectionTitle('🏅 Sport Breakdown'),
          const SizedBox(height: 8),
          _buildSportBreakdown(sportTotals, totalPts),
          const SizedBox(height: 16),
        ],
        _buildSectionTitle('🗂 Game History'),
        const SizedBox(height: 8),
        _buildGameHistory(stats),
      ],
    );
  }

  // ── Hero row ──────────────────────────────

  Widget _buildHeroRow(int totalPts, int games, int avg) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'athlete')
          .get(),
      builder: (context, snap) {
        String rank = '#—';
        if (snap.hasData) {
          final list = snap.data!.docs
              .map((d) => d.data() as Map<String, dynamic>)
              .toList()
            ..sort((a, b) =>
                _toInt(b['points']).compareTo(_toInt(a['points'])));
          final idx = list.indexWhere((a) => a['uid'] == uid);
          if (idx >= 0) rank = '#${idx + 1}';
        }
        return Row(children: [
          Expanded(child: _HeroCard(
              value: '$totalPts', label: 'Total Pts', isAccent: true)),
          const SizedBox(width: 8),
          Expanded(child: _HeroCard(value: rank, label: 'City Rank')),
          const SizedBox(width: 8),
          Expanded(child: _HeroCard(value: '$games', label: 'Games')),
          const SizedBox(width: 8),
          Expanded(child: _HeroCard(value: '$avg', label: 'Avg Pts')),
        ]);
      },
    );
  }

  // ── Chart ─────────────────────────────────

  Widget _buildChart(BuildContext context,
      List<Map<String, dynamic>> chartStats) {
    final maxPts = chartStats
        .map((s) => _toDouble(s['pointsAwarded']))
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      decoration: BoxDecoration(color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: BarChart(
        BarChartData(
          maxY: (maxPts * 1.3).ceilToDouble(),
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppTheme.border, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles:   true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= chartStats.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('G${i + 1}', style: TextStyle(
                    color: AppTheme.muted, fontSize: 9,
                    fontWeight: FontWeight.w600)));
              },
            )),
          ),
          barGroups: chartStats.asMap().entries.map((e) {
            final pts = _toDouble(e.value['pointsAwarded']);
            final pct = maxPts > 0 ? pts / maxPts : 0.0;
            final color = pct >= 0.8 ? AppTheme.accent
                : pct >= 0.5 ? const Color(0xFFFFD04D)
                : const Color(0xFFFFE9A0);
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(
                toY: pts, width: 16, color: color,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5))),
            ]);
          }).toList(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.accentSurface,
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${rod.toY.toInt()} pts',
                TextStyle(color: AppTheme.accentText,
                    fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        swapAnimationDuration: const Duration(milliseconds: 400),
        swapAnimationCurve:    Curves.easeInOut,
      ),
    );
  }

  // ── Sport breakdown ───────────────────────

  Widget _buildSportBreakdown(Map<String, int> totals, int totalPts) {
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final emoji = {'Basketball': '🏀', 'Volleyball': '🏐', 'Badminton': '🏸'};
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Column(children: sorted.map((e) {
        final pct = totalPts > 0 ? e.value / totalPts : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Text(emoji[e.key] ?? '🏅',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            SizedBox(width: 80, child: Text(e.key, style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 12,
              fontWeight: FontWeight.w600))),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct, minHeight: 6,
                backgroundColor: AppTheme.border,
                valueColor: const AlwaysStoppedAnimation(AppTheme.accent)),
            )),
            const SizedBox(width: 10),
            Text('${e.value}', style: TextStyle(
              color: AppTheme.accentText, fontSize: 12,
              fontWeight: FontWeight.w800)),
          ]),
        );
      }).toList()),
    );
  }

  // ── Game history ──────────────────────────

  Widget _buildGameHistory(List<Map<String, dynamic>> stats) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
      child: Column(children: stats.asMap().entries.map((e) {
        final isLast  = e.key == stats.length - 1;
        final stat    = e.value;
        final sport   = stat['sport']          as String?    ?? '';
        final pts     = _toDouble(stat['pointsAwarded']).round();
        final name    = stat['eventName']      as String?    ?? 'Unknown';
        final date    = stat['createdAt']      as Timestamp?;
        final fmtDate = date != null
            ? DateFormat('MMM dd, yyyy').format(date.toDate()) : '';
        final statMap = stat['stats'] as Map<String, dynamic>? ?? {};
        final emoji   = sport == 'Basketball' ? '🏀'
            : sport == 'Volleyball' ? '🏐' : '🏸';
        final summary = _statSummary(sport, statMap);

        return Container(
          decoration: BoxDecoration(border: Border(
            bottom: isLast
                ? BorderSide.none
                : BorderSide(color: AppTheme.border))),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppTheme.accentSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accent)),
                child: Center(child: Text(emoji,
                    style: const TextStyle(fontSize: 16)))),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: TextStyle(color: AppTheme.textPrimary,
                    fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(summary,
                    style: TextStyle(color: AppTheme.sub, fontSize: 10)),
                if (fmtDate.isNotEmpty)
                  Text(fmtDate,
                      style: TextStyle(color: AppTheme.muted, fontSize: 10)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppTheme.accentSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accent)),
                child: Text('+$pts', style: TextStyle(
                  color: AppTheme.accentText, fontSize: 13,
                  fontWeight: FontWeight.w800))),
            ]),
          ),
        );
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
          child: const Center(child: Text('📊',
              style: TextStyle(fontSize: 36)))),
        const SizedBox(height: 20),
        Text('No stats yet', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Your stats will appear here after an organizer records your game.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.6)),
      ]),
    ));
  }

  Widget _buildSectionTitle(String title) => Text(title, style: TextStyle(
    color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800));

  String _statSummary(String sport, Map<String, dynamic> s) {
    switch (sport) {
      case 'Basketball':
        return '${s['points'] ?? 0}pts · ${s['assists'] ?? 0}ast · '
            '${s['rebounds'] ?? 0}reb · ${s['steals'] ?? 0}stl';
      case 'Volleyball':
        return '${s['kills'] ?? 0}kills · ${s['aces'] ?? 0}aces · '
            '${s['digs'] ?? 0}digs';
      case 'Badminton':
        final w = s['matchWon'] == true ? 'Win' : 'Loss';
        return '$w · ${s['setsWon'] ?? 0} sets won';
      default: return sport;
    }
  }
}

class _HeroCard extends StatelessWidget {
  final String value, label; final bool isAccent;
  const _HeroCard({required this.value, required this.label,
      this.isAccent = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    decoration: BoxDecoration(
      color: isAccent ? AppTheme.accentSurface : AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isAccent ? AppTheme.accent : AppTheme.border,
        width: isAccent ? 1.5 : 1)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(
        color: isAccent ? AppTheme.accentText : AppTheme.textPrimary,
        fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center, style: TextStyle(
        color: AppTheme.muted, fontSize: 9, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis),
    ]),
  );
}