// lib/screens/team/athlete_team_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/team_invite.dart';
import '../../services/team_service.dart';
import '../../widgets/athlete_profile_sheet.dart';
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

  String _relativeDate(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 7) return DateFormat('MMM dd').format(date);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
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
        if (_teamName.isNotEmpty)
          Text(_teamName, style: TextStyle(color: AppTheme.sub, fontSize: 12)),
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
                invite: self,
                identity: identity,
                isSelf: true,
                relativeDate: _relativeDate,
                onTap: () => Get.toNamed('/profile'),
              ));
            }
            rows.addAll(teammates.map((m) {
              final identity = resolveMemberIdentity(profiles[m.athleteId],
                  fallbackName: m.athleteName,
                  fallbackPhotoUrl: m.athletePhotoUrl);
              return _TeammateCard(
                invite: m,
                identity: identity,
                relativeDate: _relativeDate,
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
  final TeamInvite invite;
  /// Live name/photo; `invite` still owns the membership facts (join date).
  final MemberIdentity identity;
  final String Function(DateTime?) relativeDate;
  final VoidCallback onTap;

  /// True for the viewer's own membership. Marked the same way
  /// leaderboard_screen.dart marks the viewer in a list of people: name
  /// tinted gold, plus a "YOU" pill next to it.
  final bool isSelf;

  const _TeammateCard({
    required this.invite,
    required this.identity,
    required this.relativeDate,
    required this.onTap,
    this.isSelf = false,
  });

  String get _initials {
    final parts = identity.name.trim().split(' ')
        .where((p) => p.isNotEmpty).take(2);
    return parts.map((p) => p[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
    ),
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
            child: identity.photoUrl != null &&
                    identity.photoUrl!.isNotEmpty
                ? Image.network(identity.photoUrl!, fit: BoxFit.cover,
                    width: 42, height: 42,
                    errorBuilder: (_, __, ___) => Center(
                        child: Text(_initials, style: const TextStyle(
                            color: AppTheme.buttonFg, fontSize: 14,
                            fontWeight: FontWeight.w800))))
                : Center(child: Text(_initials, style: const TextStyle(
                    color: AppTheme.buttonFg, fontSize: 14,
                    fontWeight: FontWeight.w800))),
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
            const SizedBox(height: 2),
            Text('Member since ${relativeDate(invite.respondedAt)}',
                style: TextStyle(color: AppTheme.sub, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ],
        )),
        Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
      ]),
    ),
  );
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

