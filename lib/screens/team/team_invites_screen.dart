// lib/screens/team/team_invites_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/team_invite.dart';
import '../../services/team_service.dart';
import '../../widgets/coach_profile_sheet.dart';

class TeamInvitesScreen extends StatefulWidget {
  const TeamInvitesScreen({super.key});
  @override
  State<TeamInvitesScreen> createState() => _TeamInvitesScreenState();
}

class _TeamInvitesScreenState extends State<TeamInvitesScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _highlightId;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) _highlightId = args['inviteId'] as String?;
  }

  Future<void> _acceptInvite(String inviteId) async {
    try {
      await TeamService.acceptInvite(inviteId);
    } on TeamFullException {
      Get.snackbar('Team Full',
          'Sorry — this team just reached its roster limit.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.card,
          colorText: AppTheme.textPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 3));
    } on AlreadyOnTeamException catch (e) {
      // One team per sport. Both coaches can invite before either invite is
      // answered, so this is where a conflicting pair gets resolved — the
      // athlete keeps whichever they accepted first, and leaving that team
      // from "My Teams" below frees them to accept this one.
      Get.snackbar('Already on a Team',
          "You're already playing for ${e.teamName}. Leave that team first "
          'if you want to join this one.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.card,
          colorText: AppTheme.textPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 4));
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

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildSectionLabel('PENDING INVITES'),
              const SizedBox(height: 10),
              _buildPendingSection(),
              const SizedBox(height: 24),
              _buildSectionLabel('MY TEAMS'),
              const SizedBox(height: 10),
              _buildTeamsSection(),
            ]),
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
      Text('Team Invites', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _buildSectionLabel(String label) => Text(label, style: TextStyle(
      color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w800,
      letterSpacing: 1));

  // ── Pending invites ────────────────────────

  Widget _buildPendingSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: TeamService.streamReceivedPending(_uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2)));
        }
        final invites = (snapshot.data?.docs ?? [])
            .map((d) => TeamInvite.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0)));

        if (invites.isEmpty) {
          return const _EmptyCard(
              icon: Icons.mail_outline_rounded,
              title: 'No pending invites',
              subtitle: 'Coaches who invite you will show up here');
        }

        return Column(children: invites.map((inv) => _InviteCard(
          invite: inv,
          highlighted: inv.id == _highlightId,
          onAccept: () => _acceptInvite(inv.id),
          onDecline: () => TeamService.declineInvite(inv.id),
          relativeDate: _relativeDate,
        )).toList());
      },
    );
  }

  // ── My teams ───────────────────────────────

  Widget _buildTeamsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: TeamService.streamAthleteTeams(_uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2)));
        }
        final teams = (snapshot.data?.docs ?? [])
            .map((d) => TeamInvite.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => (b.respondedAt ?? DateTime(0))
              .compareTo(a.respondedAt ?? DateTime(0)));

        if (teams.isEmpty) {
          return const _EmptyCard(
              icon: Icons.groups_outlined,
              title: "You're not on a team yet",
              subtitle: 'Accept an invite above to join one');
        }

        return Column(children: teams.map((t) => _TeamCard(
          invite: t,
          relativeDate: _relativeDate,
          onLeave: () => _confirmLeave(t),
          onTap: () => Get.toNamed('/team/mine', arguments: {
            'coachId': t.coachId,
            'coachName': t.coachName,
            'teamName': t.teamName,
          }),
        )).toList());
      },
    );
  }

  void _confirmLeave(TeamInvite invite) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Leave ${invite.teamName}?', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
            "You'll need a new invite from ${invite.coachName} to rejoin.",
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              TeamService.leaveTeam(invite.id);
            },
            child: const Text('Leave', style: TextStyle(
                color: Color(0xFFFF5C5C), fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Cards
// ─────────────────────────────────────────────

class _InviteCard extends StatelessWidget {
  final TeamInvite invite;
  final bool highlighted;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String Function(DateTime?) relativeDate;

  const _InviteCard({
    required this.invite,
    required this.highlighted,
    required this.onAccept,
    required this.onDecline,
    required this.relativeDate,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: highlighted ? AppTheme.accent : AppTheme.border,
          width: highlighted ? 2 : 1),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(invite.teamName, style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      // The coach is the thing being decided on here, so their name opens
      // their profile rather than sitting as dead text. Before this, an
      // athlete had to accept an invite to find out who had sent it — while
      // the coach had already seen their whole portfolio in Scout.
      GestureDetector(
        onTap: () => showCoachProfileSheet(context,
            coachId: invite.coachId, fallbackName: invite.coachName),
        behavior: HitTestBehavior.opaque,
        child: Row(children: [
          Flexible(
            child: Text(
                'Invited by ${invite.coachName} · ${relativeDate(invite.createdAt)}',
                style: TextStyle(
                    color: AppTheme.accentText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          Icon(Icons.chevron_right_rounded, color: AppTheme.accentText, size: 16),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: SizedBox(
          height: 42,
          child: ElevatedButton(
            onPressed: onAccept,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success, foregroundColor: Colors.white),
            child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        )),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(
          height: 42,
          child: OutlinedButton(
            onPressed: onDecline,
            child: Text('Decline', style: TextStyle(color: AppTheme.sub)),
          ),
        )),
      ]),
    ]),
  );
}

class _TeamCard extends StatelessWidget {
  final TeamInvite invite;
  final String Function(DateTime?) relativeDate;
  final VoidCallback onLeave;
  final VoidCallback onTap;

  const _TeamCard({
    required this.invite,
    required this.relativeDate,
    required this.onLeave,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(children: [
      Expanded(child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(invite.teamName, style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('Coach ${invite.coachName} · Member since ${relativeDate(invite.respondedAt)}',
              style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        ]),
      )),
      TextButton(
        onPressed: onLeave,
        child: const Text('Leave', style: TextStyle(
            color: Color(0xFFFF5C5C), fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyCard({required this.icon, required this.title, required this.subtitle});

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
