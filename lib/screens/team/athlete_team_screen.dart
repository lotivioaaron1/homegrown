// lib/screens/team/athlete_team_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../models/team_invite.dart';
import '../../services/team_service.dart';
import '../../utils/roster_labels.dart';
import '../../utils/team_name.dart';
import '../../widgets/athlete_profile_sheet.dart';
import '../../widgets/championships.dart';
import '../../widgets/coach_profile_sheet.dart';
import '../../widgets/member_profiles.dart';

/// An athlete's read-only view of their own team: who their coach is and
/// who their teammates are, with tap-through to each person's profile.
/// Deliberately separate from MyTeamScreen, which is the coach's roster
/// *management* view (remove-member actions) — wrong shape and wrong
/// permissions model for an athlete looking at their own team.
class AthleteTeamScreen extends StatefulWidget {
  const AthleteTeamScreen({super.key});
  @override
  State<AthleteTeamScreen> createState() => _AthleteTeamScreenState();
}

class _AthleteTeamScreenState extends State<AthleteTeamScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _coachId = '';
  String _coachName = '';
  String _teamName = '';
  Map<String, dynamic>? _coachProfile;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final map = args is Map ? args : const {};
    _coachId = map['coachId'] as String? ?? '';
    _coachName = map['coachName'] as String? ?? '';
    _teamName = map['teamName'] as String? ?? '';
    if (_coachId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(_coachId)
          .get()
          .then((doc) {
        if (mounted) setState(() => _coachProfile = doc.data());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        _buildTopBar(),
        Expanded(
          child: _coachId.isEmpty
              ? const _EmptyCard(
                  icon: Icons.error_outline_rounded,
                  title: "Can't load this team",
                  subtitle: 'Go back and try again')
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('COACH'),
                      const SizedBox(height: 10),
                      _buildCoachCard(),
                      // The team's titles; nothing until it has won one.
                      TeamTitlesRow(coachId: _coachId),
                      const SizedBox(height: 20),
                      _buildSectionLabel('TEAMMATES'),
                      const SizedBox(height: 10),
                      _buildTeammatesSection(),
                    ],
                  ),
                ),
        ),
      ])),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border)),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 16)),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('My Team', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 18,
            fontWeight: FontWeight.w800)),
        // The coach's live team name once their profile has loaded (see
        // initState), so a rename shows here — the argument is only the copy
        // the membership carried.
        if (_teamName.isNotEmpty || _coachProfile != null)
          Text(
              liveTeamName(
                  coachProfile: _coachProfile,
                  storedTeamName: _teamName,
                  coachName: _coachName),
              style: TextStyle(color: AppTheme.sub, fontSize: 12)),
      ]),
    ]),
  );

  Widget _buildSectionLabel(String label) => Text(label, style: TextStyle(
      color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w800,
      letterSpacing: 1));

  // ── Coach ──────────────────────────────────

  Widget _buildCoachCard() {
    final name = _coachProfile?['fullName'] as String? ?? _coachName;
    final level = _coachProfile?['coachingLevel'] as String? ?? '';
    final barangay = _coachProfile?['barangay'] as String? ?? '';
    final photoUrl = _coachProfile?['photoUrl'] as String?;
    final subtitle = [if (level.isNotEmpty) '$level Coach', if (barangay.isNotEmpty) barangay]
        .join(' · ');
    final initials = name.trim().split(' ')
        .where((p) => p.isNotEmpty).take(2)
        .map((p) => p[0]).join().toUpperCase();

    return GestureDetector(
      onTap: _showCoachProfile,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppTheme.accent, AppTheme.accent2]),
              shape: BoxShape.circle),
            child: ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(photoUrl, fit: BoxFit.cover, width: 42, height: 42,
                      errorBuilder: (_, __, ___) => Center(child: Text(initials,
                          style: const TextStyle(color: AppTheme.buttonFg,
                              fontSize: 14, fontWeight: FontWeight.w800))))
                  : Center(child: Text(initials, style: const TextStyle(
                      color: AppTheme.buttonFg, fontSize: 14, fontWeight: FontWeight.w800))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: AppTheme.sub, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
        ]),
      ),
    );
  }

  void _showCoachProfile() => showCoachProfileSheet(
        context,
        coachId: _coachId,
        coach: _coachProfile,
        fallbackName: _coachName,
      );

  // ── Teammates ──────────────────────────────

  Widget _buildTeammatesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: TeamService.streamRoster(_coachId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2)));
        }
        final everyone = (snapshot.data?.docs ?? [])
            .map((d) => TeamInvite.fromMap(d.id, d.data() as Map<String, dynamic>));
        final self = everyone.where((m) => m.athleteId == _uid).firstOrNull;
        final teammates = everyone.where((m) => m.athleteId != _uid).toList()
          ..sort((a, b) => (b.respondedAt ?? DateTime(0))
              .compareTo(a.respondedAt ?? DateTime(0)));

        // Keyed off teammates, not the full roster: a solo athlete should see
        // this message, not a lone card of themselves — it's the more useful
        // content there. (The home screen's deck still shows coach + you in
        // that case, which reads fine as a two-card deck.)
        if (teammates.isEmpty) {
          return const _EmptyCard(
            icon: Icons.groups_outlined,
            title: 'No teammates yet',
            subtitle: "You're currently the only athlete on this team");
        }

        // Membership docs freeze the athlete's name/photo at invite time, so
        // the roster reads the live user docs instead. The viewer's own uid
        // is included so their card gets the same live-photo treatment.
        return MemberProfilesBuilder(
          uids: [
            if (self != null) _uid,
            ...teammates.map((m) => m.athleteId),
          ],
          builder: (context, profiles) {
            final rows = <Widget>[];
            if (self != null) {
              final identity = resolveMemberIdentity(profiles[_uid],
                  fallbackName: self.athleteName,
                  fallbackPhotoUrl: self.athletePhotoUrl);
              rows.add(_TeammateCard(
                key: ValueKey(self.id),
                identity: identity,
                subtitle: memberSubtitle(
                    profiles[_uid]?['position'] as String?,
                    joinedLabel(self.respondedAt)),
                isSelf: true,
                onTap: () => Get.toNamed('/profile'),
              ));
            }
            rows.addAll(teammates.map((m) {
              final identity = resolveMemberIdentity(profiles[m.athleteId],
                  fallbackName: m.athleteName,
                  fallbackPhotoUrl: m.athletePhotoUrl);
              return _TeammateCard(
                key: ValueKey(m.id),
                identity: identity,
                subtitle: memberSubtitle(
                    profiles[m.athleteId]?['position'] as String?,
                    joinedLabel(m.respondedAt)),
                onTap: () => _showAthleteProfile(m.athleteId),
              );
            }));
            return Column(children: rows);
          },
        );
      },
    );
  }

  // ── Athlete profile sheet ──────────────────
  // This screen carried its own hand-rolled copy of the athlete profile
  // sheet, written before showAthleteProfileSheet existed. Delegating to the
  // shared one keeps a teammate's profile identical to the one a coach sees
  // from Scout — and means the highlights teaser and the full-profile route
  // reach teammates without this file knowing anything about media.
  void _showAthleteProfile(String athleteId) =>
      showAthleteProfileSheet(context, athleteId: athleteId);
}

// ─────────────────────────────────────────────
// Cards
// ─────────────────────────────────────────────

class _TeammateCard extends StatelessWidget {
  /// Live name/photo, so a renamed teammate shows their current name.
  final MemberIdentity identity;

  /// "Point Guard · Joined Sep 6", already composed by the caller.
  final String subtitle;
  final VoidCallback onTap;

  /// True for the viewer's own membership. Marked the same way
  /// leaderboard_screen.dart marks the viewer in a list of people: name
  /// tinted gold, plus a "YOU" pill next to it.
  final bool isSelf;

  const _TeammateCard({
    super.key,
    required this.identity,
    required this.subtitle,
    required this.onTap,
    this.isSelf = false,
  });

  String get _initials {
    final parts = identity.name.trim().split(' ')
        .where((p) => p.isNotEmpty).take(2);
    return parts.map((p) => p[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = Center(child: Text(_initials, style: const TextStyle(
        color: AppTheme.buttonFg, fontSize: 14, fontWeight: FontWeight.w800)));
    final url = identity.photoUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppTheme.border)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.accent, AppTheme.accent2]),
                  shape: BoxShape.circle),
                child: ClipOval(
                  child: url != null && url.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: url, fit: BoxFit.cover,
                          width: 42, height: 42,
                          placeholder: (_, __) => initials,
                          errorWidget: (_, __, ___) => initials)
                      : initials,
                )),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(identity.name, style: TextStyle(
                        color: isSelf ? AppTheme.accent : AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis)),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('YOU', style: TextStyle(
                            color: AppTheme.buttonFg, fontSize: 8,
                            fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ]),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: AppTheme.sub, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              )),
              Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(children: [
      Icon(icon, color: AppTheme.muted, size: 30),
      const SizedBox(height: 10),
      Text(title, style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(subtitle, textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.sub, fontSize: 12)),
    ]),
  );
}

