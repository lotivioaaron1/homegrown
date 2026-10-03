// lib/screens/profile/widgets/media_section.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  /// Whether the header counts against [max]. True on the owner's own
  /// profile, where the remaining quota is what they need to know; false
  /// when a coach or teammate is looking, since someone else's upload
  /// allowance tells the viewer nothing and reads as a limit on browsing.
  final bool showQuota;

  /// Replaces the grid's default empty-state copy. The defaults are written
  /// to the owner ("Upload your best plays"), which is the wrong voice on a
  /// profile someone else is viewing.
  final String? emptyMessage;

  /// Starts an upload, on the owner's own profile only. With it, an empty
  /// section's card carries the upload button, and a section with media in
  /// it gets "+ Add" beside its counter until the quota is used up. Null on
  /// someone else's profile, so neither appears.
  final VoidCallback? onAdd;

  /// The empty card's button, e.g. "Upload a clip".
  final String emptyAddLabel;

  /// An upload into this section is under way: both Add controls show a
  /// spinner and stop responding.
  final bool busy;

  /// Shown between the header and the grid, e.g. the video upload's
  /// progress bar.
  final Widget? status;

  const MediaSection({
    super.key,
    required this.items,
    required this.type,
    required this.title,
    required this.icon,
    required this.max,
    this.loading = false,
    this.onTapItem,
    this.showQuota = true,
    this.emptyMessage,
    this.onAdd,
    this.emptyAddLabel = 'Add',
    this.busy = false,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final owner = onAdd != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(loading ? null : items.length),
        const SizedBox(height: 12),
        if (status != null) ...[
          status!,
          const SizedBox(height: 12),
        ],
        if (loading)
          _loading()
        else if (type == MediaType.video)
          VideoGrid(
            items: items,
            onTapItem: onTapItem,
            emptyMessage: emptyMessage,
            emptyCtaLabel: owner ? (busy ? 'Uploading...' : emptyAddLabel) : null,
            onEmptyCta: onAdd,
            emptyCtaBusy: owner && busy,
          )
        else
          PhotoGrid(
            items: items,
            onTapItem: onTapItem,
            emptyMessage: emptyMessage,
            emptyCtaLabel: owner ? (busy ? 'Uploading...' : emptyAddLabel) : null,
            onEmptyCta: onAdd,
            emptyCtaBusy: owner && busy,
          ),
      ],
    );
  }

  /// [count] is null while loading, so the counter appears with the content
  /// rather than flashing `0 / 20` before the real number arrives.
  Widget _header(int? count) {
    // Never at cap in the viewer's eyes: the amber warning below is an
    // "you can't upload more" signal, which means nothing to a coach.
    final atCap = showQuota && count != null && count >= max;
    // An empty section offers the upload inside its card instead, and a full
    // one has nothing to add; the amber counter says why.
    final showAdd =
        onAdd != null && count != null && count > 0 && (busy || count < max);
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
      // Expanded so the Add button can never push the counter off a narrow
      // phone; the title gives way first.
      Expanded(
        child: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
      ),
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
          child: Text(showQuota ? '$count / $max' : '$count',
              style: TextStyle(
                  color: atCap ? AppTheme.warning : AppTheme.sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      if (showAdd) ...[
        const SizedBox(width: 8),
        _addButton(),
      ],
    ]);
  }

  /// "+ Add" beside the counter, in the empty card's gold. While busy it is
  /// a spinner alone: "Uploading..." would squeeze the title on a small
  /// phone, and the video section's progress bar already says what's
  /// happening. The 44px-tall hit area is wider than the pill it wraps.
  Widget _addButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onAdd,
      child: SizedBox(
        height: 44,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accent),
            ),
            child: busy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: AppTheme.accentText, strokeWidth: 2),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.plus,
                        color: AppTheme.accentText, size: 14),
                    const SizedBox(width: 4),
                    Text('Add',
                        style: TextStyle(
                            color: AppTheme.accentText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ]),
          ),
        ),
      ),
    );
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
