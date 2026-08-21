// lib/screens/profile/widgets/portfolio_tab_bar.dart
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

enum PortfolioTab { highlights, photos, achievements }

/// Segmented tab bar for the athlete portfolio section
/// (Highlights / Photos / Achievements), styled like the existing
/// pill-filter pattern used on the leaderboard screen.
class PortfolioTabBar extends StatelessWidget {
  final PortfolioTab selected;
  final ValueChanged<PortfolioTab> onChanged;

  const PortfolioTabBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        _tab(PortfolioTab.highlights, '🎬', 'Highlights'),
        _tab(PortfolioTab.photos, '📸', 'Photos'),
        _tab(PortfolioTab.achievements, '🏅', 'Achievements'),
      ]),
    );
  }

  Widget _tab(PortfolioTab tab, String icon, String label) {
    final sel = selected == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppTheme.accentSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel ? AppTheme.accent : Colors.transparent, width: 1.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: sel ? AppTheme.accentText : AppTheme.sub,
                fontSize: 11,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
