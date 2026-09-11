// test/utils/event_reminders_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/utils/event_reminders.dart';

void main() {
  // A Wednesday 3pm game, with "now" a week earlier so both reminders are
  // comfortably in the future unless a test moves the clock.
  final game = DateTime(2026, 9, 16, 15, 0);
  final weekBefore = DateTime(2026, 9, 9, 10, 0);

  group('remindersFor', () {
    test('schedules the evening before and an hour before', () {
      final result = remindersFor(game, now: weekBefore);

      expect(result.map((r) => r.slot),
          [ReminderSlot.eveningBefore, ReminderSlot.oneHourBefore]);
      expect(result[0].fireAt, DateTime(2026, 9, 15, 18, 0));
      expect(result[1].fireAt, DateTime(2026, 9, 16, 14, 0));
    });

    test('returns nothing for an event with no date', () {
      // A draft can be published without a date, and there is nothing to
      // remind anyone about until one is set.
      expect(remindersFor(null, now: weekBefore), isEmpty);
    });

    test('drops the evening-before slot once it has passed', () {
      // Opened the app on the morning of the game: the 18:00 reminder for the
      // night before is gone, but the hour-before one still stands.
      final result = remindersFor(game, now: DateTime(2026, 9, 16, 9, 0));

      expect(result.map((r) => r.slot), [ReminderSlot.oneHourBefore]);
    });

    test('schedules nothing for a game starting within the hour', () {
      // A notification reading "starting in 1 hour" would be wrong, so no
      // reminder is better than a late one.
      expect(remindersFor(game, now: DateTime(2026, 9, 16, 14, 30)), isEmpty);
    });

    test('schedules nothing for a game already under way', () {
      expect(remindersFor(game, now: DateTime(2026, 9, 16, 15, 30)), isEmpty);
    });

    test('rolls back into the previous month on the 1st', () {
      // DateTime normalises day 0, which is what keeps the evening-before slot
      // correct without any date arithmetic of our own.
      final result = remindersFor(DateTime(2026, 10, 1, 9, 0),
          now: DateTime(2026, 9, 20));

      expect(result.first.fireAt, DateTime(2026, 9, 30, 18, 0));
    });

    test('handles a midnight game without producing a past reminder', () {
      // Both slots land on the previous calendar day here, so the only thing
      // separating them is the clock.
      final result = remindersFor(DateTime(2026, 9, 16, 0, 30),
          now: DateTime(2026, 9, 15, 12, 0));

      expect(result[0].fireAt, DateTime(2026, 9, 15, 18, 0));
      expect(result[1].fireAt, DateTime(2026, 9, 15, 23, 30));
    });
  });

  group('reminderTitle', () {
    test('names each slot', () {
      expect(reminderTitle(ReminderSlot.eveningBefore), 'Game tomorrow');
      expect(reminderTitle(ReminderSlot.oneHourBefore), 'Starting in 1 hour');
    });
  });

  group('reminderBody', () {
    test('includes the event, its time and its venue', () {
      expect(
        reminderBody(
            eventName: 'Bicol Cup Final',
            venue: 'Albay Astrodome',
            eventDate: game),
        'Bicol Cup Final · 3:00 PM at Albay Astrodome',
      );
    });

    test('omits the venue when the event has none', () {
      expect(
        reminderBody(eventName: 'Bicol Cup Final', venue: '', eventDate: game),
        'Bicol Cup Final · 3:00 PM',
      );
    });

    test('falls back to a generic name on an unnamed event', () {
      // Firestore enforces no schema, so neither field is guaranteed.
      expect(
        reminderBody(eventName: '', venue: '  ', eventDate: game),
        'Your game · 3:00 PM',
      );
    });
  });
}
