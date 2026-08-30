// lib/screens/profile/widgets/photo_grid.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../models/media_item.dart';
import 'empty_state.dart';

/// Responsive photo grid. Shows [EmptyState] when [items] is empty.
/// Phase 1: placeholder tiles only — no real image loading yet.
class PhotoGrid extends StatelessWidget {
  final List<MediaItem> items;

  const PhotoGrid({super.key, required this.items});

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
      itemBuilder: (context, i) => _PhotoTile(item: items[i]),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final MediaItem item;
  const _PhotoTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardNested,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Icon(LucideIcons.image, color: AppTheme.muted, size: 22),
      ),
    );
  }
}
