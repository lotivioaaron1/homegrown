// lib/widgets/video_player_sheet.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../models/media_item.dart';
import '../screens/profile/widgets/video_grid.dart' show formatClipDuration;

/// Full-screen highlight player. Mirrors the photo viewer's shape — media on
/// top, then a category chip, caption, and delete affordance — so both media
/// types are dismissed and deleted the same way.
///
/// [onDelete] is null when someone other than the owner is watching — a coach
/// scouting, or a teammate — and the delete affordance is then omitted rather
/// than shown and refused.
Future<void> showVideoHighlight(
  BuildContext context,
  MediaItem item, {
  VoidCallback? onDelete,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    builder: (_) => VideoHighlightDialog(item: item, onDelete: onDelete),
  );
}

class VideoHighlightDialog extends StatefulWidget {
  final MediaItem item;

  /// Null for a read-only viewing — see [showVideoHighlight].
  final VoidCallback? onDelete;

  const VideoHighlightDialog({super.key, required this.item, this.onDelete});

  @override
  State<VideoHighlightDialog> createState() => _VideoHighlightDialogState();
}

class _VideoHighlightDialogState extends State<VideoHighlightDialog> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.item.url))
      ..initialize().then((_) {
        // The dialog can be dismissed while the network video is still
        // loading; setState after that would throw.
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.setLooping(true);
        _controller.play();
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _error = 'This highlight could not be played.');
      });
  }

  @override
  void dispose() {
    // Without this the decoder keeps running and the audio plays on after the
    // dialog is closed.
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: _ready ? _controller.value.aspectRatio : 16 / 9,
            child: Container(
              color: Colors.black,
              child: _error != null
                  ? _errorBody()
                  : !_ready
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.accent, strokeWidth: 2))
                      : Stack(alignment: Alignment.center, children: [
                          VideoPlayer(_controller),
                          // Whole-surface tap target: tapping the video is the
                          // expected way to pause, not hunting for a control.
                          GestureDetector(
                            onTap: _togglePlay,
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedOpacity(
                              opacity: _controller.value.isPlaying ? 0 : 1,
                              duration: const Duration(milliseconds: 180),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.25),
                                alignment: Alignment.center,
                                child: const Icon(LucideIcons.play,
                                    color: Colors.white, size: 44),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10),
                              colors: VideoProgressColors(
                                playedColor: AppTheme.accent,
                                bufferedColor:
                                    Colors.white.withValues(alpha: 0.35),
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                        ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _metaBar(context),
      ]),
    );
  }

  Widget _errorBody() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.videoOff, color: AppTheme.muted, size: 32),
          const SizedBox(height: 10),
          Text(_error!,
              style: TextStyle(color: AppTheme.sub, fontSize: 12.5)),
        ]),
      );

  Widget _metaBar(BuildContext context) {
    final duration = formatClipDuration(widget.item.durationSeconds);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accent)),
          child: Text(widget.item.categoryLabel,
              style: TextStyle(
                  color: AppTheme.accentText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.item.caption.isNotEmpty
                ? widget.item.caption
                : (duration.isNotEmpty ? duration : 'No caption'),
            style: TextStyle(color: AppTheme.sub, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Absent entirely when someone else is watching: the caption then
        // runs the full width rather than leaving a gap where a control the
        // viewer can never use would have been.
        if (widget.onDelete != null)
          GestureDetector(
            onTap: () {
              Get.back();
              widget.onDelete!();
            },
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: AppTheme.errorSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.errorText.withValues(alpha: 0.4))),
              child: Icon(LucideIcons.trash2,
                  color: AppTheme.errorText, size: 16),
            ),
          ),
      ]),
    );
  }
}
