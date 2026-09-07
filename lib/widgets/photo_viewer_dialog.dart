// lib/widgets/photo_viewer_dialog.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../models/media_item.dart';

/// Full-screen portfolio photo viewer — image on top, then a category chip,
/// caption, and delete affordance. Deliberately the same shape and signature
/// as [showVideoHighlight] in video_player_sheet.dart, so both media types are
/// opened, dismissed and deleted the same way.
///
/// This lived privately inside ProfileScreen until coaches and teammates
/// needed to open the same photos read-only; it sits here beside the video
/// player rather than under screens/profile/ because it is no longer the
/// owner's screen alone that shows it.
///
/// [onDelete] is null when someone other than the owner is looking, and the
/// delete affordance is then omitted rather than shown and refused.
Future<void> showPhotoViewer(
  BuildContext context,
  MediaItem item, {
  VoidCallback? onDelete,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: item.url,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(
                height: 220,
                color: AppTheme.cardNested,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 220,
                color: AppTheme.cardNested,
                alignment: Alignment.center,
                child:
                    Icon(LucideIcons.imageOff, color: AppTheme.muted, size: 32),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border)),
            child: Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.accentSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accent)),
                child: Text(item.categoryLabel,
                    style: TextStyle(
                        color: AppTheme.accentText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.caption.isNotEmpty ? item.caption : 'No caption',
                  style: TextStyle(color: AppTheme.sub, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Absent entirely when someone else is looking: the caption then
              // runs the full width rather than leaving a gap where a control
              // the viewer can never use would have been.
              if (onDelete != null)
                GestureDetector(
                  onTap: () {
                    Get.back();
                    onDelete();
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
          ),
        ],
      ),
    ),
  );
}
