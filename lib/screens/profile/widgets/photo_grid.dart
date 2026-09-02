// lib/screens/profile/widgets/photo_grid.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../models/media_item.dart';
import 'empty_state.dart';

/// Photo half of the portfolio. Purely presentational — [MediaSection] owns
/// the stream and the quota, so this can be pumped in a test without Firebase.
class PhotoGrid extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem)? onTapItem;

  const PhotoGrid({super.key, required this.items, this.onTapItem});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.image,
        message:
            'No photos yet.\nGame-day shots and training snaps will show up here.',
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, i) =>
          _PhotoTile(item: items[i], onTap: onTapItem),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final MediaItem item;
  final void Function(MediaItem)? onTap;
  const _PhotoTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: item.thumbnailUrl,
          fit: BoxFit.cover,
          // The grid is 3-up on a phone, so a full-resolution decode would
          // cost ~20x the pixels actually shown.
          memCacheWidth: 300,
          placeholder: (_, __) => Container(
            color: AppTheme.cardNested,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            color: AppTheme.cardNested,
            alignment: Alignment.center,
            child: Icon(LucideIcons.imageOff, color: AppTheme.muted, size: 20),
          ),
        ),
      ),
    );
  }
}
