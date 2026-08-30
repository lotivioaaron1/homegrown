// lib/screens/profile/widgets/video_grid.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../models/media_item.dart';
import 'empty_state.dart';

/// Responsive video grid. Shows [EmptyState] when [items] is empty.
/// Phase 1: placeholder tiles only — no real video playback yet.
class VideoGrid extends StatelessWidget {
  final List<MediaItem> items;

  const VideoGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.video,
        message: 'No highlights yet.\nUpload your best plays to build your reel.',
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.3,
      ),
      itemBuilder: (context, i) => _VideoTile(item: items[i]),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final MediaItem item;
  const _VideoTile({required this.item});

  String _formatDuration(int? seconds) {
    if (seconds == null) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final duration = _formatDuration(item.durationSeconds);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardNested,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Stack(children: [
        Center(
          child: Icon(LucideIcons.playCircle, color: AppTheme.muted, size: 28),
        ),
        if (duration.isNotEmpty)
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                duration,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ]),
    );
  }
}
