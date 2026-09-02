// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../services/media_service.dart';
import '../../services/team_service.dart';
import '../../widgets/video_player_sheet.dart';
import '../settings/settings_screen.dart';
import 'widgets/media_section.dart';

/// Portfolio-style profile. Header + avatar + bio, then Video/Photo
/// highlights, both backed by live uploads and capped per athlete by
/// MediaService.maxPhotos / maxVideos.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _uploadingPhoto = false;

  // Videos are transcoded then uploaded, which takes long enough that a bare
  // spinner reads as a hang — so the phase and its progress are both tracked.
  bool _uploadingVideo = false;
  MediaUploadPhase _videoPhase = MediaUploadPhase.compressing;
  double _videoProgress = 0;

  String _initials(String first, String last) {
    final f = first.isNotEmpty ? first[0].toUpperCase() : '';
    final l = last.isNotEmpty ? last[0].toUpperCase() : '';
    return '$f$l';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_uid)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2.5),
              );
            }
            final data = snap.data?.data() as Map<String, dynamic>? ?? {};
            final role = data['role'] as String? ?? 'athlete';
            final firstName = data['firstName'] as String? ?? '';
            final lastName = data['lastName'] as String? ?? '';
            // Coaches write their team name to `teamOrganization` and
            // organizers write theirs to `organization` at registration,
            // neither of which is the generic `teamName` field, so fall
            // back to those here — otherwise this subtitle silently shows
            // nothing useful for a coach or organizer.
            final teamName = (role == 'coach'
                    ? data['teamOrganization'] as String?
                    : role == 'organizer'
                        ? data['organization'] as String?
                        : data['teamName'] as String?) ??
                '';
            final bio = data['bio'] as String? ?? '';
            final photoUrl = data['photoUrl'] as String?;
            final sport = (data['primarySports'] as List?)?.isNotEmpty == true
                ? (data['primarySports'] as List).first.toString()
                : '';

            final roleLabel = role == 'athlete'
                ? 'Athlete'
                : role == 'coach'
                    ? 'Coach'
                    : 'Organizer';
            final subtitle = teamName.isNotEmpty
                ? teamName
                : (sport.isNotEmpty ? '$roleLabel · $sport' : roleLabel);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Header
                Row(children: [
                  _iconButton(LucideIcons.arrowLeft, () => Get.back()),
                  const SizedBox(width: 12),
                  Text('Profile',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  _iconButton(LucideIcons.settings,
                      () => Get.to(() => const SettingsScreen())),
                ]),
                const SizedBox(height: 22),

                // Avatar + name + team
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
                        Text(subtitle,
                            style: TextStyle(
                                color: AppTheme.sub,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // Bio
                if (bio.isNotEmpty) ...[
                  Text(bio,
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.5)),
                  const SizedBox(height: 18),
                ] else
                  const SizedBox(height: 4),

                // Portfolio (athlete only)
                if (role == 'athlete') _portfolio(context),

                // Team identity hub (coach only) — My Team and Scout stay
                // the real roster/scouting tools; this is a summary plus
                // quick entry points into them, not a second copy.
                if (role == 'coach') ...[
                  GestureDetector(
                    onTap: () => Get.toNamed('/team/roster'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border)),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: AppTheme.cardNested,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: (data['teamLogoUrl'] as String?)
                                        ?.isNotEmpty ==
                                    true
                                ? CachedNetworkImage(
                                    imageUrl: data['teamLogoUrl'] as String,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 150,
                                    errorWidget: (_, __, ___) => Icon(
                                        Icons.shield_outlined,
                                        color: AppTheme.muted,
                                        size: 22))
                                : Icon(Icons.shield_outlined,
                                    color: AppTheme.muted, size: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    teamName.isNotEmpty
                                        ? teamName
                                        : 'Your Team',
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                StreamBuilder<QuerySnapshot>(
                                  stream: TeamService.streamRoster(_uid),
                                  builder: (context, rosterSnap) {
                                    final count =
                                        rosterSnap.data?.docs.length ?? 0;
                                    return Text(
                                        '$count / ${TeamService.maxPlayers} players',
                                        style: TextStyle(
                                            color: AppTheme.sub,
                                            fontSize: 12));
                                  },
                                ),
                              ]),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppTheme.muted, size: 20),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: _credentialBox(
                            'Experience',
                            (data['yearsOfExperience'] as String?)
                                        ?.isNotEmpty ==
                                    true
                                ? data['yearsOfExperience'] as String
                                : '—')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _credentialBox(
                            'Level',
                            (data['coachingLevel'] as String?)?.isNotEmpty ==
                                    true
                                ? data['coachingLevel'] as String
                                : '—')),
                  ]),
                  if ((data['coachingBio'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(data['coachingBio'] as String,
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            height: 1.5)),
                  ],
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                        child: _addButton(Icons.groups_outlined,
                            'Manage Roster', () => Get.toNamed('/team/roster'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _addButton(Icons.search_rounded,
                            'Scout Players', () => Get.toNamed('/scout'))),
                  ]),
                ],

                // Organization identity hub (organizer only) — a condensed
                // summary card; Settings remains the full-detail view (also
                // showing certifications/barangay, deliberately left out
                // here to match the coach section's restraint above).
                if (role == 'organizer') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border)),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: AppTheme.cardNested,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border)),
                        child: Icon(Icons.business_rounded,
                            color: AppTheme.muted, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  teamName.isNotEmpty
                                      ? teamName
                                      : 'Your Organization',
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800)),
                              if ((data['organizationType'] as String?)
                                      ?.isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 2),
                                Text(data['organizationType'] as String,
                                    style: TextStyle(
                                        color: AppTheme.sub, fontSize: 12)),
                              ],
                            ]),
                      ),
                      const SizedBox(width: 8),
                      _organizerStatusBadge(
                          data['organizerStatus'] as String?),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  if ((data['sportsOrganized'] as List?)?.isNotEmpty ==
                      true) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (data['sportsOrganized'] as List)
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: AppTheme.cardNested,
                                    borderRadius: BorderRadius.circular(6),
                                    border:
                                        Border.all(color: AppTheme.border)),
                                child: Text(s.toString(),
                                    style: TextStyle(
                                        color: AppTheme.sub, fontSize: 11)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                  FutureBuilder<AggregateQuerySnapshot>(
                    // Only the number is shown, so a count aggregation costs
                    // one read instead of one per event created.
                    future: FirebaseFirestore.instance
                        .collection('events')
                        .where('organizerId', isEqualTo: _uid)
                        .count()
                        .get(),
                    builder: (context, eventsSnap) {
                      final count = eventsSnap.data?.count;
                      return _credentialBox(
                          'Events Created', count == null ? '—' : '$count');
                    },
                  ),
                  const SizedBox(height: 20),
                  _addButton(LucideIcons.plus, 'Create Event',
                      () => Get.toNamed('/events/create')),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// The athlete portfolio: both Add buttons and both media sections, driven
  /// by one listener on users/{uid}/media. The buttons need the same counts
  /// the section headers show, so they share a stream rather than each
  /// opening their own and risking a moment where they disagree.
  Widget _portfolio(BuildContext context) {
    return StreamBuilder<List<MediaItem>>(
      stream: MediaService.streamMedia(_uid),
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final all = snap.data ?? const <MediaItem>[];
        final photos =
            all.where((m) => m.type == MediaType.photo).toList(growable: false);
        final videos =
            all.where((m) => m.type == MediaType.video).toList(growable: false);

        // While loading, treat nothing as at-cap: greying the buttons out on
        // an unknown count would look like the feature is broken.
        final photosFull = !loading && photos.length >= MediaService.maxPhotos;
        final videosFull = !loading && videos.length >= MediaService.maxVideos;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: _addButton(
                  LucideIcons.video,
                  _uploadingVideo
                      ? _videoBusyLabel()
                      : videosFull
                          ? 'Highlights full'
                          : 'Add Video',
                  (_uploadingVideo || videosFull)
                      ? null
                      : () => _addVideo(context),
                  busy: _uploadingVideo,
                  disabled: videosFull,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _addButton(
                  LucideIcons.image,
                  _uploadingPhoto
                      ? 'Uploading...'
                      : photosFull
                          ? 'Photos full'
                          : 'Add Photo',
                  (_uploadingPhoto || photosFull)
                      ? null
                      : () => _addPhoto(context),
                  busy: _uploadingPhoto,
                  disabled: photosFull,
                ),
              ),
            ]),
            if (_uploadingVideo) ...[
              const SizedBox(height: 12),
              _videoProgressBar(),
            ],
            const SizedBox(height: 26),
            MediaSection(
              items: videos,
              loading: loading,
              type: MediaType.video,
              title: 'Video Highlights',
              icon: LucideIcons.video,
              max: MediaService.maxVideos,
              onTapItem: (item) => showVideoHighlight(
                context,
                item,
                onDelete: () => _confirmDelete(context, item),
              ),
            ),
            const SizedBox(height: 26),
            MediaSection(
              items: photos,
              loading: loading,
              type: MediaType.photo,
              title: 'Photo Highlights',
              icon: LucideIcons.image,
              max: MediaService.maxPhotos,
              onTapItem: (item) => _openPhotoViewer(context, item),
            ),
          ],
        );
      },
    );
  }

  String _videoBusyLabel() =>
      _videoPhase == MediaUploadPhase.compressing ? 'Compressing...' : 'Uploading...';

  Widget _videoProgressBar() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: _videoProgress,
          minHeight: 5,
          backgroundColor: AppTheme.cardNested,
          valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _videoPhase == MediaUploadPhase.compressing
            ? 'Shrinking your clip so it uploads faster — keep this screen open.'
            : 'Uploading your highlight...',
        style: TextStyle(color: AppTheme.sub, fontSize: 11),
      ),
    ]);
  }

  // Upload flow
  Future<void> _addPhoto(BuildContext context) async {
    final choice = await _pickCategorySheet(context);
    if (choice == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final item = await MediaService.pickAndUploadPhoto(
        uid: _uid,
        category: choice.category,
        caption: choice.caption,
      );
      if (item != null) {
        _snack('Photo added',
            'Your ${item.categoryLabel.toLowerCase()} photo is now on your profile.');
      }
    } on MediaException catch (e) {
      _snack('Could not add photo', e.message, isError: true);
    } catch (e) {
      _snack('Upload failed',
          'Something went wrong. Check your connection and try again.',
          isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _addVideo(BuildContext context) async {
    final choice = await _pickCategorySheet(
      context,
      title: 'Add Highlight',
      subtitle:
          'Pick a category, then choose a clip. Max ${MediaService.maxVideoSeconds} seconds.',
      icon: LucideIcons.video,
      actionLabel: 'Choose Video',
    );
    if (choice == null) return;

    setState(() {
      _uploadingVideo = true;
      _videoPhase = MediaUploadPhase.compressing;
      _videoProgress = 0;
    });
    try {
      final item = await MediaService.pickAndUploadVideo(
        uid: _uid,
        category: choice.category,
        caption: choice.caption,
        onProgress: (phase, progress) {
          if (!mounted) return;
          setState(() {
            _videoPhase = phase;
            _videoProgress = progress;
          });
        },
      );
      if (item != null) {
        _snack('Highlight added',
            'Your ${item.categoryLabel.toLowerCase()} clip is now on your profile.');
      }
    } on MediaException catch (e) {
      _snack('Could not add highlight', e.message, isError: true);
    } catch (e) {
      _snack('Upload failed',
          'Something went wrong. Check your connection and try again.',
          isError: true);
    } finally {
      if (mounted) setState(() => _uploadingVideo = false);
    }
  }

  /// Shared by both upload flows — they differ only in wording and icon, so
  /// forking this into a near-identical video sheet would just guarantee the
  /// two drift apart.
  Future<_PhotoChoice?> _pickCategorySheet(
    BuildContext context, {
    String title = 'Add Photo',
    String subtitle = 'Pick a category, then choose an image.',
    IconData icon = LucideIcons.image,
    String actionLabel = 'Choose from Gallery',
  }) {
    MediaCategory selected = MediaCategory.game;
    final captionCtrl = TextEditingController();
    return showModalBottomSheet<_PhotoChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: StatefulBuilder(
            builder: (ctx, setSheet) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(title,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MediaCategory.values.map((c) {
                    final sel = c == selected;
                    return GestureDetector(
                      onTap: () => setSheet(() => selected = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppTheme.accentSurface
                              : AppTheme.cardNested,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: sel ? AppTheme.accent : AppTheme.border,
                              width: sel ? 2 : 1.5),
                        ),
                        child: Text(_categoryLabel(c),
                            style: TextStyle(
                                color: sel
                                    ? AppTheme.accentText
                                    : AppTheme.muted,
                                fontSize: 13,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: captionCtrl,
                  maxLength: 80,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Caption (optional)',
                    hintStyle: TextStyle(color: AppTheme.muted, fontSize: 14),
                    filled: true,
                    fillColor: AppTheme.cardNested,
                    counterStyle: TextStyle(color: AppTheme.sub, fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppTheme.border, width: 1.5)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppTheme.accent, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Get.back(
                        result:
                            _PhotoChoice(selected, captionCtrl.text.trim())),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: AppTheme.buttonFg, size: 18),
                        const SizedBox(width: 8),
                        Text(actionLabel,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Photo viewer + delete
  void _openPhotoViewer(BuildContext context, MediaItem item) {
    showDialog(
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
                  child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 220,
                  color: AppTheme.cardNested,
                  alignment: Alignment.center,
                  child: Icon(LucideIcons.imageOff,
                      color: AppTheme.muted, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                GestureDetector(
                  onTap: () {
                    Get.back();
                    _confirmDelete(context, item);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: AppTheme.errorSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                AppTheme.errorText.withValues(alpha: 0.4))),
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

  void _confirmDelete(BuildContext context, MediaItem item) {
    final isVideo = item.type == MediaType.video;
    final noun = isVideo ? 'highlight' : 'photo';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Icon(LucideIcons.trash2, color: Color(0xFFFF5C5C), size: 30),
          const SizedBox(height: 12),
          Text('Delete $noun?',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('This removes it from your profile permanently.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.sub, fontSize: 13)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: AppTheme.sub,
                            fontWeight: FontWeight.w600))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                    onPressed: () async {
                      Get.back();
                      try {
                        await MediaService.deleteMedia(_uid, item);
                        _snack('Deleted',
                            '${isVideo ? 'Highlight' : 'Photo'} removed from your profile.');
                      } catch (_) {
                        _snack('Delete failed',
                            'Could not remove that $noun. Try again.',
                            isError: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5C5C),
                        foregroundColor: Colors.white),
                    child: const Text('Delete',
                        style: TextStyle(fontWeight: FontWeight.w700))),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // Reusable pieces
  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
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
  }

  Widget _avatar(String first, String last, String? photoUrl) {
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
                errorWidget: (_, __, ___) => _initialsAvatar(first, last),
              )
            : _initialsAvatar(first, last),
      ),
    );
  }

  Widget _initialsAvatar(String first, String last) => Center(
        child: Text(_initials(first, last),
            style: const TextStyle(
                color: AppTheme.buttonFg,
                fontSize: 24,
                fontWeight: FontWeight.w900)),
      );

  Widget _addButton(IconData icon, String label, VoidCallback? onTap,
      {bool busy = false, bool disabled = false}) {
    // A quota-blocked button drops the gold entirely rather than dimming it:
    // at a glance it should read as "not available", not "tap harder".
    final fg = disabled ? AppTheme.muted : AppTheme.accentText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
            color: disabled ? AppTheme.cardNested : AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: disabled ? AppTheme.border : AppTheme.accent)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (busy)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: fg, strokeWidth: 2),
            )
          else
            Icon(disabled ? LucideIcons.circleSlash : icon, color: fg, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _credentialBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: AppTheme.cardNested,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: AppTheme.muted, fontSize: 10),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _organizerStatusBadge(String? status) {
    final (label, color) = switch (status) {
      'approved' => ('Approved', AppTheme.success),
      'rejected' => ('Rejected', AppTheme.error),
      'revoked' => ('Revoked', AppTheme.error),
      _ => ('Pending Review', AppTheme.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  String _categoryLabel(MediaCategory c) {
    switch (c) {
      case MediaCategory.game:
        return 'Game';
      case MediaCategory.team:
        return 'Team';
      case MediaCategory.tournament:
        return 'Tournament';
      case MediaCategory.award:
        return 'Award';
      case MediaCategory.training:
        return 'Training';
    }
  }

  void _snack(String title, String msg, {bool isError = false}) {
    Get.snackbar(title, msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: isError ? const Color(0xFF2A1A1A) : AppTheme.card,
        colorText: isError ? const Color(0xFFFF5C5C) : AppTheme.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3));
  }
}

/// Result of the category sheet, shared by the photo and video flows.
class _PhotoChoice {
  final MediaCategory category;
  final String caption;
  _PhotoChoice(this.category, this.caption);
}

