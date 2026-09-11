// lib/widgets/athlete_profile_sheet.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/media_item.dart';
import '../screens/profile/athlete_profile_view_screen.dart';
import '../services/media_service.dart';
import '../theme/app_theme.dart';
import '../utils/profile_format.dart';
import 'athlete_profile_parts.dart';

/// How many portfolio thumbnails the sheet previews. Four fits the strip
/// across a phone without scrolling; the rest live on the full profile.
const int _kTeaserCount = 4;

/// Shared read-only athlete profile bottom sheet — avatar, stat boxes,
/// per-category stat averages, and bio. Leaderboard, Scout, My Team, and
/// event rosters all used to carry their own nearly-identical copy of this;
/// this is the one implementation they share instead.
///
/// [trailingActionBuilder], if given, is called with the fetched athlete
/// data to build a caller-specific action shown above the Close button —
/// e.g. Scout's "Invite to Team" button, which Leaderboard/My Team/event
/// rosters don't show.
void showAthleteProfileSheet(
  BuildContext context, {
  required String athleteId,
  Widget Function(BuildContext context, Map<String, dynamic> athlete)?
      trailingActionBuilder,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (_, ctrl) => FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('users').doc(athleteId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2));
          }
          final athlete = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          return _AthleteProfileContent(
            scrollController: ctrl,
            athleteId: athleteId,
            athlete: athlete,
            trailingActionBuilder: trailingActionBuilder,
          );
        },
      ),
    ),
  );
}

class _AthleteProfileContent extends StatelessWidget {
  final ScrollController scrollController;
  final String athleteId;
  final Map<String, dynamic> athlete;
  final Widget Function(BuildContext context, Map<String, dynamic> athlete)?
      trailingActionBuilder;

  const _AthleteProfileContent({
    required this.scrollController,
    required this.athleteId,
    required this.athlete,
    required this.trailingActionBuilder,
  });

  int _toInt(dynamic v) => v is int ? v : (v is double ? v.toInt() : 0);

  @override
  Widget build(BuildContext context) {
    final firstName = athlete['firstName'] as String? ?? '';
    final lastName = athlete['lastName'] as String? ?? '';
    final position = athlete['position'] as String? ?? '—';
    final barangay = athlete['barangay'] as String? ?? '—';
    final years = athlete['yearsOfPlaying'] as String? ?? '—';
    final height = formatMeasure(athlete['heightCm'], 'cm');
    final weight = formatMeasure(athlete['weightKg'], 'kg');
    final bio = athlete['bio'] as String? ?? '';
    final sports = (athlete['primarySports'] as List?)
            ?.map((e) => e.toString())
            .join(', ') ??
        '—';
    final isOpen = athlete['openToRecruitment'] as bool? ?? false;
    final pts = _toInt(athlete['points']);
    final photoUrl = athlete['photoUrl'] as String?;
    final initials =
        '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
            .toUpperCase();

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Center(
              child: Column(children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.accent, AppTheme.accent2]),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accent, width: 2.5)),
              child: ClipOval(
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(photoUrl,
                        fit: BoxFit.cover,
                        width: 72,
                        height: 72,
                        errorBuilder: (_, __, ___) => Center(
                            child: Text(initials,
                                style: const TextStyle(
                                    color: AppTheme.buttonFg,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900))))
                    : Center(
                        child: Text(initials,
                            style: const TextStyle(
                                color: AppTheme.buttonFg,
                                fontSize: 22,
                                fontWeight: FontWeight.w900))),
              ),
            ),
            const SizedBox(height: 10),
            Text('$firstName $lastName',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text('$position · $barangay',
                style: TextStyle(color: AppTheme.sub, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                    color: isOpen ? AppTheme.successSurface : AppTheme.cardNested,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isOpen ? AppTheme.successText : AppTheme.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isOpen ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isOpen ? AppTheme.successText : AppTheme.muted, size: 14),
                  const SizedBox(width: 6),
                  Text(isOpen ? 'Open to Recruitment' : 'Not Available',
                      style: TextStyle(
                          color: isOpen ? AppTheme.successText : AppTheme.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ])),
          ])),
          const SizedBox(height: 20),
          Row(children: [
            ProfileStatBox(value: '$pts', label: 'Total Pts', isAccent: true),
            const SizedBox(width: 8),
            ProfileStatBox(value: years, label: 'Experience'),
            const SizedBox(width: 8),
            ProfileStatBox(value: height, label: 'Height'),
            const SizedBox(width: 8),
            ProfileStatBox(value: weight, label: 'Weight'),
          ]),
          const SizedBox(height: 16),
          // Sits directly under the headline figures, above the averages and
          // the detail rows: the footage is the thing a scout came for, so it
          // should not be below a scroll.
          _buildHighlightsTeaser(context),
          const SizedBox(height: 16),
          AthleteStatAverages(athleteId: athleteId),
          const SizedBox(height: 16),
          Divider(color: AppTheme.border),
          const SizedBox(height: 12),
          ProfileInfoRow(label: 'Sport', value: sports),
          const SizedBox(height: 8),
          ProfileInfoRow(label: 'Position', value: position),
          const SizedBox(height: 8),
          ProfileInfoRow(label: 'Barangay', value: barangay),
          const SizedBox(height: 8),
          ProfileInfoRow(label: 'Experience', value: years),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Bio',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppTheme.cardNested,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border)),
                child: Text(bio,
                    style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.5))),
          ],
          const SizedBox(height: 24),
          if (trailingActionBuilder != null) ...[
            trailingActionBuilder!(context, athlete),
            const SizedBox(height: 10),
          ],
          SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                  onPressed: () => Get.back(),
                  child: Text('Close',
                      style: TextStyle(
                          color: AppTheme.sub,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)))),
        ],
      ),
    );
  }

  // ── Highlights teaser ─────────────────────
  // The reason this sheet exists at all is to decide "is this player worth a
  // closer look", and footage answers that better than any average does. A
  // strip of thumbnails makes it visible that highlights exist without the
  // viewer having to open anything — during a fast Scout scan, a plain
  // button would be scrolled past.

  Widget _buildHighlightsTeaser(BuildContext context) {
    if (athleteId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<MediaItem>>(
      // Capped at the four the strip can show. The full profile opens its own
      // unbounded stream; this one must not pull a 23-item portfolio just to
      // render a preview.
      stream: MediaService.streamMedia(athleteId, limit: _kTeaserCount),
      builder: (context, snap) {
        final items = snap.data ?? const <MediaItem>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (items.isNotEmpty) ...[
              Row(children: [
                const Icon(LucideIcons.clapperboard,
                    color: AppTheme.accent, size: 14),
                const SizedBox(width: 6),
                Text('Highlights',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _TeaserTile(
                    item: items[i],
                    onTap: () => _openFullProfile(context),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: () => _openFullProfile(context),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.accent, width: 1.5)),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('View Full Profile',
                          style: TextStyle(
                              color: AppTheme.accentText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Icon(LucideIcons.arrowRight,
                          color: AppTheme.accentText, size: 15),
                    ]),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Dismisses the sheet before pushing the full profile — without the
  /// `Get.back()` the sheet stays mounted underneath and is still there when
  /// the viewer pops back off the profile.
  ///
  /// Pushed with the widget rather than by route name so the caller's action
  /// travels with it: a coach who watches a highlight and decides to recruit
  /// can invite from the profile itself, instead of backing out to a sheet
  /// this method has already dismissed. The `/profile/athlete` named route
  /// stays registered for callers that have only a uid to offer.
  void _openFullProfile(BuildContext context) {
    final action = trailingActionBuilder?.call(context, athlete);
    Get.back();
    Get.to(() => AthleteProfileViewScreen(
          athleteId: athleteId,
          trailingAction: action,
        ));
  }
}

/// One thumbnail in the teaser strip. Videos carry a play glyph so the strip
/// distinguishes a clip from a photo at a glance, the way the portfolio grids
/// already do.
class _TeaserTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _TeaserTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 96,
          height: 72,
          child: Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(
              imageUrl: item.thumbnailUrl,
              fit: BoxFit.cover,
              memCacheWidth: 220,
              placeholder: (_, __) => Container(color: AppTheme.cardNested),
              // A video whose poster frame failed to generate falls back to
              // the clip's own URL, which will not decode as an image. The
              // play badge below still reads it as a video.
              errorWidget: (_, __, ___) =>
                  Container(color: AppTheme.cardNested),
            ),
            if (item.type == MediaType.video) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28)),
              ),
              const Center(
                child: Icon(LucideIcons.playCircle,
                    color: Colors.white, size: 22),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
