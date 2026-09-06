// lib/utils/firestore_helpers.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore has no schema enforcement, so a field expected to be a
/// [Timestamp] can end up as something else (e.g. a string typed in by
/// hand through the console). Use this instead of `as Timestamp?` so a
/// malformed value is treated as missing rather than crashing the widget
/// that reads it.
Timestamp? asTimestamp(dynamic value) => value is Timestamp ? value : null;

/// The same guard for string fields. `as String? ?? ''` looks equivalent but
/// throws on a non-string rather than falling back, which turns one malformed
/// document into a failure of whatever list is rendering it.
String asString(dynamic value) => value is String ? value : '';

/// True when a `users/{uid}` document represents someone worth listing.
///
/// Two kinds of dead profile have to be kept out of Scout and the Leaderboard,
/// and neither can be excluded by the Firestore query itself:
///
/// * Deleting an account from the Firebase console removes only the Auth
///   credential. `users/{uid}` survives completely untouched — same `role`,
///   same `primarySports`, same `openToRecruitment` — so the person keeps
///   appearing as a scoutable athlete nobody can ever sign in as. The name
///   check is what catches these, since nothing on the document records that
///   the account behind it is gone.
/// * The in-app deletion flow leaves a deliberate tombstone (`deleted: true`,
///   see [AccountDeletionService]) so that references from matches and stats
///   still resolve to "Deleted user". That is right for a match report and
///   wrong for a list of athletes to recruit or rank.
///
/// Blank names are treated as unlistable rather than rendered, because a card
/// with no name on it tells a coach nothing and cannot be acted on.
bool isListableProfile(Map<String, dynamic> user) {
  if (user['deleted'] == true) return false;
  final parts =
      '${asString(user['firstName'])} ${asString(user['lastName'])}'.trim();
  return parts.isNotEmpty || asString(user['fullName']).trim().isNotEmpty;
}

/// A game with no eventDate is still being scheduled, so it's treated as
/// upcoming rather than disappearing from every list by default. This is
/// the single source of truth for "is this game done" — the `status` field
/// on an event doc is only ever written once at creation ('draft' or
/// 'upcoming') and never updated afterward for a completed game, so it can't
/// be used for that. A cancelled event is the one exception: it's excluded
/// here regardless of date so a cancelled-but-not-yet-happened game doesn't
/// keep showing as upcoming.
bool isEventUpcoming(Map<String, dynamic> event, {DateTime? now}) {
  if (event['status'] == 'cancelled') return false;
  final date = asTimestamp(event['eventDate'])?.toDate();
  if (date == null) return true;
  return !date.isBefore(now ?? DateTime.now());
}
