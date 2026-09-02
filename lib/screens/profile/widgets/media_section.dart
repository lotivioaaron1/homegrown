// lib/screens/profile/widgets/media_section.dart
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/media_item.dart';
import '../../../widgets/skeleton.dart';
import 'photo_grid.dart';
import 'video_grid.dart';

/// One portfolio section — header with an `n / max` quota counter, then the
/// matching grid or its empty state.
///
/// Photos and videos differ only in type, grid, and cap, so both go through
/// here: the quota counter, the loading skeleton, and the grid choice then
/// exist once instead of being duplicated per section and drifting apart.
///
/// Deliberately takes a list rather than opening its own stream. The profile
/// needs these same counts to disable its Add buttons, so one listener up in
/// ProfileScreen feeds the sections and the buttons alike — three overlapping
/// listeners on the same collection would only invite them to disagree.
class MediaSection extends StatelessWidget {
  final List<MediaItem> items;
  final bool loading;
  final MediaType type;
  final String title;
  final IconData icon;
  final int max;
  final void Function(MediaItem)? onTapItem;

  const MediaSection({
    super.key,
    required this.items,
    required this.type,
    required this.title,
    required this.icon,
    required this.max,
    this.loading = false,
    this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(loading ? null : items.length),
        const SizedBox(height: 12),
        if (loading)
          _loading()
        else if (type == MediaType.video)
          VideoGrid(items: items, onTapItem: onTapItem)
        else
          PhotoGrid(items: items, onTapItem: onTapItem),
      ],
    );
  }

  /// [count] is null while loading, so the counter appears with the content
  /// rather than flashing `0 / 20` before the real number arrives.
  Widget _header(int? count) {
    final atCap = count != null && count >= max;
    return Row(children: [
      Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppTheme.accent, size: 16),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
      const Spacer(),
      if (count != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            // Turns amber at the cap so the limit is discoverable before
            // someone hits it and gets refused.
            color: atCap ? AppTheme.warning.withValues(alpha: 0.15) : AppTheme.cardNested,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: atCap
                    ? AppTheme.warning.withValues(alpha: 0.4)
                    : AppTheme.border),
          ),
          child: Text('$count / $max',
              style: TextStyle(
                  color: atCap ? AppTheme.warning : AppTheme.sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
    ]);
  }

  Widget _loading() {
    // Mirrors the grid it stands in for, so the layout does not jump when the
    // real tiles land.
    final isVideo = type == MediaType.video;
    return Shimmer(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: isVideo ? 2 : 3,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isVideo ? 2 : 3,
          mainAxisSpacing: isVideo ? 10 : 8,
          crossAxisSpacing: isVideo ? 10 : 8,
          childAspectRatio: isVideo ? 1.3 : 1,
        ),
        itemBuilder: (_, __) => const SkeletonBox(radius: 10),
      ),
    );
  }
}
