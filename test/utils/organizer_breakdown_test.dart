// test/utils/organizer_breakdown_test.dart
//
// The counts behind the breakdown sheets on the organizer's own profile. The
// sheet is only worth having if its numbers can be trusted, so every section
// must add up to the total, and the status groups must agree with the ones
// My Events shows.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/organizer_breakdown.dart';

// A fixed "now" so the tests never depend on the wall clock.
final _now = DateTime(2026, 6, 15, 12, 0);

Map<String, dynamic> _event({
  String sport = 'Basketball',
  DateTime? date,
  String status = 'upcoming',
  bool recorded = false,
  String? tournamentId,
}) =>
    {
      'sport': sport,
      'status': status,
      if (date != null) 'eventDate': Timestamp.fromDate(date),
      if (recorded) 'hasMatchData': true,
      if (tournamentId != null) 'tournamentId': tournamentId,
    };

Map<String, int> _asMap(List<BreakdownRow> rows) =>
    {for (final r in rows) r.label: r.count};

int _sum(List<BreakdownRow> rows) => rows.fold<int>(0, (n, r) => n + r.count);

void main() {
  final past = _now.subtract(const Duration(days: 3));
  final future = _now.add(const Duration(days: 3));

  group('eventBreakdown', () {
    test('groups by status the way My Events does, in a fixed order', () {
      final b = eventBreakdown([
        _event(status: 'cancelled', date: future),
        _event(date: past, recorded: true),
        _event(date: past),
        _event(status: 'draft'),
        _event(date: future),
        _event(date: past, recorded: true),
      ], now: _now);

      expect(b.byStatus.map((r) => r.label).toList(), [
        'Upcoming',
        'Awaiting result',
        'Completed',
        'Draft',
        'Cancelled',
      ]);
      expect(_asMap(b.byStatus), {
        'Upcoming': 1,
        'Awaiting result': 1,
        'Completed': 2,
        'Draft': 1,
        'Cancelled': 1,
      });
    });

    test('a played game whose status still says upcoming is not upcoming', () {
      // `status` is never updated once a game is played.
      final b = eventBreakdown([_event(date: past)], now: _now);
      expect(_asMap(b.byStatus), {'Awaiting result': 1});
    });

    test('leaves out statuses with nothing in them', () {
      final b = eventBreakdown([_event(date: future)], now: _now);
      expect(_asMap(b.byStatus), {'Upcoming': 1});
    });

    test('orders sports the usual way and counts a blank one as No sport', () {
      final b = eventBreakdown([
        _event(sport: 'Badminton', date: future),
        _event(sport: 'Basketball', date: future),
        _event(sport: 'Badminton', date: future),
        _event(sport: '', date: future),
        _event(sport: 'Volleyball', date: future),
      ], now: _now);

      expect(b.bySport.map((r) => r.label).toList(),
          ['Basketball', 'Volleyball', 'Badminton', 'No sport']);
      expect(_asMap(b.bySport),
          {'Basketball': 1, 'Volleyball': 1, 'Badminton': 2, 'No sport': 1});
    });

    test('a missing sport field also counts as No sport', () {
      final b = eventBreakdown([
        {'status': 'upcoming'}
      ], now: _now);
      expect(_asMap(b.bySport), {'No sport': 1});
    });

    test('splits games the organizer scheduled from bracket games', () {
      final b = eventBreakdown([
        _event(date: future),
        _event(date: future, tournamentId: 't1'),
        _event(date: past, tournamentId: 't1'),
        _event(date: past),
        _event(status: 'draft'),
      ], now: _now);

      expect(b.scheduled, 3);
      expect(b.tournamentGames, 2);
    });

    test('every section adds up to the total', () {
      final b = eventBreakdown([
        _event(sport: 'Volleyball', status: 'cancelled'),
        _event(sport: 'Badminton', date: past, tournamentId: 't'),
        _event(sport: '', status: 'draft'),
        _event(date: past, recorded: true),
        _event(date: future),
      ], now: _now);

      expect(b.total, 5);
      expect(_sum(b.byStatus), b.total);
      expect(_sum(b.bySport), b.total);
      expect(b.scheduled + b.tournamentGames, b.total);
    });

    test('no events gives an empty breakdown', () {
      final b = eventBreakdown(const [], now: _now);
      expect(b.total, 0);
      expect(b.byStatus, isEmpty);
      expect(b.bySport, isEmpty);
      expect(b.scheduled, 0);
      expect(b.tournamentGames, 0);
    });
  });

  group('tournamentBreakdown', () {
    test('labels statuses the way the Tournaments list does', () {
      // Anything not completed or cancelled reads "In progress" there.
      final b = tournamentBreakdown([
        {'sport': 'Basketball', 'status': 'active'},
        {'sport': 'Basketball', 'status': 'draft'},
        {'sport': 'Volleyball', 'status': 'completed'},
        {'sport': 'Badminton', 'status': 'cancelled'},
      ]);

      expect(b.byStatus.map((r) => r.label).toList(),
          ['In progress', 'Completed', 'Cancelled']);
      expect(_asMap(b.byStatus),
          {'In progress': 2, 'Completed': 1, 'Cancelled': 1});
    });

    test('counts by sport and adds up to the total', () {
      final b = tournamentBreakdown([
        {'sport': 'Badminton', 'status': 'active'},
        {'sport': 'Basketball', 'status': 'completed'},
        {'sport': 'Badminton', 'status': 'completed'},
      ]);

      expect(b.total, 3);
      expect(b.bySport.map((r) => r.label).toList(),
          ['Basketball', 'Badminton']);
      expect(_asMap(b.bySport), {'Basketball': 1, 'Badminton': 2});
      expect(_sum(b.byStatus), b.total);
      expect(_sum(b.bySport), b.total);
    });

    test('no tournaments gives an empty breakdown', () {
      final b = tournamentBreakdown(const []);
      expect(b.total, 0);
      expect(b.byStatus, isEmpty);
      expect(b.bySport, isEmpty);
    });
  });
}
