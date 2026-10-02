// lib/services/standings_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';
import '../utils/team_standings.dart';

/// Reads the games a season's team standings are built from. Static helpers,
/// matching TeamService's style; the table itself is worked out by the pure
/// computeStandings in utils/team_standings.dart.
///
/// Nothing is stored for standings: they're derived from the events and
/// match results that already exist, so there's nothing to keep in step and
/// nothing to reset when a season ends.
class StandingsService {
  static final _events = FirebaseFirestore.instance.collection('events');
  static final _matches = FirebaseFirestore.instance.collection('matches');

  /// Every official [sport] game played in [season] between two coaches'
  /// teams. Events whose result isn't recorded yet are left out by the query
  /// (hasMatchData); tune-ups, cancelled events and the like by
  /// [standingsGameFrom].
  ///
  /// Needs the composite index on events (sport, hasMatchData, eventDate) in
  /// firestore.indexes.json.
  static Future<List<StandingsGame>> fetchSeasonGames(
      String sport, int season) async {
    final bounds = seasonBounds(season);
    final eventSnap = await _events
        .where('sport', isEqualTo: sport)
        .where('hasMatchData', isEqualTo: true)
        .where('eventDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(bounds.start))
        .where('eventDate', isLessThan: Timestamp.fromDate(bounds.end))
        .get();
    if (eventSnap.docs.isEmpty) return [];

    final events = {for (final d in eventSnap.docs) d.id: d.data()};
    final eventIds = events.keys.toList();

    // `whereIn` accepts at most 30 values, so this chunks. The rules allow
    // one match per event, so each event pairs with at most one result.
    final games = <StandingsGame>[];
    for (var i = 0; i < eventIds.length; i += 30) {
      final end = i + 30 < eventIds.length ? i + 30 : eventIds.length;
      final matchSnap = await _matches
          .where('eventId', whereIn: eventIds.sublist(i, end))
          .get();
      for (final m in matchSnap.docs) {
        final event = events[m.data()['eventId']];
        if (event == null) continue;
        final game = standingsGameFrom(
          event: event,
          match: m.data(),
          playedAt: asTimestamp(event['eventDate'])?.toDate(),
        );
        if (game != null) games.add(game);
      }
    }
    return games;
  }
}
