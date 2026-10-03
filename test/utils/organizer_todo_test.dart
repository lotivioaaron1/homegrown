import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/organizer_todo.dart';

final _now = DateTime(2026, 9, 30, 12);

Map<String, dynamic> _event(
  String id, {
  required DateTime date,
  String status = 'upcoming',
  bool hasResult = false,
  String? name,
}) =>
    {
      'eventId': id,
      'name': name ?? 'Game $id',
      'status': status,
      'eventDate': Timestamp.fromDate(date),
      if (hasResult) 'hasMatchData': true,
    };

void main() {
  group('organizerTodo', () {
    test('nothing to do for a future game', () {
      final todo = organizerTodo(
        events: [_event('a', date: _now.add(const Duration(days: 2)))],
        pendingMatches: const [],
        now: _now,
      );
      expect(todo.isEmpty, isTrue);
    });

    test('a game past kick-off with no result needs a score', () {
      final todo = organizerTodo(
        events: [_event('a', date: _now.subtract(const Duration(hours: 3)))],
        pendingMatches: const [],
        now: _now,
      );
      expect(todo.needsScore?.count, 1);
      expect(todo.needsScore?.nextEventId, 'a');
      expect(todo.needsStats, isNull);
    });

    test('a recorded game with a pending match needs stats, not a score', () {
      final todo = organizerTodo(
        events: [
          _event('a',
              date: _now.subtract(const Duration(days: 1)), hasResult: true),
        ],
        pendingMatches: const [
          {'eventId': 'a', 'status': 'pending'},
        ],
        now: _now,
      );
      expect(todo.needsScore, isNull);
      expect(todo.needsStats?.count, 1);
      expect(todo.needsStats?.nextEventId, 'a');
    });

    test('a pending match on a cancelled or unknown event is left out', () {
      final todo = organizerTodo(
        events: [
          _event('a',
              date: _now.subtract(const Duration(days: 1)),
              status: 'cancelled',
              hasResult: true),
        ],
        pendingMatches: const [
          {'eventId': 'a'},
          {'eventId': 'not-mine'},
        ],
        now: _now,
      );
      expect(todo.needsStats, isNull);
    });

    test('two pending matches for one event count as one game', () {
      final todo = organizerTodo(
        events: [
          _event('a',
              date: _now.subtract(const Duration(days: 1)), hasResult: true),
        ],
        pendingMatches: const [
          {'eventId': 'a'},
          {'eventId': 'a'},
        ],
        now: _now,
      );
      expect(todo.needsStats?.count, 1);
    });

    test('drafts are counted, and never as needing a score', () {
      final todo = organizerTodo(
        events: [
          _event('d',
              date: _now.subtract(const Duration(days: 1)), status: 'draft'),
        ],
        pendingMatches: const [],
        now: _now,
      );
      expect(todo.drafts?.count, 1);
      expect(todo.needsScore, isNull);
    });

    test('the game that has waited longest is offered first', () {
      final todo = organizerTodo(
        events: [
          _event('recent', date: _now.subtract(const Duration(hours: 2))),
          _event('oldest', date: _now.subtract(const Duration(days: 5))),
          _event('middle', date: _now.subtract(const Duration(days: 1))),
        ],
        pendingMatches: const [],
        now: _now,
      );
      expect(todo.needsScore?.count, 3);
      expect(todo.needsScore?.nextEventId, 'oldest');
    });

    test('a blank name reads as Untitled Event', () {
      final todo = organizerTodo(
        events: [
          _event('a',
              date: _now.subtract(const Duration(hours: 1)), name: '  '),
        ],
        pendingMatches: const [],
        now: _now,
      );
      expect(todo.needsScore?.nextEventName, 'Untitled Event');
    });
  });

  test('labels are singular for one and plural otherwise', () {
    expect(todoScoreLabel(1), '1 game needs a score');
    expect(todoScoreLabel(2), '2 games need a score');
    expect(todoStatsLabel(1), '1 game needs player stats');
    expect(todoStatsLabel(3), '3 games need player stats');
    expect(todoDraftsLabel(1), '1 draft to publish');
    expect(todoDraftsLabel(2), '2 drafts to publish');
  });
}
