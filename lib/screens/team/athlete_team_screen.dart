// lib/screens/team/athlete_team_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/team_invite.dart';
import '../../services/team_service.dart';
import '../../utils/stat_scoring.dart';
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
              ? _EmptyCard(
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
            decoration: BoxDecoration(
              gradient: const LinearGradient(
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
          return _EmptyCard(
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
                onTap: () => _showAthleteProfile(m.athleteId, identity.name),
              );
            }));
            return Column(children: rows);
          },
        );
      },
    );
  }

  // ── Athlete profile sheet ──────────────────
  // Ported from MyTeamScreen._showAthleteProfile, plus the per-sport
  // Averages section from ScoutScreen — same "what is this teammate good
  // at" info a coach can already see, now visible to teammates too.

  Future<void> _showAthleteProfile(String athleteId, String athleteName) async {
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(athleteId).get();
    if (!mounted) return;
    final a = doc.data() ?? {};

    final position = a['position'] as String? ?? '—';
    final barangay = a['barangay'] as String? ?? '—';
    final years = a['yearsOfPlaying'] as String? ?? '—';
    final height = a['heightCm'] as String? ?? '—';
    final weight = a['weightKg'] as String? ?? '—';
    final bio = a['bio'] as String? ?? '';
    final sports = (a['primarySports'] as List?)
        ?.map((e) => e.toString()).join(', ') ?? '—';
    final pts = a['points'];
    final ptsStr = pts is num ? '${pts.toInt()}' : '0';
    // The doc was just fetched, so prefer its name over the one the caller
    // passed in — that argument may have come from a stale membership doc.
    final identity =
        resolveMemberIdentity(a, fallbackName: athleteName);
    final displayName = identity.name;
    final photoUrl = identity.photoUrl;
    final nameParts = displayName.trim().split(' ');
    final initials = nameParts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();

    if (!mounted) return;
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
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Center(child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.accent, AppTheme.accent2]),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accent, width: 2.5)),
                  child: ClipOval(
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? Image.network(photoUrl, fit: BoxFit.cover,
                            width: 72, height: 72,
                            errorBuilder: (_, __, ___) => Center(
                                child: Text(initials, style: const TextStyle(
                                    color: AppTheme.buttonFg, fontSize: 22,
                                    fontWeight: FontWeight.w900))))
                        : Center(child: Text(initials, style: const TextStyle(
                            color: AppTheme.buttonFg, fontSize: 22,
                            fontWeight: FontWeight.w900))),
                  )),
                const SizedBox(height: 10),
                Text(displayName, style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 18,
                    fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('$position · $barangay',
                    style: TextStyle(color: AppTheme.sub, fontSize: 13)),
              ])),
              const SizedBox(height: 20),
              Row(children: [
                _StatBox(value: ptsStr, label: 'Total Pts', isAccent: true),
                const SizedBox(width: 8),
                _StatBox(value: years, label: 'Experience'),
                const SizedBox(width: 8),
                _StatBox(value: '${height}cm', label: 'Height'),
                const SizedBox(width: 8),
                _StatBox(value: '${weight}kg', label: 'Weight'),
              ]),
              const SizedBox(height: 16),
              _buildStatAverages(athleteId),
              const SizedBox(height: 16),
              Divider(color: AppTheme.border),
              const SizedBox(height: 12),
              _InfoRow(label: 'Sport', value: sports),
              const SizedBox(height: 8),
              _InfoRow(label: 'Position', value: position),
              const SizedBox(height: 8),
              _InfoRow(label: 'Barangay', value: barangay),
              const SizedBox(height: 8),
              _InfoRow(label: 'Experience', value: years),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Bio', style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 12,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppTheme.cardNested,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border)),
                  child: Text(bio, style: TextStyle(
                      color: AppTheme.sub, fontSize: 13, height: 1.5))),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  child: Text('Close', style: TextStyle(
                      color: AppTheme.sub, fontSize: 14,
                      fontWeight: FontWeight.w600)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatAverages(String athleteUid) {
    if (athleteUid.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('stats')
          .where('athleteId', isEqualTo: athleteUid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 32,
            child: Center(child: SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2))));
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();

        final bySport = <String, List<Map<String, dynamic>>>{};
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final sport = data['sport'] as String? ?? '';
          final stats = (data['stats'] as Map?)?.cast<String, dynamic>() ?? {};
          bySport.putIfAbsent(sport, () => []).add(stats);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Averages', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 12,
              fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...bySport.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SportAverages(sport: e.key, games: e.value),
            )),
          ],
        );
      },
    );
  }
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
          decoration: BoxDecoration(
            gradient: const LinearGradient(
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

class _SportAverages extends StatelessWidget {
  final String sport;
  final List<Map<String, dynamic>> games;
  const _SportAverages({required this.sport, required this.games});

  String _format(String label, double value) {
    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return label == 'Win Rate %' ? '$formatted%' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final avgs = averageStats(sport, games);
    if (avgs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$sport · ${games.length} game${games.length == 1 ? '' : 's'}',
          style: TextStyle(color: AppTheme.sub, fontSize: 11,
              fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: avgs.entries.map((e) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.cardNested,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.key, style: TextStyle(color: AppTheme.muted, fontSize: 9)),
                Text(_format(e.key, e.value), style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13,
                    fontWeight: FontWeight.w800)),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final bool isAccent;
  const _StatBox({required this.value, required this.label,
      this.isAccent = false});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isAccent ? AppTheme.accentSurface : AppTheme.cardNested,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAccent ? AppTheme.accent : AppTheme.border)),
      child: Column(children: [
        Text(value, style: TextStyle(
          color: isAccent ? AppTheme.accentText : AppTheme.textPrimary,
          fontSize: 14, fontWeight: FontWeight.w900),
          overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
            color: AppTheme.muted, fontSize: 9),
            overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 90, child: Text(label, style: TextStyle(
      color: AppTheme.muted, fontSize: 12))),
    Expanded(child: Text(value, style: TextStyle(
      color: AppTheme.textPrimary, fontSize: 13,
      fontWeight: FontWeight.w600),
      overflow: TextOverflow.ellipsis)),
  ]);
}
