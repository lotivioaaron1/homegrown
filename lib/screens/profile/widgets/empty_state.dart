// lib/screens/profile/widgets/empty_state.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/app_theme.dart';

/// Reusable empty-state card: icon, message, and an optional CTA button.
/// Used by PhotoGrid / VideoGrid / AchievementsList when their list is empty.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.cardNested,
            shape: BoxShape.circle,
          ),
          child: Center(child: Icon(icon, color: AppTheme.muted, size: 22)),
        ),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppTheme.sub,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500),
        ),
        if (ctaLabel != null && onCta != null) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onCta,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accent),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.plus, color: AppTheme.accentText, size: 14),
                const SizedBox(width: 6),
                Text(
                  ctaLabel!,
                  style: TextStyle(
                      color: AppTheme.accentText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
