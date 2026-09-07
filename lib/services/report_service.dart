// lib/services/report_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/report.dart';

/// Writes and resolves entries in the `reports` collection.
///
/// The collection is deliberately write-only for ordinary users: the rules let
/// a signed-in account create a report attributed to itself and nothing else,
/// so nobody can read the queue, see who reported whom, or amend a report
/// after filing it. Only the super-admin reads and updates.
class ReportService {
  ReportService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('reports');

  /// Files a new report against a user or an event.
  ///
  /// [targetLabel] is stored alongside the id so the admin queue can name what
  /// was reported even after the target is gone.
  static Future<void> submit({
    required String targetType,
    required String targetId,
    required String targetLabel,
    required String reason,
    String details = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('A report can only be filed by a signed-in user.');
    }

    // Resolved here rather than passed in by the calling screen: every entry
    // point would otherwise need its own copy of this lookup, and a report
    // filed with a blank reporter is far less useful to the admin reviewing
    // it. One read, on an action taken rarely.
    final reporterName = await _reporterName(uid);

    await _col.add({
      'reporterUid': uid,
      'reporterName': reporterName,
      'targetType': targetType,
      'targetId': targetId,
      'targetLabel': targetLabel,
      'reason': reason,
      'details': details.trim(),
      'status': Report.statusOpen,
      // serverTimestamp rather than the model's toMap, so ordering in the
      // queue doesn't depend on the reporter's device clock.
      'createdAt': FieldValue.serverTimestamp(),
      'resolvedBy': '',
      'resolvedAt': null,
    });
  }

  /// The reporter's display name, best-effort. A failed lookup must not stop
  /// the report being filed — an anonymous complaint still reaches the queue,
  /// which is better than losing it.
  static Future<String> _reporterName(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final full = (data['fullName'] as String? ?? '').trim();
      if (full.isNotEmpty) return full;
      return '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
    } catch (_) {
      return '';
    }
  }

  /// Whether this user has an open report already filed against [targetId].
  ///
  /// Used to stop the same person filing the same complaint repeatedly. This
  /// is the one read a non-admin is allowed, and only of their own reports —
  /// see the `reports` rule, which scopes it to `reporterUid == uid`.
  static Future<bool> hasOpenReport(String targetId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final existing = await _col
        .where('reporterUid', isEqualTo: uid)
        .where('targetId', isEqualTo: targetId)
        .where('status', isEqualTo: Report.statusOpen)
        .limit(1)
        .get();
    return existing.docs.isNotEmpty;
  }

  static Future<void> resolve(String reportId) =>
      _close(reportId, Report.statusResolved);

  static Future<void> dismiss(String reportId) =>
      _close(reportId, Report.statusDismissed);

  static Future<void> _close(String reportId, String status) async {
    await _col.doc(reportId).update({
      'status': status,
      'resolvedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }
}
