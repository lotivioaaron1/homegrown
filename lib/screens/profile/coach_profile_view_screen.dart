// lib/screens/profile/coach_profile_view_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/report.dart';
import '../../models/team_invite.dart';
import '../../services/team_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../utils/sports.dart';
import '../../widgets/athlete_profile_parts.dart';
import '../../widgets/report_dialog.dart';
import '../../widgets/team_roster_grid.dart';

/// A coach's profile, read-only — the counterpart to
/// [AthleteProfileViewScreen], and the answer to the athlete's side of the
/// question Scout already answers for coaches.
///
/// Coaches could inspect an athlete's whole portfolio before recruiting them,
/// while an athlete deciding on that same invite got a name in a text line.
/// [showCoachProfileSheet] stays the quick peek; this is what it opens into.
///
/// The sheet shows only what a coach typed about themselves — level, years,
/// org, certifications, bio. What this screen adds is the part that isn't
/// self-reported: the team actually exists, it has this many players on it,
/// and here is who they are. That is what an athlete is really asking before
/// accepting.
///
/// Deliberately mirrors [AthleteProfileViewScreen]'s layout — same header
/// shape, same avatar treatment, same stat-box row — so the two profiles read
/// as one family.
class CoachProfileViewScreen extends StatelessWidget {
  final String coachId;

  /// Optional caller-specific action pinned under the profile, matching
  /// AthleteProfileViewScreen's hook. Nothing passes one yet; the invite card
  /// deliberately keeps Accept/Decline on the invite itself rather than
  /// moving the decision onto this screen.
  final Widget? trailingAction;

  const CoachProfileViewScreen({
    super.key,
    required this.coachId,
    this.trailingAction,
  });

  /// Reads the id from either the constructor or the route arguments, so the
  /// screen works both as a named route (`/profile/coach`) and when pushed
  /// directly.
  static CoachProfileViewScreen fromRoute() {
    final args = Get.arguments;
    return CoachProfileViewScreen(
      coachId: (args is Map ? args['coachId'] as String? : null) ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: coachId.isEmpty
            ? _missing('No coach selected',
                'This profile was opened without a coach to show.')
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(coachId)
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
                  final coach = snap.data?.data() as Map<String, dynamic>?;
                  // A deleted account, or an invite pointing at a uid that no
                  // longer exists. Saying so beats a screen of dashes.
                  if (coach == null) {
                    return _missing('Profile unavailable',
                        'This coach is no longer on Homegrown.');
                  }
                  return _buildProfile(context, coach);
                },
              ),
      ),
    );
  }

  // ── Body ──────────────────────────────────

  Widget _buildProfile(BuildContext context, Map<String, dynamic> coach) {
    // Same resolver the rosters use: `firstName`/`lastName` win over the
    // `fullName` a pre-rename doc may still carry.
    final identity = resolveMemberIdentity(coach, fallbackName: 'Coach');
    final name = identity.name;
    final photoUrl = identity.photoUrl;
    final level = (coach['coachingLevel'] as String? ?? '').trim();
    final years = (coach['yearsOfExperience'] as String? ?? '').trim();
    final org = (coach['teamOrganization'] as String? ?? '').trim();
    final barangay = (coach['barangay'] as String? ?? '').trim();
    final certifications = (coach['certifications'] as String? ?? '').trim();
    final bio = (coach['coachingBio'] as String? ?? '').trim();
    final sports = sportsOf(coach);
    final subtitle = [
      if (level.isNotEmpty) '$level Coach',
      if (barangay.isNotEmpty) barangay,
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(children: [
          _iconButton(LucideIcons.arrowLeft, () => Get.back()),
          const SizedBox(width: 12),
          Text('Coach Profile',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          // Files a complaint into the admin console's Reports queue, exactly
          // as the athlete profile does. Hidden on your own profile, where
          // there is nothing to report.
          if (FirebaseAuth.instance.currentUser?.uid != coachId) ...[
            const Spacer(),
            _iconButton(
              LucideIcons.flag,
              () => showReportDialog(
                context,
                targetType: Report.targetUser,
                targetId: coachId,
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
                Text(name,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color: AppTheme.sub,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
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
        _team(context, coach, level: level, years: years, org: org),

        if (certifications.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle('Certifications'),
          const SizedBox(height: 8),
          _panel(certifications),
        ],

        if (trailingAction != null) ...[
          const SizedBox(height: 24),
          trailingAction!,
        ],
      ],
    );
  }

  // ── Team ──────────────────────────────────
  // One listener feeding the headline row, the team card and the roster, as
  // the athlete profile's portfolio does — three streams on the same query
  // would only invite them to disagree about the player count.

  Widget _team(
    BuildContext context,
    Map<String, dynamic> coach, {
    required String level,
    required String years,
    required String org,
  }) {
    final teamName = (coach['teamName'] as String? ?? '').trim();
    final teamLogoUrl = (coach['teamLogoUrl'] as String? ?? '').trim();

    return StreamBuilder<QuerySnapshot>(
      stream: TeamService.streamRoster(coachId),
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final members = (snap.data?.docs ?? [])
            .map((d) =>
                TeamInvite.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => (b.respondedAt ?? DateTime(0))
              .compareTo(a.respondedAt ?? DateTime(0)));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ProfileStatBox(
                value: years.isNotEmpty ? years : '—',
                label: 'Experience',
              ),
              const SizedBox(width: 8),
              ProfileStatBox(value: level.isNotEmpty ? level : '—', label: 'Level'),
              const SizedBox(width: 8),
              // The one figure on this screen the coach cannot type in.
              ProfileStatBox(
                value: loading
                    ? '—'
                    : '${members.length}/${TeamService.maxPlayers}',
                label: 'Roster',
                isAccent: true,
              ),
            ]),
            const SizedBox(height: 18),
            _sectionTitle('Team'),
            const SizedBox(height: 8),
            _teamCard(
              teamName: teamName.isNotEmpty ? teamName : org,
              logoUrl: teamLogoUrl,
              count: members.length,
              loading: loading,
            ),
            const SizedBox(height: 18),
            _sectionTitle('Players'),
            const SizedBox(height: 8),
            TeamRosterGrid(
              members: members,
              loading: loading,
              emptyMessage: 'No players on this team yet.',
            ),
          ],
        );
      },
    );
  }

  // ── Pieces ────────────────────────────────

  Widget _teamCard({
    required String teamName,
    required String logoUrl,
    required int count,
    required bool loading,
  }) =>
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
            decoration: BoxDecoration(
                color: AppTheme.cardNested,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: logoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: logoUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 150,
                      errorWidget: (_, __, ___) => Icon(Icons.shield_outlined,
                          color: AppTheme.muted, size: 22))
                  : Icon(Icons.shield_outlined,
                      color: AppTheme.muted, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(teamName.isNotEmpty ? teamName : 'Unnamed team',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                      loading
                          ? '—'
                          : '$count / ${TeamService.maxPlayers} players',
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
