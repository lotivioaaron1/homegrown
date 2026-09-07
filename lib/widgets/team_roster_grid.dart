// lib/widgets/team_roster_grid.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/team_invite.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import 'member_profiles.dart';

/// A team's players as a wrap of avatars with names.
///
/// Shared by the coach's public profile ([CoachProfileViewScreen]) and the
/// coach's own profile ([ProfileScreen]), which is the point: the same faces
/// rendered by the same code, so the two screens cannot drift apart. They did
/// drift before — the public profile showed a roster the coach could not see
/// on their own profile, which read as the players having been removed.
///
/// Takes an already-loaded [members] list rather than opening its own stream,
/// so a caller that already listens to `TeamService.streamRoster` (both of
/// them do, for the player count) feeds this from that one listener instead of
/// starting a second one that could disagree with it.
class TeamRosterGrid extends StatelessWidget {
  final List<TeamInvite> members;
  final bool loading;

  /// Shown in place of the grid when the roster is empty. The two callers word
  /// this differently — a coach reads about their own team, a visitor about
  /// someone else's.
  final String emptyMessage;

  const TeamRosterGrid({
    super.key,
    required this.members,
    required this.loading,
    this.emptyMessage = 'No players on this team yet.',
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
          height: 64,
          child: Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2))));
    }
    if (members.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.cardNested,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border)),
        child: Text(emptyMessage,
            style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.5)),
      );
    }

    // Membership docs freeze the athlete's name and photo at invite time, so
    // the grid reads the live user docs and falls back to the snapshot only
    // while those load.
    return MemberProfilesBuilder(
      uids: members.map((m) => m.athleteId).toList(),
      builder: (context, profiles) => Wrap(
        spacing: 10,
        runSpacing: 12,
        children: members.map((m) {
          final identity = resolveMemberIdentity(profiles[m.athleteId],
              fallbackName: m.athleteName,
              fallbackPhotoUrl: m.athletePhotoUrl);
          return SizedBox(
            width: 62,
            child: Column(children: [
              _MemberAvatar(identity: identity),
              const SizedBox(height: 5),
              Text(identity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.sub,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final MemberIdentity identity;
  const _MemberAvatar({required this.identity});

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
          identity.name
              .trim()
              .split(' ')
              .where((p) => p.isNotEmpty)
              .take(2)
              .map((p) => p[0])
              .join()
              .toUpperCase(),
          style: const TextStyle(
              color: AppTheme.buttonFg,
              fontSize: 15,
              fontWeight: FontWeight.w800)),
    );
    final photoUrl = identity.photoUrl;
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.accent, AppTheme.accent2]),
          shape: BoxShape.circle),
      child: ClipOval(
        child: (photoUrl != null && photoUrl.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                memCacheWidth: 130,
                errorWidget: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}
