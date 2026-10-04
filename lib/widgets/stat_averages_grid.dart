// lib/widgets/stat_averages_grid.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/stats_view.dart';

/// An athlete's per-game box-score averages for one sport, on the performance
/// dashboard: a 2×2 grid, or a single row of three for Badminton.
///
/// The figures come from [boxScoreAverages], which shares its averaging with
/// Scout, so they match what a coach sees. Renders nothing for a sport that
/// has no categories.
class StatAveragesGrid extends StatelessWidget {
  final String sport;

  /// That sport's `stats` documents, decoded to maps.
  final List<Map<String, dynamic>> games;

  const StatAveragesGrid({super.key, required this.sport, required this.games});

  @override
  Widget build(BuildContext context) {
    final tiles = boxScoreAverages(sport, games);
    if (tiles.isEmpty) return const SizedBox.shrink();

    // Three fit across; four would leave each tile too narrow for its label.
    final perRow = tiles.length == 3 ? 3 : 2;
    final rows = [
      for (var i = 0; i < tiles.length; i += perRow)
        tiles.sublist(i, (i + perRow).clamp(0, tiles.length)),
    ];

    return Column(children: [
      for (final row in rows)
        Padding(
          padding: EdgeInsets.only(bottom: row == rows.last ? 0 : 8),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < perRow; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: i < row.length
                      ? _AverageTile(row[i])
                      : const SizedBox.shrink(),
                ),
              ],
            ]),
          ),
        ),
    ]);
  }
}

class _AverageTile extends StatelessWidget {
  final StatAverage average;

  const _AverageTile(this.average);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(average.value,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1)),
          const SizedBox(height: 6),
          Text(average.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}
