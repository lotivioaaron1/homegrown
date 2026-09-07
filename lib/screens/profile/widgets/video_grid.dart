// lib/screens/profile/widgets/video_grid.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../models/media_item.dart';
import 'empty_state.dart';

/// Formats a clip length as `m:ss`. Shared with the highlight viewer so the
/// grid badge and the player's scrub position never disagree on the format.
String formatClipDuration(int? seconds) {
  if (seconds == null) return '';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Video half of the portfolio. Purely presentational — [MediaSection] owns
/// the stream and the quota, so this can be pumped in a test without Firebase.
class VideoGrid extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem)? onTapItem;

  /// Overrides the empty-state copy, which is otherwise addressed to the
  /// portfolio's owner and reads oddly to a coach or teammate viewing it.
  final String? emptyMessage;

  const VideoGrid(
      {super.key, required this.items, this.onTapItem, this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: LucideIcons.video,
        message: emptyMessage ??
            'No highlights yet.\nUpload your best plays to build your reel.',
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
      itemBuilder: (context, i) =>
          _VideoTile(item: items[i], onTap: onTapItem),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final MediaItem item;
  final void Function(MediaItem)? onTap;
  const _VideoTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final duration = formatClipDuration(item.durationSeconds);
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardNested,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(
              imageUrl: item.thumbnailUrl,
              fit: BoxFit.cover,
              memCacheWidth: 400,
              placeholder: (_, __) => Container(color: AppTheme.cardNested),
              // Thumbnail generation can fail on an unusual codec, in which
              // case thumbnailUrl falls back to the video URL and will not
              // decode as an image. A plain tile still reads as a video
              // because the play badge below sits on top regardless.
              errorWidget: (_, __, ___) =>
                  Container(color: AppTheme.cardNested),
            ),
            // Scrim: keeps the white play glyph and duration legible over a
            // bright frame.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
            const Center(
              child: Icon(LucideIcons.playCircle, color: Colors.white, size: 34),
            ),
            if (duration.isNotEmpty)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        ),
      ),
    );
  }
}
