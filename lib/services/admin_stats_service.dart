// lib/services/admin_stats_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// A snapshot of the numbers behind the super-admin's Overview tab.
///
/// Every figure is produced by a Firestore `count()` aggregation rather than
/// by reading documents. That distinction matters here more than anywhere
/// else in the app: the admin can read `users`, `events` and `matches` in
/// full, so a naive dashboard would download the entire database on every
/// open. An aggregation returns a single integer per query instead.
class AdminStats {
  final int users;
  final int athletes;
  final int coaches;
  final int organizers;

  /// Organizer applications waiting on the Approvals tab. This is the figure
  /// that replaces the `organizer_pending` notification an admin can never
  /// read — see organizer_register_screen.dart, which fans one out to every
  /// admin, and the notification bell, which lives only on /home.
  final int pendingOrganizers;

  final int suspended;

  /// Reports still waiting on a decision in the Reports tab.
  final int openReports;

  final int events;
  final int upcomingEvents;
  final int matches;

  const AdminStats({
    required this.users,
    required this.athletes,
    required this.coaches,
    required this.organizers,
    required this.pendingOrganizers,
    required this.suspended,
    required this.openReports,
    required this.events,
    required this.upcomingEvents,
    required this.matches,
  });

  /// All zeroes — the shape the dashboard renders while the real counts load.
  const AdminStats.empty()
      : users = 0,
        athletes = 0,
        coaches = 0,
        organizers = 0,
        pendingOrganizers = 0,
        suspended = 0,
        openReports = 0,
        events = 0,
        upcomingEvents = 0,
        matches = 0;
}

class AdminStatsService {
  static final _db = FirebaseFirestore.instance;

  /// Runs every count in parallel and returns them together, so the dashboard
  /// resolves in one round trip's worth of latency rather than nine.
  static Future<AdminStats> load() async {
    final users = _db.collection('users');

    final results = await Future.wait<int>([
      _count(users),
      _count(users.where('role', isEqualTo: 'athlete')),
      _count(users.where('role', isEqualTo: 'coach')),
      _count(users.where('role', isEqualTo: 'organizer')),
      _count(users
          .where('role', isEqualTo: 'organizer')
          .where('organizerStatus', isEqualTo: 'pending')),
      _count(users.where('suspended', isEqualTo: true)),
      _count(_db.collection('reports').where('status', isEqualTo: 'open')),
      _count(_db.collection('events')),
      _count(_db.collection('events').where('status', isEqualTo: 'upcoming')),
      _count(_db.collection('matches')),
    ]);

    return AdminStats(
      users: results[0],
      athletes: results[1],
      coaches: results[2],
      organizers: results[3],
      pendingOrganizers: results[4],
      suspended: results[5],
      openReports: results[6],
      events: results[7],
      upcomingEvents: results[8],
      matches: results[9],
    );
  }

  /// `AggregateQuerySnapshot.count` is nullable because the server can decline
  /// to compute it; treating that as zero keeps one unavailable figure from
  /// taking down the whole dashboard.
  static Future<int> _count(Query<Map<String, dynamic>> query) async {
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }
}
