// test/utils/next_game_test.dart
//
// The "Next game" card on Home: which game it picks and how the kickoff reads.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/next_game.dart';

// Saturday 3 Oct 2026, 9:00 AM.
final _now = DateTime(2026, 10, 3, 9);

Map<String, dynamic> _event(String name, DateTime? date,
        {String status = 'upcoming'}) =>
    {
      'name': name,
      'status': status,
      if (date != null) 'eventDate': Timestamp.fromDate(date),
    };

String? _pick(List<Map<String, dynamic>> events) =>
    nextGame<Map<String, dynamic>>(events, dataOf: (e) => e, now: _now)
        ?['name'] as String?;

void main() {
  group('nextGame', () {
    test('picks the soonest game, whatever order they arrive in', () {
      expect(
        _pick([
          _event('later', DateTime(2026, 10, 10, 16)),
          _event('soonest', DateTime(2026, 10, 4, 16)),
          _event('middle', DateTime(2026, 10, 6, 16)),
        ]),
        'soonest',
      );
    });

    test('skips games that have already been played', () {
      expect(
        _pick([
          _event('yesterday', DateTime(2026, 10, 2, 16)),
          _event('next week', DateTime(2026, 10, 10, 16)),
        ]),
        'next week',
      );
    });

    test('skips cancelled games and drafts', () {
      expect(
        _pick([
          _event('cancelled', DateTime(2026, 10, 4), status: 'cancelled'),
          _event('draft', DateTime(2026, 10, 4), status: 'draft'),
          _event('real', DateTime(2026, 10, 5)),
        ]),
        'real',
      );
    });

    test('skips a game with no date, which has no kickoff to show', () {
      expect(
        _pick([
          _event('no date', null),
          _event('dated', DateTime(2026, 10, 8)),
        ]),
        'dated',
      );
    });

    test('a malformed date is treated as missing rather than crashing', () {
      expect(
        _pick([
          {'name': 'typed by hand', 'eventDate': 'Oct 4'},
          _event('dated', DateTime(2026, 10, 8)),
        ]),
        'dated',
      );
    });

    test('nothing to play is null, so the card can stay hidden', () {
      expect(_pick([]), isNull);
      expect(_pick([_event('past', DateTime(2026, 9, 1))]), isNull);
    });

    test('a game later today still counts as next', () {
      expect(_pick([_event('tonight', DateTime(2026, 10, 3, 19))]), 'tonight');
    });
  });

  group('kickoffLabel', () {
    test('later today', () {
      expect(kickoffLabel(DateTime(2026, 10, 3, 16), now: _now),
          'Today · 4:00 PM');
    });

    test('tomorrow', () {
      expect(kickoffLabel(DateTime(2026, 10, 4, 9, 30), now: _now),
          'Tomorrow · 9:30 AM');
    });

    test('calendar days, not 24 hours: a 9 AM game seen at 10 PM is tomorrow',
        () {
      expect(
          kickoffLabel(DateTime(2026, 10, 4, 9),
              now: DateTime(2026, 10, 3, 22)),
          'Tomorrow · 9:00 AM');
    });

    test('further out names the day and date', () {
      expect(kickoffLabel(DateTime(2026, 10, 10, 16), now: _now),
          'Sat, Oct 10 · 4:00 PM');
    });

    test('across a month boundary', () {
      expect(
          kickoffLabel(DateTime(2026, 11, 1, 8),
              now: DateTime(2026, 10, 31, 20)),
          'Tomorrow · 8:00 AM');
    });
  });

  group('isGameDay', () {
    test('same calendar day', () {
      expect(isGameDay(DateTime(2026, 10, 3, 23, 59), now: _now), isTrue);
    });

    test('tomorrow is not game day', () {
      expect(isGameDay(DateTime(2026, 10, 4), now: _now), isFalse);
    });
  });
}
