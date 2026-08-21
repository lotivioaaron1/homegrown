// lib/models/team_invite.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// A coach→athlete team relationship, stored at
/// teamMemberships/{coachId}_{athleteId}. The same doc represents both a
/// pending invite and, once accepted, the membership itself — there is no
/// separate roster collection since each coach has exactly one team.
class TeamInvite {
  final String id;
  final String coachId;
  final String athleteId;
  final String coachName;
  final String teamName;
  final String athleteName;
  final String? athletePhotoUrl;
  final String status; // 'pending' | 'accepted'
  final DateTime? createdAt;
  final DateTime? respondedAt;

  const TeamInvite({
    required this.id,
    required this.coachId,
    required this.athleteId,
    required this.coachName,
    required this.teamName,
    required this.athleteName,
    this.athletePhotoUrl,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';

  Map<String, dynamic> toMap() {
    return {
      'coachId': coachId,
      'athleteId': athleteId,
      'coachName': coachName,
      'teamName': teamName,
      'athleteName': athleteName,
      'athletePhotoUrl': athletePhotoUrl,
      'status': status,
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }

  factory TeamInvite.fromMap(String id, Map<String, dynamic> map) {
    return TeamInvite(
      id: id,
      coachId: map['coachId'] as String? ?? '',
      athleteId: map['athleteId'] as String? ?? '',
      coachName: map['coachName'] as String? ?? '',
      teamName: map['teamName'] as String? ?? '',
      athleteName: map['athleteName'] as String? ?? '',
      athletePhotoUrl: map['athletePhotoUrl'] as String?,
      status: map['status'] as String? ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
    );
  }
}
