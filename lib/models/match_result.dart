// lib/models/match_result.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// A single match between two sides of an event's roster, stored at
/// matches/{matchId}. Created by RecordMatchScreen as 'pending' once the
/// sides and final score are set, then flipped to 'finalized' by
/// RatingService once every participant's stats have been recorded and
/// their ratings updated.
class MatchResult {
  final String id;
  final String eventId;
  final String sport;
  final List<String> sideA;
  final List<String> sideB;
  final int scoreA;
  final int scoreB;
  final String winner; // 'A' | 'B'
  final String status; // 'pending' | 'finalized'
  final String recordedBy;
  final DateTime? createdAt;
  final DateTime? finalizedAt;

  const MatchResult({
    required this.id,
    required this.eventId,
    required this.sport,
    required this.sideA,
    required this.sideB,
    required this.scoreA,
    required this.scoreB,
    required this.winner,
    required this.status,
    required this.recordedBy,
    this.createdAt,
    this.finalizedAt,
  });

  bool get isFinalized => status == 'finalized';

  List<String> get allParticipants => [...sideA, ...sideB];

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'sport': sport,
      'sideA': sideA,
      'sideB': sideB,
      'scoreA': scoreA,
      'scoreB': scoreB,
      'winner': winner,
      'status': status,
      'recordedBy': recordedBy,
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'finalizedAt':
          finalizedAt != null ? Timestamp.fromDate(finalizedAt!) : null,
    };
  }

  factory MatchResult.fromMap(String id, Map<String, dynamic> map) {
    return MatchResult(
      id: id,
      eventId: map['eventId'] as String? ?? '',
      sport: map['sport'] as String? ?? '',
      sideA: List<String>.from(map['sideA'] as List? ?? const []),
      sideB: List<String>.from(map['sideB'] as List? ?? const []),
      scoreA: (map['scoreA'] as num?)?.toInt() ?? 0,
      scoreB: (map['scoreB'] as num?)?.toInt() ?? 0,
      winner: map['winner'] as String? ?? 'A',
      status: map['status'] as String? ?? 'pending',
      recordedBy: map['recordedBy'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      finalizedAt: (map['finalizedAt'] as Timestamp?)?.toDate(),
    );
  }
}
