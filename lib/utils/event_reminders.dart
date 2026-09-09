// lib/utils/event_reminders.dart

import 'package:intl/intl.dart';

/// Which of the two reminders a scheduled notification is.
enum ReminderSlot {
  /// 18:00 on the calendar day before the event — the "you play tomorrow"
  /// heads-up, timed for when someone is likely to be planning their evening.
  eveningBefore,

  /// One hour before kickoff — the "leave now" nudge.
  oneHourBefore,
}

/// One reminder to hand to the OS scheduler.
class EventReminder {
  const EventReminder({required this.slot, required this.fireAt});

  final ReminderSlot slot;
  final DateTime fireAt;

  @override
  String toString() => 'EventReminder($slot, $fireAt)';
}

/// The minimum lead time a reminder needs to be worth scheduling. Handing the
/// OS an alarm for a few seconds from now produces a notification that lands
/// while the user is still looking at the app that scheduled it.
const Duration _minimumLeadTime = Duration(minutes: 2);

/// The reminders to schedule for an event starting at [eventDate].
///
/// Returns an empty list for an event with no date — a draft still being
/// scheduled has nothing to remind anyone about — and drops any slot that
/// has already passed. That last rule is what handles a game added at short
/// notice: an event three hours away gets only the one-hour reminder, and an
/// event thirty minutes away gets none at all, because a notification reading
/// "starting in 1 hour" would be wrong.
List<EventReminder> remindersFor(DateTime? eventDate, {DateTime? now}) {
  if (eventDate == null) return const [];
  final cutoff = (now ?? DateTime.now()).add(_minimumLeadTime);

  // Day - 1 rather than subtracting 24 hours: DateTime normalises a zero or
  // negative day into the previous month, so this stays correct on the 1st.
  final eveningBefore = DateTime(
      eventDate.year, eventDate.month, eventDate.day - 1, 18, 0);
  final oneHourBefore = eventDate.subtract(const Duration(hours: 1));

  return [
    if (eveningBefore.isAfter(cutoff))
      EventReminder(slot: ReminderSlot.eveningBefore, fireAt: eveningBefore),
    if (oneHourBefore.isAfter(cutoff))
      EventReminder(slot: ReminderSlot.oneHourBefore, fireAt: oneHourBefore),
  ];
}

/// Headline for a reminder. "Tomorrow" is accurate by construction: the
/// evening-before slot only ever fires on the day preceding the event.
String reminderTitle(ReminderSlot slot) => switch (slot) {
      ReminderSlot.eveningBefore => 'Game tomorrow',
      ReminderSlot.oneHourBefore => 'Starting in 1 hour',
    };

/// Body copy for a reminder: the event, its kickoff time, and where it is.
///
/// Both the name and the venue can be missing on a real document, so each part
/// is only joined in when it has something to say — the alternative is a
/// notification reading "  · 3:00 PM at ".
String reminderBody({
  required String eventName,
  required String venue,
  required DateTime eventDate,
}) {
  final time = DateFormat('h:mm a').format(eventDate);
  final name = eventName.trim();
  final place = venue.trim();

  final head = name.isEmpty ? 'Your game' : name;
  return place.isEmpty ? '$head · $time' : '$head · $time at $place';
}
