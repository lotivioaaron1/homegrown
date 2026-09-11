// lib/utils/team_name.dart

// Which name to show for a coach's team, as a pure decision.
//
// Two things went wrong with team names. The name was optional at coach
// sign-up, so a coach could have none — and Scout then sent invites with the
// literal placeholder "your team", which athletes saw as "Coach Ana wants you
// for your team". And each membership copied the name when the invite was
// sent, so a coach renaming their team changed nothing athletes could see.

/// The placeholder Scout used to write when a coach had no team name. Invites
/// already sent with it are treated as having no name at all.
const String _kLegacyPlaceholder = 'your team';

/// [teamOrganization] if it is a real name, otherwise "Coach {first name}'s
/// team", or plain "Team" when even the coach's name is unknown.
String teamDisplayName({String? teamOrganization, String? coachName}) {
  final org = teamOrganization?.trim() ?? '';
  if (org.isNotEmpty && org.toLowerCase() != _kLegacyPlaceholder) return org;

  final first = (coachName ?? '').trim().split(RegExp(r'\s+')).first;
  return first.isEmpty ? 'Team' : "Coach $first's team";
}

/// The team name an athlete should see for a membership.
///
/// Prefers the coach's live profile ([coachProfile], null while it loads or if
/// it can't be read) over [storedTeamName], the copy made when the invite was
/// sent — so a rename shows up everywhere without rewriting the memberships.
String liveTeamName({
  Map<String, dynamic>? coachProfile,
  required String storedTeamName,
  String? coachName,
}) {
  if (coachProfile != null) {
    final liveCoachName =
        (coachProfile['fullName'] as String? ?? '').trim().isNotEmpty
            ? coachProfile['fullName'] as String
            : coachName;
    return teamDisplayName(
      teamOrganization: coachProfile['teamOrganization'] as String?,
      coachName: liveCoachName,
    );
  }
  return teamDisplayName(
      teamOrganization: storedTeamName, coachName: coachName);
}
