// lib/widgets/points_explainer_sheet.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../utils/elo_calculator.dart';
import '../utils/stat_scoring.dart';

/// One stat and what each one is worth in Homegrown points.
class PointWeight {
  final String label;

  /// The key calcPointsAwarded reads, so the test can check [perUnit].
  final String statKey;
  final double perUnit;

  const PointWeight(this.label, this.statKey, this.perUnit);
}

/// The scoring table as shown to athletes. It restates the weights in
/// stat_scoring.dart for display, and test/widgets/points_explainer_sheet_test
/// fails if the two ever disagree — change both together.
const Map<String, List<PointWeight>> kPointWeights = {
  'Basketball': [
    PointWeight('Point', 'points', 1),
    PointWeight('Assist', 'assists', 1.5),
    PointWeight('Rebound', 'rebounds', 1),
    PointWeight('Steal', 'steals', 2),
    PointWeight('Block', 'blocks', 2),
    PointWeight('Turnover', 'turnovers', -1),
  ],
  'Volleyball': [
    PointWeight('Kill', 'kills', 2),
    PointWeight('Ace', 'aces', 2),
    PointWeight('Block', 'blocks', 2),
    PointWeight('Assist', 'assists', 1),
    PointWeight('Dig', 'digs', 1),
  ],
  'Badminton': [
    PointWeight('Win', 'matchWon', 10),
    PointWeight('Set won', 'setsWon', 3),
    PointWeight('Point scored', 'pointsScored', 0.5),
  ],
};

const Map<String, String> _kSportEmoji = {
  'Basketball': '🏀',
  'Volleyball': '🏐',
  'Badminton': '🏸',
};

/// "How points work" — the one place the app explains its numbers.
///
/// Home's TOTAL POINTS, the dashboard and the leaderboard all show Homegrown
/// points, a weighted score rather than points scored: a basketball player who
/// scores 10 is credited with more than 10. Nothing used to say so, and the
/// leaderboard's sport filter quietly switched to a different number — match
/// rating — without saying that either.
void showPointsExplainerSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => _PointsExplainer(scrollController: ctrl),
    ),
  );
}

class _PointsExplainer extends StatelessWidget {
  final ScrollController scrollController;
  const _PointsExplainer({required this.scrollController});

  static String _formatWeight(double v) {
    final magnitude = v.abs();
    final text = magnitude == magnitude.truncateToDouble()
        ? magnitude.toInt().toString()
        : magnitude.toString();
    return '${v < 0 ? '−' : '+'}$text';
  }

  @override
  Widget build(BuildContext context) {
    // Computed, not typed out, so the example can never contradict the
    // formula actually used to score games.
    final examplePoints = calcPointsAwarded(
        'Basketball', {'points': 10, 'assists': 3, 'rebounds': 5});

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 18),
        Text('How points work',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
            'Every recorded game earns you Homegrown points. The organizer '
            'enters your stats after the game, and the app scores them.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.5)),
        const SizedBox(height: 18),
        for (final entry in kPointWeights.entries) ...[
          Text('${_kSportEmoji[entry.key] ?? ''}  ${entry.key}',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entry.value
                .map((w) => _WeightChip(
                    label: w.label, value: _formatWeight(w.perUnit)))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accent)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(LucideIcons.lightbulb, color: AppTheme.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  'Example: 10 points, 3 assists and 5 rebounds in a '
                  'basketball game = $examplePoints Homegrown points. That is '
                  'why your total is not the same as the points you scored.',
                  style: TextStyle(
                      color: AppTheme.accentText, fontSize: 12.5, height: 1.5)),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        const _Section(
          icon: LucideIcons.trophy,
          title: 'City Rank',
          body: 'Your place among every athlete in Legazpi by total Homegrown '
              "points. You're unranked until your first recorded game.",
        ),
        const SizedBox(height: 14),
        const _Section(
          icon: LucideIcons.swords,
          title: 'Match rating (Rankings by sport)',
          body: 'Each sport has its own rating, starting at $kStartingRating. '
              'After a recorded match it goes up when your side wins and down '
              'when it loses — more for beating a higher-rated side, and a '
              'little more for a standout game.',
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('Got it'),
          ),
        ),
      ],
    );
  }
}

class _WeightChip extends StatelessWidget {
  final String label;
  final String value;
  const _WeightChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: AppTheme.cardNested,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border)),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: '$label ',
              style: TextStyle(color: AppTheme.sub, fontSize: 12)),
          TextSpan(
              text: value,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ])),
      );
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Section({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: AppTheme.accent, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(body,
                    style: TextStyle(
                        color: AppTheme.sub, fontSize: 12.5, height: 1.5)),
              ],
            ),
          ),
        ],
      );
}
