// lib/screens/profile/organizer_profile_view_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/report.dart';
import '../../services/team_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/athlete_profile_parts.dart';
import '../../widgets/organizer_profile_parts.dart';
import '../../widgets/report_dialog.dart';

/// An organizer's profile, read-only — the third and last of the public
/// profiles, after [AthleteProfileViewScreen] and [CoachProfileViewScreen].
///
/// Until this screen, `organizerId` was a pure authorisation token: read only
/// to decide whether the Edit and Record Results buttons were drawn, and never
/// once rendered as a person. An athlete could be rostered into an event by
/// someone whose name they never learned.
///
/// Every profile in this app leads with a figure its owner cannot type — the
/// athlete's stat averages, the coach's roster count. Here it is Events
/// Created and Tournaments Run. The organization name, type, certifications
/// and bio below are all self-reported and sit underneath accordingly.
class OrganizerProfileViewScreen extends StatelessWidget {
  final String organizerId;

  const OrganizerProfileViewScreen({super.key, required this.organizerId});

  /// Reads the id from either the constructor or the route arguments, so the
  /// screen works both as a named route (`/profile/organizer`) and when pushed
  /// directly. The byline uses the named route, which keeps
  /// `organizer_profile_parts.dart` from importing this file.
  static OrganizerProfileViewScreen fromRoute() {
    final args = Get.arguments;
    return OrganizerProfileViewScreen(
      organizerId: (args is Map ? args['organizerId'] as String? : null) ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: organizerId.isEmpty
            ? _missing('No organizer selected',
                'This profile was opened without an organizer to show.')
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(organizerId)
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
                  final org = snap.data?.data() as Map<String, dynamic>?;
                  // Two distinct ways to be gone. A missing document is an id
                  // that never resolved; a `deleted: true` document is the
                  // tombstone AccountDeletionService leaves behind so match
                  // reports still resolve to "Deleted user". Events keep their
                  // organizerId through deletion, so the tombstone is the case
                  // that actually reaches this screen — without this check it
                  // would render as a live profile with every field blank.
                  if (org == null || org['deleted'] == true) {
                    return _missing('Profile unavailable',
                        'This organizer is no longer on Homegrown.');
                  }
                  return _buildProfile(context, org);
                },
              ),
      ),
    );
  }

  // ── Body ──────────────────────────────────

  Widget _buildProfile(BuildContext context, Map<String, dynamic> org) {
    // The same resolver the rosters use: `firstName`/`lastName` win over a
    // `fullName` that a pre-rename document may still carry.
    final identity = resolveMemberIdentity(org, fallbackName: 'Organizer');
    final name = identity.name;
    final photoUrl = identity.photoUrl;
    final organization = (org['organization'] as String? ?? '').trim();
    final orgType = (org['organizationType'] as String? ?? '').trim();
    final barangay = (org['barangay'] as String? ?? '').trim();
    final certifications = (org['certifications'] as String? ?? '').trim();
    final bio = (org['bio'] as String? ?? '').trim();
    // Deliberately not `sportsOf()`, which reads `primarySports` — the field
    // an athlete or coach uses. An organizer's sports live in a different one.
    final sports = (org['sportsOrganized'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final subtitle = [
      if (orgType.isNotEmpty) orgType,
      if (barangay.isNotEmpty) barangay,
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(children: [
          _iconButton(LucideIcons.arrowLeft, () => Get.back()),
          const SizedBox(width: 12),
          Text('Organizer Profile',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          // Files into the admin console's Reports queue, as the athlete and
          // coach profiles do. Hidden on your own profile.
          if (FirebaseAuth.instance.currentUser?.uid != organizerId) ...[
            const Spacer(),
            _iconButton(
              LucideIcons.flag,
              () => showReportDialog(
                context,
                targetType: Report.targetUser,
                targetId: organizerId,
                targetLabel: name,
              ),
            ),
          ],
        ]),
        const SizedBox(height: 22),

        // Identity
        Row(children: [
          _avatar(name, photoUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  // Flexible + ellipsis so a long organization name truncates
                  // rather than pushing the tick off the edge.
                  Flexible(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3)),
                  ),
                  OrganizerVerifiedTick(
                      status: org['organizerStatus'] as String?),
                ]),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color: AppTheme.sub,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: 8),
                OrganizerApprovedBadge(
                    status: org['organizerStatus'] as String?),
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
        _TrackRecord(organizerId: organizerId),

        const SizedBox(height: 20),
        _sectionTitle('Organization'),
        const SizedBox(height: 8),
        _organizationCard(organization, orgType),

        if (certifications.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle('Certifications'),
          const SizedBox(height: 8),
          _panel(certifications),
        ],
      ],
    );
  }

  // ── Pieces ────────────────────────────────

  /// No organizer-logo field exists in the app, so this reuses the business
  /// glyph ProfileScreen shows an organizer on their own profile.
  Widget _organizationCard(String organization, String orgType) => Container(
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
            child: Icon(Icons.business_rounded, color: AppTheme.muted, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(organization.isNotEmpty ? organization : 'Unnamed organization',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(orgType.isNotEmpty ? orgType : '—',
                      style: TextStyle(color: AppTheme.sub, fontSize: 12)),
                ]),
          ),
        ]),
      );

  Widget _sectionTitle(String text) => Text(text,
      style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700));

  Widget _panel(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.cardNested,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border)),
        child: Text(text,
            style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.5)),
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

  String _initialsOf(String name) => name
      .trim()
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0])
      .join()
      .toUpperCase();

  Widget _avatar(String name, String? photoUrl) {
    final fallback = Center(
      child: Text(_initialsOf(name),
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

/// The two figures an organizer cannot self-report.
///
/// A StatefulWidget purely so the counts are fetched **once**. The enclosing
/// user-doc stream rebuilds on every tick, and a `FutureBuilder` created
/// inside `build` — as ProfileScreen's own events count is — re-fires the
/// aggregation each time. Holding the future in State fixes that, the way
/// SettingsScreen memoises its futures in fields.
///
/// One future for both counts, so the two boxes cannot disagree mid-load.
/// Both queries are single-field equality aggregations, which the automatic
/// index serves — adding an `orderBy` here would demand a composite index.
class _TrackRecord extends StatefulWidget {
  final String organizerId;
  const _TrackRecord({required this.organizerId});

  @override
  State<_TrackRecord> createState() => _TrackRecordState();
}

class _TrackRecordState extends State<_TrackRecord> {
  late Future<List<int>> _counts;

  @override
  void initState() {
    super.initState();
    _counts = _load();
  }

  Future<List<int>> _load() {
    Future<int> countOf(String collection) => FirebaseFirestore.instance
        .collection(collection)
        .where('organizerId', isEqualTo: widget.organizerId)
        .count()
        .get()
        .then((s) => s.count ?? 0);
    return Future.wait([countOf('events'), countOf('tournaments')]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: _counts,
      builder: (context, snap) {
        // A dash rather than a zero while loading or on error: "0 events" is a
        // claim about this organizer, and an unresolved read has not earned it.
        final ok = snap.hasData && !snap.hasError;
        final events = ok ? '${snap.data![0]}' : '—';
        final tournaments = ok ? '${snap.data![1]}' : '—';
        return Row(children: [
          ProfileStatBox(
              value: events, label: 'Events Created', isAccent: true),
          const SizedBox(width: 8),
          ProfileStatBox(
              value: tournaments, label: 'Tournaments Run', isAccent: true),
        ]);
      },
    );
  }
}
