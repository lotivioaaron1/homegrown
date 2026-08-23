// lib/screens/team/my_team_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/team_invite.dart';
import '../../services/team_service.dart';
import '../../widgets/athlete_profile_sheet.dart';

class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});
  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildTeamIdentityCard(),
              const SizedBox(height: 20),
              _buildSectionLabel('ROSTER'),
              const SizedBox(height: 10),
              _buildRosterSection(),
            ]),
          ),
        ),
      ])),
    );
  }

  // Pending Invites Sent lives behind the mail icon in the top bar
  // instead of stacked below the roster — a full 15-player roster would
  // otherwise push it far down the screen, out of easy reach.

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
      Text('My Team', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w800)),
      const Spacer(),
      StreamBuilder<QuerySnapshot>(
        stream: TeamService.streamRoster(_uid),
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          final isFull = count >= TeamService.maxPlayers;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: isFull
                    ? const Color(0xFFFF5C5C).withValues(alpha: 0.12)
                    : AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isFull ? const Color(0xFFFF5C5C) : AppTheme.accent)),
            child: Text('$count / ${TeamService.maxPlayers}', style: TextStyle(
                color: isFull ? const Color(0xFFFF5C5C) : AppTheme.accentText,
                fontSize: 13, fontWeight: FontWeight.w800)),
          );
        },
      ),
      const SizedBox(width: 8),
      StreamBuilder<QuerySnapshot>(
        stream: TeamService.streamSentPending(_uid),
        builder: (context, snapshot) {
          final pending = snapshot.data?.docs.length ?? 0;
          return GestureDetector(
            onTap: _showPendingInvitesSheet,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border)),
                child: Icon(Icons.mail_outline_rounded,
                    color: AppTheme.textPrimary, size: 18)),
              if (pending > 0)
                Positioned(
                  top: -2, right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(
                        minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFF5C5C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.card, width: 1.5)),
                    child: Center(
                      child: Text(pending > 9 ? '9+' : '$pending',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    ]),
  );

  // ── Team identity (name + logo) ───────────

  bool _uploadingLogo = false;

  Widget _buildTeamIdentityCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final teamName = data['teamOrganization'] as String? ?? 'Your Team';
        final logoUrl = data['teamLogoUrl'] as String?;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child: Row(children: [
            GestureDetector(
              onTap: _uploadingLogo ? null : _pickAndUploadLogo,
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                    color: AppTheme.cardNested,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border)),
                child: _uploadingLogo
                    ? const Center(child: CircularProgressIndicator(
                        color: AppTheme.accent, strokeWidth: 2))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: logoUrl != null && logoUrl.isNotEmpty
                            ? Image.network(logoUrl, fit: BoxFit.cover,
                                width: 56, height: 56,
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.shield_outlined,
                                    color: AppTheme.muted, size: 26))
                            : Icon(Icons.add_photo_alternate_outlined,
                                color: AppTheme.muted, size: 26)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(teamName, style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 15,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Tap the logo to change it', style: TextStyle(
                    color: AppTheme.muted, fontSize: 11)),
              ]),
            ),
            GestureDetector(
              onTap: () => _renameTeam(teamName),
              child: Icon(Icons.edit_outlined, color: AppTheme.accent, size: 18),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _pickAndUploadLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 1000, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingLogo = true);
    try {
      final url = await TeamService.uploadTeamLogo(_uid, File(picked.path));
      await FirebaseFirestore.instance.collection('users').doc(_uid)
          .update({'teamLogoUrl': url});
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', e.toString(),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF2A1A1A),
            colorText: AppTheme.error,
            margin: const EdgeInsets.all(16), borderRadius: 12);
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  void _renameTeam(String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename your team', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
              hintText: 'Team name',
              hintStyle: TextStyle(color: AppTheme.muted)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              Navigator.pop(dialogContext);
              if (name.isEmpty) return;
              await FirebaseFirestore.instance.collection('users').doc(_uid)
                  .update({'teamOrganization': name});
            },
            child: Text('Save', style: TextStyle(
                color: AppTheme.accent, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showPendingInvitesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Text('Pending Invites Sent', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 16,
                  fontWeight: FontWeight.w800)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _buildPendingSection(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSectionLabel(String label) => Text(label, style: TextStyle(
      color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w800,
      letterSpacing: 1));

  // ── Roster ─────────────────────────────────

  Widget _buildRosterSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: TeamService.streamRoster(_uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2)));
        }
        final members = (snapshot.data?.docs ?? [])
            .map((d) => TeamInvite.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => (b.respondedAt ?? DateTime(0))
              .compareTo(a.respondedAt ?? DateTime(0)));

        if (members.isEmpty) {
          return _EmptyCard(
            icon: Icons.groups_outlined,
            title: 'No athletes on your roster yet',
            subtitle: 'Invite athletes from Scout',
            actionLabel: 'Go to Scout',
            onAction: () => Get.toNamed('/scout'),
          );
        }

        return Column(children: members.map((m) => _RosterCard(
          invite: m,
          relativeDate: _relativeDate,
          onRemove: () => _confirmRemove(m),
          onTapAthlete: () => _showAthleteProfile(m.athleteId, m.athleteName),
        )).toList());
      },
    );
  }

  // ── Pending sent ───────────────────────────

  Widget _buildPendingSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: TeamService.streamSentPending(_uid),
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
          return _EmptyCard(
            icon: Icons.mail_outline_rounded,
            title: 'No pending invites',
            subtitle: 'Invites you send will show up here until answered',
          );
        }

        return Column(children: invites.map((inv) => _PendingCard(
          invite: inv,
          relativeDate: _relativeDate,
          onCancel: () => TeamService.cancelInvite(inv.id),
        )).toList());
      },
    );
  }

  void _confirmRemove(TeamInvite invite) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove ${invite.athleteName}?', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
            "They'll need a new invite to rejoin ${invite.teamName}.",
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              TeamService.removeMember(invite.id);
            },
            child: const Text('Remove', style: TextStyle(
                color: Color(0xFFFF5C5C), fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Athlete profile sheet ──────────────────
  // Read-only view of a roster athlete's profile — the same shared sheet
  // Scout and Leaderboard use, minus the recruitment badge and Invite
  // button (not relevant once they're already on the roster, since this
  // caller passes no trailingActionBuilder).

  void _showAthleteProfile(String athleteId, String athleteName) {
    showAthleteProfileSheet(context, athleteId: athleteId);
  }
}

// ─────────────────────────────────────────────
// Cards
// ─────────────────────────────────────────────

class _RosterCard extends StatelessWidget {
  final TeamInvite invite;
  final String Function(DateTime?) relativeDate;
  final VoidCallback onRemove;
  final VoidCallback onTapAthlete;

  const _RosterCard({
    required this.invite,
    required this.relativeDate,
    required this.onRemove,
    required this.onTapAthlete,
  });

  String get _initials {
    final parts = invite.athleteName.trim().split(' ')
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
    child: Row(children: [
      Expanded(child: GestureDetector(
        onTap: onTapAthlete,
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
              child: invite.athletePhotoUrl != null &&
                      invite.athletePhotoUrl!.isNotEmpty
                  ? Image.network(invite.athletePhotoUrl!, fit: BoxFit.cover,
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
              Text(invite.athleteName, style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 15,
                  fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('Member since ${relativeDate(invite.respondedAt)}',
                  style: TextStyle(color: AppTheme.sub, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      )),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onRemove,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: const Color(0xFFFF5C5C).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.person_remove_rounded,
              color: Color(0xFFFF5C5C), size: 18)),
      ),
    ]),
  );
}

class _PendingCard extends StatelessWidget {
  final TeamInvite invite;
  final String Function(DateTime?) relativeDate;
  final VoidCallback onCancel;

  const _PendingCard({
    required this.invite,
    required this.relativeDate,
    required this.onCancel,
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
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(invite.athleteName, style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('Invited ${relativeDate(invite.createdAt)}',
            style: TextStyle(color: AppTheme.sub, fontSize: 12)),
      ])),
      TextButton(
        onPressed: onCancel,
        child: Text('Cancel', style: TextStyle(color: AppTheme.sub)),
      ),
    ]),
  );
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
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
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: 14),
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel!, style: TextStyle(
              color: AppTheme.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    ]),
  );
}
