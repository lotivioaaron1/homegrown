// lib/services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Central place to write notification docs. Kept as static helpers
/// (not a GetX controller) so any screen — AddStatsScreen today,
/// event-creation or scouting screens later — can call this without
/// needing a shared instance or extra setup.
class NotificationService {
  static final _col = FirebaseFirestore.instance.collection('notifications');

  /// The complete set of notification types the app writes. Mirrored by the
  /// allowlist in firestore.rules — a signed-in user can still write a
  /// notification to anyone, but no longer one of an arbitrary invented type,
  /// and no longer one attributed to somebody else. Add to both places
  /// together when introducing a new type.
  static const Set<String> kTypes = {
    'event_added',
    'event_cancelled',
    'event_updated',
    'organizer_pending',
    'organizer_status',
    'stats_added',
    'team_full',
    'team_invite',
  };

  /// Call this alongside whatever action should notify a user —
  /// e.g. right after AddStatsScreen's batch.commit() for stats.
  /// [writeBatch] is optional: pass an existing WriteBatch to include
  /// this write atomically with other writes (recommended so the
  /// notification never gets created if the rest of the save fails);
  /// omit it to write immediately on its own.
  static Future<void> create({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? relatedId,
    WriteBatch? writeBatch,
  }) async {
    assert(kTypes.contains(type), 'Unknown notification type "$type" — add it '
        'to NotificationService.kTypes and to firestore.rules together.');

    final doc = _col.doc();
    final data = {
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'relatedId': relatedId,
      'read': false,
      // Records who caused the notification so the rules can refuse a document
      // attributed to anyone but its actual sender. Recipients never see this;
      // it exists purely so forgery is checkable server-side.
      'fromUid': FirebaseAuth.instance.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (writeBatch != null) {
      writeBatch.set(doc, data);
    } else {
      await doc.set(data);
    }
  }

  static Future<void> markRead(String notificationId) {
    return _col.doc(notificationId).update({'read': true});
  }

  static Future<void> markAllRead(String userId) async {
    final unread = await _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Deletes every notification for a user. Firestore batches cap at
  /// 500 writes, so this chunks in case someone has a very long
  /// backlog — unlikely today, but cheap insurance.
  static Future<void> deleteAll(String userId) async {
    final all = await _col.where('userId', isEqualTo: userId).get();
    final docs = all.docs;
    for (var i = 0; i < docs.length; i += 500) {
      final chunk = docs.sublist(i, i + 500 > docs.length ? docs.length : i + 500);
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}