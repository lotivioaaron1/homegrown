// lib/models/app_notification.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of in-app notifications. Add new cases here as more
/// triggers get wired up (event reminders, rank changes, etc.) —
/// the UI icon per type is chosen inline in home_screen.dart's
/// notification sheet, so a new type needs a branch added there too.
enum NotificationType {
  statsAdded,
  eventAdded,
  eventUpdated,
  eventCancelled,
  eventReminder,
  rankChange,
  teamInvite,
  teamFull,
  other,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final String? relatedId;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.relatedId,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      type: _typeFromString(d['type'] as String?),
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      relatedId: d['relatedId'] as String?,
      read: d['read'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static NotificationType _typeFromString(String? s) {
    switch (s) {
      case 'stats_added':
        return NotificationType.statsAdded;
      case 'event_added':
        return NotificationType.eventAdded;
      case 'event_updated':
        return NotificationType.eventUpdated;
      case 'event_cancelled':
        return NotificationType.eventCancelled;
      case 'event_reminder':
        return NotificationType.eventReminder;
      case 'rank_change':
        return NotificationType.rankChange;
      case 'team_invite':
        return NotificationType.teamInvite;
      case 'team_full':
        return NotificationType.teamFull;
      default:
        return NotificationType.other;
    }
  }
}