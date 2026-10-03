// lib/widgets/recruitment_badge.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/team_invite.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../utils/recruitment_status.dart';
import '../utils/team_name.dart';
import 'member_profiles.dart';

/// The recruitment pill under an athlete's name, shared by the profile sheet
/// and the full athlete profile. A closed athlete who has a team shows that
/// team instead of "Not Available" — see [recruitmentBadge].
class RecruitmentBadge extends StatefulWidget {
  final String athleteId;
  final bool isOpen;

  /// The full profile's slightly smaller pill, which sits beside the avatar
  /// rather than centred under it.
  final bool compact;

  const RecruitmentBadge({
    super.key,
    required this.athleteId,
    required this.isOpen,
    this.compact = false,
  });

  @override
  State<RecruitmentBadge> createState() => _RecruitmentBadgeState();
}

class _RecruitmentBadgeState extends State<RecruitmentBadge> {
  /// Held across rebuilds so a parent rebuild doesn't re-subscribe and re-read
  /// the athlete's memberships.
  Stream<QuerySnapshot>? _teams;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(RecruitmentBadge old) {
    super.didUpdateWidget(old);
    if (old.athleteId != widget.athleteId || old.isOpen != widget.isOpen) {
      _subscribe();
    }
  }

  // An open athlete reads as open whatever teams they have, so the lookup is
  // skipped and they cost no reads.
  void _subscribe() => _teams = widget.isOpen || widget.athleteId.isEmpty
      ? null
      : TeamService.streamAthleteTeams(widget.athleteId);

  @override
  Widget build(BuildContext context) {
    final teams = _teams;
    if (teams == null) {
      return _pill(recruitmentBadge(isOpen: widget.isOpen, teamNames: const []));
    }

    final unavailable = recruitmentBadge(isOpen: false, teamNames: const []);
    return StreamBuilder<QuerySnapshot>(
      stream: teams,
      builder: (context, snap) {
        if (snap.hasError) return _pill(unavailable);
        // Held invisible until the teams arrive, so the pill doesn't read
        // "Not Available" for a moment and then change.
        if (!snap.hasData) {
          return Visibility.maintain(visible: false, child: _pill(unavailable));
        }

        final memberships = snap.data!.docs
            .map((d) =>
                TeamInvite.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList();
        if (memberships.isEmpty) return _pill(unavailable);

        // The membership holds the team name as it was at invite time; the
        // coach's live profile has the current one. See utils/team_name.dart.
        return MemberProfilesBuilder(
          uids: memberships.map((m) => m.coachId).toList(),
          builder: (context, coaches) => _pill(recruitmentBadge(
            isOpen: false,
            teamNames: [
              for (final m in memberships)
                liveTeamName(
                    coachProfile: coaches[m.coachId],
                    storedTeamName: m.teamName,
                    coachName: m.coachName),
            ],
          )),
        );
      },
    );
  }

  Widget _pill(RecruitmentBadgeInfo badge) {
    final (Color fg, Color border, Color bg, IconData icon) = switch (
        badge.kind) {
      RecruitmentKind.open => (
          AppTheme.successText,
          AppTheme.successText,
          AppTheme.successSurface,
          Icons.check_circle_rounded,
        ),
      RecruitmentKind.onTeam => (
          AppTheme.accentText,
          AppTheme.accent,
          AppTheme.accentSurface,
          LucideIcons.users,
        ),
      RecruitmentKind.unavailable => (
          AppTheme.muted,
          AppTheme.border,
          AppTheme.cardNested,
          Icons.cancel_rounded,
        ),
    };
    final compact = widget.compact;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: 5),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: fg, size: compact ? 13 : 14),
        SizedBox(width: compact ? 5 : 6),
        // A long team name, or one per sport, ellipsises rather than pushing
        // past the avatar on the full profile.
        Flexible(
          child: Text(badge.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: fg,
                  fontSize: compact ? 10.5 : 11,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
