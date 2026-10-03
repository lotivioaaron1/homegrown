// lib/utils/recruitment_status.dart

// What an athlete's recruitment pill says, as a pure decision.
//
// Joining a team closes recruitment (see TeamService.acceptInvite), so most
// closed athletes are closed because they already have a team. "Not
// Available" never said so; naming the team does, and tells a coach who has
// them.

enum RecruitmentKind { open, onTeam, unavailable }

class RecruitmentBadgeInfo {
  final RecruitmentKind kind;
  final String label;

  const RecruitmentBadgeInfo(this.kind, this.label);
}

/// [isOpen] wins over [teamNames]: an athlete on a team who switched
/// recruitment back on did it deliberately — typically a multi-sport player
/// looking for a team in their other sport — so they read as open.
///
/// [teamNames] are the athlete's current teams, one per sport at most. Blank
/// names are dropped and a repeated name is shown once.
RecruitmentBadgeInfo recruitmentBadge({
  required bool isOpen,
  required List<String> teamNames,
}) {
  if (isOpen) {
    return const RecruitmentBadgeInfo(
        RecruitmentKind.open, 'Open to Recruitment');
  }

  final names = teamNames
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty)
      .toSet();
  if (names.isEmpty) {
    return const RecruitmentBadgeInfo(
        RecruitmentKind.unavailable, 'Not Available');
  }
  return RecruitmentBadgeInfo(
      RecruitmentKind.onTeam, 'Plays for ${names.join(' · ')}');
}
