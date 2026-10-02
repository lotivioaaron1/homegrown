// lib/utils/sport_rating.dart

/// [ratings] is an athlete's `ratings` map from their user document; returns
/// their Elo in [sport], or null when they have no rated match in it.
///
/// Null rather than kStartingRating: the leaderboard reads a missing rating
/// as the starting value so it can sort everyone, but on a profile "Unrated"
/// and "exactly 1000" tell a scout different things.
///
/// Keys are the lowercase sport name, as RatingService.sportKey writes them.
/// Restated here rather than imported so this stays free of Firestore.
int? sportRating(Map? ratings, String sport) {
  final value = ratings?[sport.toLowerCase()];
  return value is num ? value.toInt() : null;
}
