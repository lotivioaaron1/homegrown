// lib/models/rating_history_entry.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// One rating change for a player, stored at
/// users/{uid}/ratingHistory/{matchId}. Written by RatingService when a
/// match is finalized; powers the rating trend on the performance
/// dashboard and gives an audit trail for how a player's rating moved.
class RatingHistoryEntry {
  final String matchId;
  final String sport;
  final int oldRating;
  final int newRating;
  final int delta;
  final String result; // 'win' | 'loss'
  final DateTime? createdAt;

  const RatingHistoryEntry({
    required this.matchId,
    required this.sport,
    required this.oldRating,
    required this.newRating,
    required this.delta,
    required this.result,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'sport': sport,
      'oldRating': oldRating,
      'newRating': newRating,
      'delta': delta,
      'result': result,
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  factory RatingHistoryEntry.fromMap(Map<String, dynamic> map) {
    return RatingHistoryEntry(
      matchId: map['matchId'] as String? ?? '',
      sport: map['sport'] as String? ?? '',
      oldRating: (map['oldRating'] as num?)?.toInt() ?? 0,
      newRating: (map['newRating'] as num?)?.toInt() ?? 0,
      delta: (map['delta'] as num?)?.toInt() ?? 0,
      result: map['result'] as String? ?? 'loss',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
