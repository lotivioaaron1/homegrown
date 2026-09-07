// lib/screens/profile/widgets/achievements_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../models/achievement.dart';
import 'empty_state.dart';

/// Resolves an [Achievement.icon] key to its LucideIcons constant.
IconData _iconForKey(String key) {
  switch (key) {
    case 'medal':
      return LucideIcons.medal;
    case 'star':
      return LucideIcons.star;
    case 'award':
      return LucideIcons.award;
    case 'trophy':
    default:
      return LucideIcons.trophy;
  }
}

/// List of achievement cards. Shows [EmptyState] when [items] is empty.
class AchievementsList extends StatelessWidget {
  final List<Achievement> items;

  const AchievementsList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.trophy,
        message:
            'No achievements yet.\nMVP awards and milestones will appear here.',
      );
    }
    return Column(
      children: items.map((a) => _AchievementCard(achievement: a)).toList(),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent),
          ),
          child: Center(
              child: Icon(_iconForKey(achievement.icon),
                  color: AppTheme.accentText, size: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(achievement.title,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(achievement.description,
                  style: TextStyle(
                      color: AppTheme.sub, fontSize: 12, height: 1.3)),
              const SizedBox(height: 4),
              Text(DateFormat.yMMMd().format(achievement.date),
                  style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ]),
    );
  }
}
