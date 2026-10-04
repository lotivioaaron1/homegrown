// lib/widgets/best_game_card.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../utils/stats_view.dart';

/// The athlete's highest-scoring game, on the performance dashboard, picked
/// by [bestGame]. Styled like the Best Game section in Settings so the two
/// read as the same thing.
///
/// [game] is one `stats` document decoded to a map.
class BestGameCard extends StatelessWidget {
  final Map<String, dynamic> game;

  const BestGameCard({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final name = (game['eventName'] as String? ?? '').trim();
    final sport = game['sport'] as String? ?? '';
    final ts = game['createdAt'];
    final venue = (game['venue'] as String? ?? '').trim();
    final stats = (game['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    // The box score first: it's what the athlete remembers the game by.
    final detail = [
      boxScoreLine(sport, stats),
      if (ts is Timestamp) DateFormat('MMM d').format(ts.toDate()),
      venue,
    ].where((s) => s.isNotEmpty).join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.accentSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accent)),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent)),
          child: const Icon(LucideIcons.trophy, color: AppTheme.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('BEST GAME',
                style: TextStyle(
                    color: AppTheme.accentText,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(name.isEmpty ? 'Unknown game' : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3)),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.sub, fontSize: 11)),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        // Points on the right, as in the Game History rows below it.
        Text('+${gamePoints(game)}',
            style: TextStyle(
                color: AppTheme.accentText,
                fontSize: 16,
                fontWeight: FontWeight.w900)),
      ]),
    );
  }
}
