// lib/models/tournament.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// One player inside an entrant's frozen roster snapshot.
///
/// Deliberately the same three keys an event's `players[]` entry carries
/// (minus `team`, which is stamped on when a matchup spawns its child
/// event), so building that event is a straight copy rather than a
/// re-query of the coach's live roster.
class EntrantPlayer {
  final String uid;
  final String fullName;
  final String position;

  const EntrantPlayer({
    required this.uid,
    required this.fullName,
    this.position = '',
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'fullName': fullName,
        'position': position,
      };

  factory EntrantPlayer.fromMap(Map<String, dynamic> map) => EntrantPlayer(
        uid: map['uid'] as String? ?? '',
        fullName: map['fullName'] as String? ?? '',
        position: map['position'] as String? ?? '',
      );
}

/// A team entered into a tournament: a coach, their team identity, and the
/// roster as it stood when the bracket was drawn.
///
/// The roster is snapshotted rather than read live because a bracket has to
/// stay stable for its whole run — an athlete leaving the coach's team
/// midway through should not silently change who is on the teamsheet for a
/// semifinal. The organizer can still trim an individual matchup's roster
/// through the existing Edit Teams screen.
class TournamentEntrant {
  /// 1-based. Seed 1 is the top seed; seeding drives bye placement.
  final int seed;
  final String coachId;
  final String teamName;
  final String coachName;
  final String? teamLogoUrl;
  final List<EntrantPlayer> players;

  const TournamentEntrant({
    required this.seed,
    required this.coachId,
    required this.teamName,
    this.coachName = '',
    this.teamLogoUrl,
    this.players = const [],
  });

  TournamentEntrant copyWith({int? seed}) => TournamentEntrant(
        seed: seed ?? this.seed,
        coachId: coachId,
        teamName: teamName,
        coachName: coachName,
        teamLogoUrl: teamLogoUrl,
        players: players,
      );

  Map<String, dynamic> toMap() => {
        'seed': seed,
        'coachId': coachId,
        'teamName': teamName,
        'coachName': coachName,
        'teamLogoUrl': teamLogoUrl,
        'players': players.map((p) => p.toMap()).toList(),
      };

  factory TournamentEntrant.fromMap(Map<String, dynamic> map) =>
      TournamentEntrant(
        seed: (map['seed'] as num?)?.toInt() ?? 0,
        coachId: map['coachId'] as String? ?? '',
        teamName: map['teamName'] as String? ?? '',
        coachName: map['coachName'] as String? ?? '',
        teamLogoUrl: map['teamLogoUrl'] as String?,
        players: ((map['players'] as List?) ?? const [])
            .map((p) => EntrantPlayer.fromMap(Map<String, dynamic>.from(p as Map)))
            .toList(),
      );
}

/// A single-elimination tournament, stored at tournaments/{tournamentId}.
///
/// The bracket itself lives in the `matches` subcollection (see
/// [BracketSlot]); this document holds the entrants and the outcome. Only
/// the owning organizer may write it — see the `tournaments` block in
/// firestore.rules.
class Tournament {
  static const String statusDraft = 'draft';
  static const String statusActive = 'active';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  /// Below four teams a bracket is just an event; above sixteen the
  /// entrants array starts to strain a single document.
  static const int minEntrants = 4;
  static const int maxEntrants = 16;

  final String id;
  final String organizerId;
  final String name;
  final String description;
  final String sport;
  final String status;
  final bool isPublic;

  // Venue is fixed for the whole tournament and inherited by every child
  // event; a one-off change is made on that event instead.
  final String venue;
  final String venueAddress;
  final double venueLat;
  final double venueLng;
  final String venueType;

  final int entrantCount;
  final int roundCount;
  final List<TournamentEntrant> entrants;

  final String? championCoachId;
  final String? championTeamName;

  /// Set the first time any matchup's result is recorded. Mirrors the same
  /// field on an event: it lets the delete rule refuse a tournament that
  /// already has results without running a subcollection query, which
  /// security rules cannot cheaply express.
  final bool hasMatchData;

  final DateTime? createdAt;
  final DateTime? completedAt;

  const Tournament({
    required this.id,
    required this.organizerId,
    required this.name,
    required this.sport,
    this.description = '',
    this.status = statusActive,
    this.isPublic = true,
    this.venue = '',
    this.venueAddress = '',
    this.venueLat = 0,
    this.venueLng = 0,
    this.venueType = '',
    this.entrantCount = 0,
    this.roundCount = 0,
    this.entrants = const [],
    this.championCoachId,
    this.championTeamName,
    this.hasMatchData = false,
    this.createdAt,
    this.completedAt,
  });

  bool get isCompleted => status == statusCompleted;
  bool get isCancelled => status == statusCancelled;

  /// The entrant a bracket slot's coachId refers to, or null if that coach
  /// is not in this tournament.
  TournamentEntrant? entrantFor(String coachId) {
    for (final e in entrants) {
      if (e.coachId == coachId) return e;
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': id,
        'organizerId': organizerId,
        'name': name,
        'description': description,
        'sport': sport,
        'status': status,
        'isPublic': isPublic,
        'venue': venue,
        'venueAddress': venueAddress,
        'venueLat': venueLat,
        'venueLng': venueLng,
        'venueType': venueType,
        'entrantCount': entrantCount,
        'roundCount': roundCount,
        'entrants': entrants.map((e) => e.toMap()).toList(),
        'championCoachId': championCoachId,
        'championTeamName': championTeamName,
        'hasMatchData': hasMatchData,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      };

  factory Tournament.fromMap(String id, Map<String, dynamic> map) => Tournament(
        id: id,
        organizerId: map['organizerId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        sport: map['sport'] as String? ?? '',
        status: map['status'] as String? ?? statusActive,
        isPublic: map['isPublic'] as bool? ?? true,
        venue: map['venue'] as String? ?? '',
        venueAddress: map['venueAddress'] as String? ?? '',
        venueLat: (map['venueLat'] as num?)?.toDouble() ?? 0,
        venueLng: (map['venueLng'] as num?)?.toDouble() ?? 0,
        venueType: map['venueType'] as String? ?? '',
        entrantCount: (map['entrantCount'] as num?)?.toInt() ?? 0,
        roundCount: (map['roundCount'] as num?)?.toInt() ?? 0,
        entrants: ((map['entrants'] as List?) ?? const [])
            .map((e) =>
                TournamentEntrant.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        championCoachId: map['championCoachId'] as String?,
        championTeamName: map['championTeamName'] as String?,
        hasMatchData: map['hasMatchData'] as bool? ?? false,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
        completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      );
}
