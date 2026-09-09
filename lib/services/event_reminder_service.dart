// lib/services/event_reminder_service.dart

import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../utils/event_reminders.dart';
import '../utils/firestore_helpers.dart';

/// Schedules the "your game starts soon" notifications with the operating
/// system, so they arrive with the app closed.
///
/// Deliberately local notifications rather than push. A server-side reminder
/// would mean Cloud Functions, a scheduler and a billing plan; handing the OS
/// a list of "fire this at time T" alarms needs none of that and still wakes
/// the user's phone. The trade-off is that reminders are only (re)calculated
/// while the app is open — see [syncFor].
///
/// Nothing is written to Firestore. An `event_reminder` notification document
/// would have to be created either at the reminder moment (which needs the app
/// to be running, defeating the point) or hours early at schedule time (which
/// would put a "starting soon" row in the bell while it is still untrue). The
/// OS notification *is* the reminder; tapping it opens the event.
///
/// Static helpers rather than a GetX service, matching [NotificationService].
class EventReminderService {
  EventReminderService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'event_reminders';
  static const String _channelName = 'Event reminders';
  static const String _channelDescription =
      'Reminders that a game you are in is about to start.';

  /// How many events deep to look when scheduling. Each one costs up to two
  /// pending alarms, and nobody is rostered into enough near-term games for
  /// this to bite.
  static const int _eventFetchLimit = 20;
  static const int _maxScheduledEvents = 10;

  static bool _initialised = false;
  static bool _permissionRequested = false;

  /// Set when a reminder is tapped, and consumed by the home screen. A tap
  /// that cold-starts the app arrives long before GetX has a navigator, so the
  /// event id is parked here rather than navigated to immediately.
  static String? _pendingEventId;

  /// Android and iOS only. The project also builds for Windows, where the
  /// plugin needs a packaged app identity to raise a toast at all, so every
  /// entry point below no-ops rather than throwing on desktop.
  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Prepares the plugin and the notification channel. Safe to call before
  /// anyone is signed in — it deliberately does *not* ask for the notification
  /// permission, because that prompt belongs at the point the user stands to
  /// gain something from it (see [syncFor]) rather than on a cold splash
  /// screen before login.
  static Future<void> init() async {
    if (!_supported || _initialised) return;

    try {
      tz_data.initializeTimeZones();
      // Hardcoded rather than read from the device: Homegrown is a Legazpi
      // City app, so the one timezone it will ever schedule against is known
      // up front. Reading the device zone would mean adding flutter_timezone
      // to rediscover a constant. If the app ever ships outside PH, that
      // package is the fix — not a second hardcoded zone.
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));

      await _plugin.initialize(
        settings: const InitializationSettings(
          // The monogram already shipped for the Android 13 themed launcher
          // icon. Android renders a notification's small icon as a silhouette,
          // so a full-colour icon would come through as a white blob; this one
          // is alpha-only and comes through as the HG mark.
          android:
              AndroidInitializationSettings('@drawable/ic_launcher_monochrome'),
          iOS: DarwinInitializationSettings(
            // Requested by [syncFor] instead, for the same reason as Android.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _handleTap(response.payload),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ));

      // A tap that launched the app from cold never reaches the callback
      // above, so the launch details are the only way to see it.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _pendingEventId = launch?.notificationResponse?.payload;
      }

      _initialised = true;
    } catch (e, st) {
      // A phone that refuses to set up notifications is not a reason to fail
      // startup — the rest of the app works fine without reminders.
      debugPrint('EventReminderService.init failed: $e\n$st');
    }
  }

  /// Rebuilds the whole set of scheduled reminders for [uid].
  ///
  /// Called when the home screen mounts. Everything pending is cancelled and
  /// rescheduled from scratch, which is what keeps this correct without any
  /// bookkeeping: an event that moved, was cancelled or that the user was
  /// dropped from simply does not come back in the query.
  ///
  /// The limitation that follows is that reminders only refresh while the app
  /// is open. If an organizer rosters someone into a game while their app is
  /// closed, that reminder is scheduled the next time they open it.
  static Future<void> syncFor(String uid) async {
    if (!_supported || uid.isEmpty) return;
    await init();
    if (!_initialised) return;

    try {
      if (!await _ensurePermission()) return;

      final events = await _upcomingEventsFor(uid);
      await _plugin.cancelAll();

      final now = DateTime.now();
      for (final event in events) {
        final date = asTimestamp(event['eventDate'])?.toDate();
        final eventId = asString(event['eventId']);
        if (eventId.isEmpty) continue;

        for (final reminder in remindersFor(date, now: now)) {
          await _plugin.zonedSchedule(
            id: _notificationId(eventId, reminder.slot),
            title: reminderTitle(reminder.slot),
            body: reminderBody(
              eventName: asString(event['name']),
              venue: asString(event['venue']),
              eventDate: date!,
            ),
            scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.local),
            payload: eventId,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                channelDescription: _channelDescription,
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            // Inexact on purpose. An exact alarm needs SCHEDULE_EXACT_ALARM,
            // which Android 12+ makes the user grant by hand and which Play
            // scrutinises; a few minutes of drift on "your game is tomorrow"
            // is not worth either. allowWhileIdle so a phone in Doze — which
            // is exactly where it will be at 18:00 the night before — still
            // fires it.
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    } catch (e, st) {
      debugPrint('EventReminderService.syncFor failed: $e\n$st');
    }
  }

  /// The events [uid] is actually taking part in, soonest first.
  ///
  /// Two queries because membership is stored two different ways: athletes are
  /// in the `playerUids` array, while coaches sit on `teamACoachId` /
  /// `teamBCoachId` and are deliberately kept out of that array (see
  /// [eventAudienceUids]). Running both means the caller never has to know the
  /// signed-in user's role.
  ///
  /// Neither query filters on `eventDate`. Adding that clause would need a new
  /// composite index for each; filtering a couple of dozen documents on the
  /// client costs nothing and keeps the deploy footprint at zero.
  static Future<List<Map<String, dynamic>>> _upcomingEventsFor(
      String uid) async {
    final events = FirebaseFirestore.instance.collection('events');
    final results = await Future.wait([
      events
          .where('playerUids', arrayContains: uid)
          .limit(_eventFetchLimit)
          .get(),
      events
          .where(Filter.or(
            Filter('teamACoachId', isEqualTo: uid),
            Filter('teamBCoachId', isEqualTo: uid),
          ))
          .limit(_eventFetchLimit)
          .get(),
    ]);

    // A coach picked for a side of a game they also play in would otherwise
    // be scheduled two identical reminders.
    final byId = <String, Map<String, dynamic>>{};
    for (final snapshot in results) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'draft') continue;
        if (!isEventUpcoming(data)) continue;
        byId[doc.id] = data;
      }
    }

    final upcoming = byId.values.toList()
      ..sort((a, b) {
        final aT = asTimestamp(a['eventDate']);
        final bT = asTimestamp(b['eventDate']);
        if (aT == null || bT == null) return 0;
        return aT.compareTo(bT);
      });
    return upcoming.take(_maxScheduledEvents).toList();
  }

  /// Asks for the notification permission the first time reminders are
  /// scheduled in a session. Android 13+ requires the grant; earlier versions
  /// return true without prompting.
  static Future<bool> _ensurePermission() async {
    if (_permissionRequested) return true;
    _permissionRequested = true;

    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? true;
    }
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? true;
  }

  /// A stable id per event and slot, so rescheduling the same reminder
  /// replaces it rather than stacking up duplicates. Masked into a positive
  /// 32-bit range because that is what the Android notification id accepts.
  static int _notificationId(String eventId, ReminderSlot slot) =>
      Object.hash(eventId, slot.index) & 0x7fffffff;

  static void _handleTap(String? eventId) {
    if (eventId == null || eventId.isEmpty) return;
    _pendingEventId = eventId;
    // Only navigate directly when the app is already up. On a cold start the
    // navigator does not exist yet, so the id waits for the home screen.
    if (Get.key.currentState != null) {
      openPendingEvent();
    }
  }

  /// Opens the event a tapped reminder pointed at, if there is one. Called by
  /// the home screen once it is mounted, which is the first moment a cold
  /// start has somewhere to navigate from.
  static void openPendingEvent() {
    final eventId = _pendingEventId;
    if (eventId == null || eventId.isEmpty) return;
    _pendingEventId = null;
    Get.toNamed('/events/detail', arguments: {'eventId': eventId});
  }
}
