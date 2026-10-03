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
///
/// With an odd count the first clip (the newest, as MediaService streams
/// them) spans the full width and the rest sit two to a row. With an even
/// count they all sit two to a row. Either way no row is left half empty,
/// which a plain two-column grid did at the three-clip cap.
class VideoGrid extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem)? onTapItem;

  /// Overrides the empty-state copy, which is otherwise addressed to the
  /// portfolio's owner and reads oddly to a coach or teammate viewing it.
  final String? emptyMessage;

  /// The empty card's button, e.g. "Upload a clip". Shown only with
  /// [onEmptyCta], or while [emptyCtaBusy]; the owner's profile passes both,
  /// a viewer's passes neither.
  final String? emptyCtaLabel;
  final VoidCallback? onEmptyCta;
  final bool emptyCtaBusy;

  const VideoGrid({
    super.key,
    required this.items,
    this.onTapItem,
    this.emptyMessage,
    this.emptyCtaLabel,
    this.onEmptyCta,
    this.emptyCtaBusy = false,
  });

  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: LucideIcons.video,
        message: emptyMessage ??
            'No highlights yet.\nUpload your best plays to build your reel.',
        ctaLabel: emptyCtaLabel,
        onCta: onEmptyCta,
        ctaBusy: emptyCtaBusy,
      );
    }

    final featured = items.length.isOdd ? items.first : null;
    final rest = featured == null ? items : items.skip(1).toList();

    return Column(children: [
      if (featured != null)
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _VideoTile(item: featured, onTap: onTapItem, featured: true),
        ),
      for (var i = 0; i < rest.length; i += 2)
        Padding(
          padding: EdgeInsets.only(
              top: featured != null || i > 0 ? _gap : 0),
          child: Row(children: [
            Expanded(child: _pairTile(rest[i])),
            const SizedBox(width: _gap),
            Expanded(
                child: i + 1 < rest.length
                    ? _pairTile(rest[i + 1])
                    : const SizedBox.shrink()),
          ]),
        ),
    ]);
  }

  Widget _pairTile(MediaItem item) => AspectRatio(
        aspectRatio: 1.3,
        child: _VideoTile(item: item, onTap: onTapItem),
      );
}

class _VideoTile extends StatelessWidget {
  final MediaItem item;
  final void Function(MediaItem)? onTap;

  /// The full-width tile: a bigger play glyph, and the caption shown.
  final bool featured;

  const _VideoTile({required this.item, this.onTap, this.featured = false});

  @override
  Widget build(BuildContext context) {
    final duration = formatClipDuration(item.durationSeconds);
    final caption = featured ? item.caption.trim() : '';
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
              memCacheWidth: featured ? 800 : 400,
              placeholder: (_, __) => Container(color: AppTheme.cardNested),
              // Thumbnail generation can fail on an unusual codec, in which
              // case thumbnailUrl falls back to the video URL and will not
              // decode as an image. A plain tile still reads as a video
              // because the play badge below sits on top regardless.
              errorWidget: (_, __, ___) =>
                  Container(color: AppTheme.cardNested),
            ),
            // Scrim: keeps the white play glyph, caption and duration
            // legible over a bright frame.
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
            Center(
              child: Icon(LucideIcons.playCircle,
                  color: Colors.white, size: featured ? 44 : 34),
            ),
            if (caption.isNotEmpty || duration.isNotEmpty)
              Positioned(
                left: 8,
                right: 6,
                bottom: 6,
                child: Row(children: [
                  Expanded(
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (duration.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
