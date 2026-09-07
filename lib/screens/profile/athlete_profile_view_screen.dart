// lib/screens/profile/athlete_profile_view_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/media_item.dart';
import '../../models/report.dart';
import '../../services/media_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../utils/sports.dart';
import '../../widgets/athlete_profile_parts.dart';
import '../../widgets/photo_viewer_dialog.dart';
import '../../widgets/report_dialog.dart';
import '../../widgets/video_player_sheet.dart';
import 'widgets/media_section.dart';

/// Another athlete's profile, read-only — the scouting counterpart to
/// [ProfileScreen].
///
/// Stats answer "how well has this player performed"; photos and highlight
/// clips answer "can this player play", which is the question a coach is
/// actually asking and the one the numbers can't reach. The portfolio was
/// only ever visible to the athlete who uploaded it until this screen; the
/// underlying reads were already permitted by firestore.rules and
/// storage.rules for any signed-in user.
///
/// Deliberately mirrors ProfileScreen's layout — same header shape, same
/// avatar treatment, same media sections in the same order — so an athlete
/// recognises their own profile in what a coach sees.
class AthleteProfileViewScreen extends StatelessWidget {
  final String athleteId;

  /// Optional caller-specific action pinned under the header — Scout passes
  /// its "Invite to Team" button so a coach can recruit straight from the
  /// footage rather than backing out to the sheet to do it.
  final Widget? trailingAction;

  const AthleteProfileViewScreen({
    super.key,
    required this.athleteId,
    this.trailingAction,
  });

  /// Reads the id from either the constructor or the route arguments, so the
  /// screen works both as a named route (`/profile/athlete`) and when pushed
  /// directly with a caller-supplied action.
  static AthleteProfileViewScreen fromRoute() {
    final args = Get.arguments;
    return AthleteProfileViewScreen(
      athleteId: (args is Map ? args['athleteId'] as String? : null) ?? '',
    );
  }

  int _toInt(dynamic v) => v is int ? v : (v is double ? v.toInt() : 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: athleteId.isEmpty
            ? _missing('No athlete selected',
                'This profile was opened without an athlete to show.')
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(athleteId)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.accent, strokeWidth: 2.5));
                  }
                  if (snap.hasError) {
                    return _missing('Could not load this profile',
                        friendlyError(snap.error));
                  }
                  final athlete = snap.data?.data() as Map<String, dynamic>?;
                  // A deleted account, or a membership doc pointing at a uid
                  // that no longer exists. Saying so beats a screen of dashes.
                  if (athlete == null) {
                    return _missing('Profile unavailable',
                        'This athlete is no longer on Homegrown.');
                  }
                  return _buildProfile(context, athlete);
                },
              ),
      ),
    );
  }

  // ── Body ──────────────────────────────────

  Widget _buildProfile(BuildContext context, Map<String, dynamic> athlete) {
    final firstName = athlete['firstName'] as String? ?? '';
    final lastName = athlete['lastName'] as String? ?? '';
    final position = athlete['position'] as String? ?? '—';
    final barangay = athlete['barangay'] as String? ?? '—';
    final years = athlete['yearsOfPlaying'] as String? ?? '—';
    final height = athlete['heightCm']?.toString() ?? '—';
    final weight = athlete['weightKg']?.toString() ?? '—';
    final bio = athlete['bio'] as String? ?? '';
    final sports = sportsOf(athlete);
    final isOpen = athlete['openToRecruitment'] as bool? ?? false;
    final pts = _toInt(athlete['points']);
    final photoUrl = athlete['photoUrl'] as String?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(children: [
          _iconButton(LucideIcons.arrowLeft, () => Get.back()),
          const SizedBox(width: 12),
          Text('Athlete Profile',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          // Files a complaint into the admin console's Reports queue. Hidden
          // on your own profile, where there is nothing to report.
          if (FirebaseAuth.instance.currentUser?.uid != athleteId) ...[
            const Spacer(),
            _iconButton(
              LucideIcons.flag,
              () => showReportDialog(
                context,
                targetType: Report.targetUser,
                targetId: athleteId,
                targetLabel: '$firstName $lastName'.trim(),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 22),

        // Identity
        Row(children: [
          _avatar(firstName, lastName, photoUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$firstName $lastName',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3)),
                const SizedBox(height: 3),
                Text('$position · $barangay',
                    style: TextStyle(
                        color: AppTheme.sub,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                _recruitmentBadge(isOpen),
              ],
            ),
          ),
        ]),

        if (sports.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sports.map(_sportChip).toList(),
          ),
        ],

        if (bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(bio,
              style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13, height: 1.5)),
        ],

        const SizedBox(height: 18),
        Row(children: [
          ProfileStatBox(value: '$pts', label: 'Total Pts', isAccent: true),
          const SizedBox(width: 8),
          ProfileStatBox(value: years, label: 'Experience'),
          const SizedBox(width: 8),
          ProfileStatBox(value: '${height}cm', label: 'Height'),
          const SizedBox(width: 8),
          ProfileStatBox(value: '${weight}kg', label: 'Weight'),
        ]),

        const SizedBox(height: 18),
        AthleteStatAverages(athleteId: athleteId),

        const SizedBox(height: 10),
        _portfolio(context),

        if (trailingAction != null) ...[
          const SizedBox(height: 24),
          trailingAction!,
        ],
      ],
    );
  }

  // ── Portfolio ─────────────────────────────
  // One listener feeding both sections, as ProfileScreen does — two streams
  // on the same collection would only invite them to disagree.

  Widget _portfolio(BuildContext context) {
    return StreamBuilder<List<MediaItem>>(
      stream: MediaService.streamMedia(athleteId),
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final all = snap.data ?? const <MediaItem>[];
        final photos =
            all.where((m) => m.type == MediaType.photo).toList(growable: false);
        final videos =
            all.where((m) => m.type == MediaType.video).toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaSection(
              items: videos,
              loading: loading,
              type: MediaType.video,
              title: 'Video Highlights',
              icon: LucideIcons.video,
              max: MediaService.maxVideos,
              // Someone else's remaining upload allowance is not the viewer's
              // business, and the amber at-cap warning would read as a limit
              // on what they are allowed to watch.
              showQuota: false,
              emptyMessage: 'No highlights yet.\n'
                  'This athlete has not uploaded any clips.',
              // No onDelete: the viewer does not own this media, so the
              // control is absent rather than shown and refused.
              onTapItem: (item) => showVideoHighlight(context, item),
            ),
            const SizedBox(height: 26),
            MediaSection(
              items: photos,
              loading: loading,
              type: MediaType.photo,
              title: 'Photo Highlights',
              icon: LucideIcons.image,
              max: MediaService.maxPhotos,
              showQuota: false,
              emptyMessage: 'No photos yet.\n'
                  'This athlete has not uploaded any photos.',
              onTapItem: (item) => showPhotoViewer(context, item),
            ),
          ],
        );
      },
    );
  }

  // ── Pieces ────────────────────────────────

  Widget _recruitmentBadge(bool isOpen) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
            color: isOpen ? AppTheme.successSurface : AppTheme.cardNested,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isOpen ? AppTheme.successText : AppTheme.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isOpen ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isOpen ? AppTheme.successText : AppTheme.muted, size: 13),
          const SizedBox(width: 5),
          Text(isOpen ? 'Open to Recruitment' : 'Not Available',
              style: TextStyle(
                  color: isOpen ? AppTheme.successText : AppTheme.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _sportChip(String sport) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.accent)),
        child: Text(sport,
            style: TextStyle(
                color: AppTheme.accentText,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );

  Widget _iconButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border)),
          child: Icon(icon, color: AppTheme.textPrimary, size: 18),
        ),
      );

  Widget _avatar(String first, String last, String? photoUrl) {
    final initials =
        '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'
            .toUpperCase();
    final fallback = Center(
      child: Text(initials,
          style: const TextStyle(
              color: AppTheme.buttonFg,
              fontSize: 24,
              fontWeight: FontWeight.w900)),
    );
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.accent, AppTheme.accent2]),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.accent, width: 2),
      ),
      child: ClipOval(
        child: (photoUrl != null && photoUrl.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                errorWidget: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }

  Widget _missing(String title, String subtitle) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            _iconButton(LucideIcons.arrowLeft, () => Get.back()),
          ]),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                        color: AppTheme.accentSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accent)),
                    child: const Icon(LucideIcons.userX,
                        color: AppTheme.accent, size: 30)),
                const SizedBox(height: 16),
                Text(title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.sub, fontSize: 13, height: 1.5)),
              ]),
            ),
          ),
        ),
      ]);
}
