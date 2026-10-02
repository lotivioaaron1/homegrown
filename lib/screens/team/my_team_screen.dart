// lib/screens/team/my_team_screen.dart

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../models/team_invite.dart';
import '../../services/team_service.dart';
import '../../widgets/athlete_profile_sheet.dart';
import '../../widgets/championships.dart';
import '../../widgets/member_profiles.dart';
import '../../utils/error_messages.dart';
import '../../utils/roster_labels.dart';
import '../../utils/sports.dart';
import '../../utils/team_name.dart';

class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});
  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Held rather than rebuilt in build(): a fresh stream on every setState
  // (the logo upload spinner, for one) resubscribes the StreamBuilder and
  // flashes it back to its waiting state.
  late final Stream<QuerySnapshot> _rosterStream =
      TeamService.streamRoster(_uid);
  late final Stream<DocumentSnapshot> _profileStream =
      FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
  late final Stream<QuerySnapshot> _pendingCountStream =
      TeamService.streamSentPending(_uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        _buildTopBar(),
        Expanded(
          // One roster subscription feeds both the team card's capacity strip
          // and the list, so the two can never disagree about the count.
          child: StreamBuilder<QuerySnapshot>(
            stream: _rosterStream,
            builder: (context, snapshot) {
              final waiting =
                  snapshot.connectionState == ConnectionState.waiting;
              final members = (snapshot.data?.docs ?? [])
                  .map((d) => TeamInvite.fromMap(
                      d.id, d.data() as Map<String, dynamic>))
                  .toList()
                ..sort((a, b) => (b.respondedAt ?? DateTime(0))
                    .compareTo(a.respondedAt ?? DateTime(0)));

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _buildTeamIdentityCard(
                      rosterCount: waiting ? null : members.length),
                  // The team's titles; nothing until it has won one.
                  TeamTitlesRow(coachId: _uid),
                  const SizedBox(height: 20),
                  _buildSectionLabel('ROSTER'),
                  const SizedBox(height: 10),
                  _buildRosterSection(waiting: waiting, members: members),
                ]),
              );
            },
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
        stream: _pendingCountStream,
        builder: (context, snapshot) {
          final pending = snapshot.data?.docs.length ?? 0;
          return Tooltip(
            message: 'Pending invites',
            child: GestureDetector(
              onTap: _showPendingInvitesSheet,
              behavior: HitTestBehavior.opaque,
              // 38pt to match the back button, inside a 44pt touch area.
              child: Padding(
                padding: const EdgeInsets.all(3),
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
                            color: AppTheme.error,
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
              ),
            ),
          );
        },
      ),
    ]),
  );

  // ── Team identity (name + logo + capacity) ─

  bool _uploadingLogo = false;

  /// [rosterCount] is null while the roster is still loading.
  Widget _buildTeamIdentityCard({required int? rosterCount}) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        // The name athletes see on invites; "Coach {name}'s team" when the
        // coach never set one, instead of an empty title.
        final storedName = (data['teamOrganization'] as String? ?? '').trim();
        final teamName = teamDisplayName(
            teamOrganization: storedName,
            coachName: data['fullName'] as String?);
        final logoUrl = data['teamLogoUrl'] as String?;
        // What the team plays. The camera badge on the logo now carries the
        // "you can change this" cue, so the hint only returns when there is
        // no sport to show in its place.
        final sports = sportsOf(data);

        return Material(
          color: AppTheme.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.border)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            child: Column(children: [
              Row(children: [
                _buildLogo(logoUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(teamName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 20,
                            fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 4),
                    sports.isEmpty
                        ? Text('Tap the logo to change it', style: TextStyle(
                            color: AppTheme.muted, fontSize: 12))
                        : Text(sports.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppTheme.sub, fontSize: 13,
                                fontWeight: FontWeight.w600)),
                  ]),
                ),
                IconButton(
                  // Pre-filled with the stored name, not the fallback, so a
                  // coach who never named the team starts from an empty box.
                  onPressed: () => _renameTeam(storedName),
                  tooltip: 'Rename team',
                  // accentText, not accent: raw gold on the light theme's
                  // white card is too faint for a control.
                  icon: Icon(Icons.edit_outlined,
                      color: AppTheme.accentText, size: 18),
                  constraints:
                      const BoxConstraints.tightFor(width: 44, height: 44),
                  padding: EdgeInsets.zero,
                ),
              ]),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(height: 1, color: AppTheme.border),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                // Holds its height while the roster loads, so the card does
                // not grow under the user's thumb when the count arrives.
                child: Visibility(
                  visible: rosterCount != null,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: _CapacityStrip(count: rosterCount ?? 0),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildLogo(String? logoUrl) {
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;
    return Semantics(
      button: true,
      label: hasLogo ? 'Change team logo' : 'Add team logo',
      child: GestureDetector(
        onTap: _uploadingLogo ? null : _pickAndUploadLogo,
        child: SizedBox(
          width: 72, height: 72,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: AppTheme.cardNested,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border)),
              child: _uploadingLogo
                  ? const Center(child: SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: AppTheme.accent, strokeWidth: 2)))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: hasLogo
                          ? CachedNetworkImage(
                              imageUrl: logoUrl,
                              fit: BoxFit.cover,
                              width: 72, height: 72,
                              memCacheWidth: 216,
                              errorWidget: (_, __, ___) => Icon(
                                  Icons.shield_outlined,
                                  color: AppTheme.muted, size: 30))
                          : Icon(Icons.add_photo_alternate_outlined,
                              color: AppTheme.muted, size: 30)),
            ),
            if (!_uploadingLogo)
              Positioned(
                right: -4, bottom: -4,
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.card, width: 2)),
                  child: const Icon(Icons.photo_camera_rounded,
                      color: AppTheme.buttonFg, size: 12),
                ),
              ),
          ]),
        ),
      ),
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
      if (mounted) _showError(e);
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
            child: const Text('Save', style: TextStyle(
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
          const _GrabHandle(),
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

  Widget _buildRosterSection({
    required bool waiting,
    required List<TeamInvite> members,
  }) {
    if (waiting) {
      return const Center(child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 2)));
    }

    if (members.isEmpty) {
      return _EmptyCard(
        icon: Icons.groups_outlined,
        title: 'No athletes on your roster yet',
        subtitle: 'Invite athletes from Scout',
        actionLabel: 'Go to Scout',
        onAction: () => Get.toNamed('/scout'),
      );
    }

    // A full roster has nowhere to put another player, so the row that would
    // only lead to Scout's "team is full" error is left out; the capacity
    // strip above already says why.
    final hasRoom = members.length < TeamService.maxPlayers;

    // The membership doc's name/photo are invite-time copies, so the
    // roster is rendered from the live user docs instead.
    return MemberProfilesBuilder(
      uids: members.map((m) => m.athleteId).toList(),
      builder: (context, profiles) => Column(children: [
        for (final m in members)
          Builder(builder: (context) {
            final profile = profiles[m.athleteId];
            final identity = resolveMemberIdentity(profile,
                fallbackName: m.athleteName,
                fallbackPhotoUrl: m.athletePhotoUrl);
            return _RosterCard(
              key: ValueKey(m.id),
              identity: identity,
              subtitle: memberSubtitle(profile?['position'] as String?,
                  joinedLabel(m.respondedAt)),
              onTap: () => _showAthleteProfile(m.athleteId),
              onMore: () => _showMemberActions(m, identity.name),
            );
          }),
        if (hasRoom) _AddPlayerRow(onTap: () => Get.toNamed('/scout')),
      ]),
    );
  }

  /// The row's ⋮ menu. Removing a player is rare and can't be undone without
  /// a fresh invite, so it sits one step back here instead of as a red
  /// button on every row of the list.
  void _showMemberActions(TeamInvite invite, String athleteName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              // Left-aligned like the actions below it; only the handle
              // centres.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Center(child: _GrabHandle()),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Text(athleteName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ),
            _SheetAction(
              icon: Icons.person_outline_rounded,
              label: 'View profile',
              color: AppTheme.textPrimary,
              onTap: () {
                Navigator.pop(sheetContext);
                _showAthleteProfile(invite.athleteId);
              },
            ),
            _SheetAction(
              icon: Icons.person_remove_rounded,
              label: 'Remove from team',
              color: AppTheme.errorText,
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmRemove(invite, athleteName);
              },
            ),
          ]),
        ),
      ),
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
          return const _EmptyCard(
            icon: Icons.mail_outline_rounded,
            title: 'No pending invites',
            subtitle: 'Invites you send will show up here until answered',
          );
        }

        return MemberProfilesBuilder(
          uids: invites.map((inv) => inv.athleteId).toList(),
          builder: (context, profiles) =>
              Column(children: invites.map((inv) => _PendingCard(
                key: ValueKey(inv.id),
                invite: inv,
                identity: resolveMemberIdentity(profiles[inv.athleteId],
                    fallbackName: inv.athleteName,
                    fallbackPhotoUrl: inv.athletePhotoUrl),
                onCancel: () => TeamService.cancelInvite(inv.id),
              )).toList()),
        );
      },
    );
  }

  void _confirmRemove(TeamInvite invite, String athleteName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove $athleteName?', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        // Not invite.teamName: that is the copy taken when the invite was
        // sent, and showed a renamed team (or a placeholder) by its old name.
        content: Text(
            "They'll need a new invite to rejoin your team.",
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await TeamService.removeMember(invite.id);
                if (mounted) {
                  Get.snackbar('Player removed',
                      '$athleteName is no longer on your roster',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppTheme.card,
                      colorText: AppTheme.textPrimary,
                      margin: const EdgeInsets.all(16), borderRadius: 12);
                }
              } catch (e) {
                if (mounted) _showError(e);
              }
            },
            child: Text('Remove', style: TextStyle(
                color: AppTheme.errorText, fontSize: 14,
                fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showError(Object e) {
    Get.snackbar('Error', friendlyError(e),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorSurface,
        colorText: AppTheme.errorText,
        margin: const EdgeInsets.all(16), borderRadius: 12);
  }

  // ── Athlete profile sheet ──────────────────
  // Read-only view of a roster athlete's profile — the same shared sheet
  // Scout and Leaderboard use, minus the recruitment badge and Invite
  // button (not relevant once they're already on the roster, since this
  // caller passes no trailingActionBuilder).

  void _showAthleteProfile(String athleteId) {
    showAthleteProfileSheet(context, athleteId: athleteId);
  }
}

// ─────────────────────────────────────────────
// Team card parts
// ─────────────────────────────────────────────

/// "5 of 15 players · 10 spots open" over a bar that fills gold, and red once
/// the roster is full. The fill eases to its new width when a player joins or
/// leaves, which is the one piece of motion on this screen.
class _CapacityStrip extends StatelessWidget {
  final int count;
  const _CapacityStrip({required this.count});

  @override
  Widget build(BuildContext context) {
    const max = TeamService.maxPlayers;
    final full = count >= max;
    final fill = (count / max).clamp(0.0, 1.0);
    final motion = !MediaQuery.of(context).disableAnimations;

    return Column(children: [
      Row(children: [
        Expanded(
          child: Text('$count of $max players',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        // Unwrapped so it sits flush right: its longest form, "14 spots
        // open", is short enough that the left label gives way first.
        Text(openSpotsLabel(count, max),
            style: TextStyle(
                color: full ? AppTheme.errorText : AppTheme.sub,
                fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: 6,
          color: AppTheme.border,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: fill),
            duration: motion
                ? const Duration(milliseconds: 300)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FractionallySizedBox(
              widthFactor: value,
              heightFactor: 1,
              child: ColoredBox(
                  color: full ? AppTheme.error : AppTheme.accent),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) => Container(
      width: 40, height: 4,
      decoration: BoxDecoration(color: AppTheme.border,
          borderRadius: BorderRadius.circular(2)));
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(
              color: color, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// Cards
// ─────────────────────────────────────────────

/// Gold-gradient circle with the member's photo, or their initials when there
/// is none — the same avatar the home screen's roster rows use.
class _Avatar extends StatelessWidget {
  final MemberIdentity identity;

  const _Avatar({required this.identity});

  static const double size = 42;

  String get _initials => identity.name.trim().split(' ')
      .where((p) => p.isNotEmpty).take(2)
      .map((p) => p[0]).join().toUpperCase();

  @override
  Widget build(BuildContext context) {
    final initials = Center(child: Text(_initials, style: const TextStyle(
        color: AppTheme.buttonFg, fontSize: size / 3,
        fontWeight: FontWeight.w800)));
    final url = identity.photoUrl;
    return Container(
      width: size, height: size,
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
                width: size, height: size,
                placeholder: (_, __) => initials,
                errorWidget: (_, __, ___) => initials)
            : initials,
      ),
    );
  }
}

class _RosterCard extends StatelessWidget {
  /// Live name/photo, so a renamed athlete shows their current name.
  final MemberIdentity identity;

  /// "Point Guard · Joined Sep 6", already composed by the caller.
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _RosterCard({
    super.key,
    required this.identity,
    required this.subtitle,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) => Padding(
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
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(children: [
            _Avatar(identity: identity),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(identity.name, style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 15,
                    fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(color: AppTheme.sub, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            )),
            IconButton(
              onPressed: onMore,
              tooltip: 'Options for ${identity.name}',
              icon: Icon(Icons.more_vert_rounded,
                  color: AppTheme.muted, size: 20),
              constraints:
                  const BoxConstraints.tightFor(width: 48, height: 48),
              padding: EdgeInsets.zero,
            ),
          ]),
        ),
      ),
    ),
  );
}

/// Closes the roster while there is room, matching the home screen deck's
/// "Add player from Scout" row (a private widget in team_carousel.dart).
class _AddPlayerRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPlayerRow({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.cardNested,
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
            decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accent)),
            child: Icon(Icons.add_rounded,
                color: AppTheme.accentText, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Add player from Scout', style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 14,
                fontWeight: FontWeight.w700)),
          ),
          Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
        ]),
      ),
    ),
  );
}

class _PendingCard extends StatelessWidget {
  final TeamInvite invite;
  final MemberIdentity identity;
  final VoidCallback onCancel;

  const _PendingCard({
    super.key,
    required this.invite,
    required this.identity,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(children: [
      _Avatar(identity: identity),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(identity.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 15,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(invitedLabel(invite.createdAt),
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
          child: Text(actionLabel!, style: const TextStyle(
              color: AppTheme.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    ]),
  );
}
