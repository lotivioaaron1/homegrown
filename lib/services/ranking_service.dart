// lib/services/ranking_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Answers "where does this athlete sit in the city?" without downloading the
/// city.
///
/// The home screen, performance dashboard and settings screen each showed a
/// single rank number, and each got it by fetching every athlete document and
/// sorting client-side. That is O(users) Firestore reads to render one label,
/// repeated on every rebuild — comfortably the app's largest read cost.
///
/// A count aggregation asks Firestore for the number of athletes ahead instead
/// of their contents, which bills roughly one read per 1000 matched index
/// entries rather than one per document.
class RankingService {
  /// One-based city rank for an athlete holding [points].
  ///
  /// Ties now share a rank — two athletes on 40 points are both 3rd — where the
  /// old client-side `indexWhere` broke ties by whichever document Firestore
  /// happened to return first. Shared ranks are the conventional reading of
  /// "rank" and no longer change between refreshes, so this is a fix rather
  /// than a regression.
  ///
  /// Athletes whose `points` field is missing entirely are not counted, which
  /// matches the old behaviour: `_toInt` mapped a missing value to 0, and 0 is
  /// never greater than a non-negative score.
  static Future<int> cityRank({
    required int points,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final ahead = await db
        .collection('users')
        .where('role', isEqualTo: 'athlete')
        .where('points', isGreaterThan: points)
        .count()
        .get();
    return (ahead.count ?? 0) + 1;
  }
}
