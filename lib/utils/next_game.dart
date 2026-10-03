// lib/utils/next_game.dart

import 'package:intl/intl.dart';

import 'firestore_helpers.dart';

// The "Next game" card on Home, as pure decisions: which game it shows and how
// its kickoff reads. Home's Upcoming Games list sits at the bottom of the
// screen, under the team deck and Recent Activity, so a game tomorrow was the
// last thing an athlete or coach saw — this card puts the soonest one under
// the hero instead.

/// The soonest game in [events] that is still to be played, or null.
///
/// Drafts are left out (only the organizer sees those), and so is anything
/// [isEventUpcoming] rules out, which covers cancelled and already-played
/// games. A game with no date is also skipped even though [isEventUpcoming]
/// counts it as upcoming: the card's whole job is to say *when*, and it has
/// nothing to say about one.
T? nextGame<T>(
  Iterable<T> events, {
  required Map<String, dynamic> Function(T) dataOf,
  DateTime? now,
}) {
  T? best;
  DateTime? bestDate;
  for (final event in events) {
    final data = dataOf(event);
    if (data['status'] == 'draft') continue;
    if (!isEventUpcoming(data, now: now)) continue;
    final date = asTimestamp(data['eventDate'])?.toDate();
    if (date == null) continue;
    if (bestDate == null || date.isBefore(bestDate)) {
      best = event;
      bestDate = date;
    }
  }
  return best;
}

/// When [date] kicks off, relative to [now]: "Today · 4:00 PM",
/// "Tomorrow · 4:00 PM", or "Sat, Oct 10 · 4:00 PM" further out.
///
/// Days are calendar days, not 24-hour spans, so a 9 AM game seen at 10 PM
/// the night before reads "Tomorrow" rather than "Today".
String kickoffLabel(DateTime date, {required DateTime now}) {
  final time = DateFormat('h:mm a').format(date);
  // UTC midnights so a daylight-saving change (none in Manila, but possible
  // on a test machine) can't make a calendar day 23 hours long.
  final days = DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(now.year, now.month, now.day))
      .inDays;
  if (days == 0) return 'Today · $time';
  if (days == 1) return 'Tomorrow · $time';
  return '${DateFormat('EEE, MMM d').format(date)} · $time';
}

/// True when [date] falls on [now]'s calendar day — the card is drawn in
/// gold on game day and neutral otherwise.
bool isGameDay(DateTime date, {required DateTime now}) =>
    date.year == now.year && date.month == now.month && date.day == now.day;
