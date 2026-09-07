// lib/services/admin_user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// The super-admin's write access to other people's accounts.
///
/// Deliberately narrow. Firestore's rules let an admin touch exactly two
/// things on someone else's user document — `organizerStatus` (the approval
/// queue) and the three suspension fields below — and this service covers
/// only the second. Anything wider would need a matching rule, which is the
/// point: the rule is the real boundary, and keeping the client surface this
/// small makes the two easy to keep in agreement.
///
/// **Suspension is not account deletion.** Without Cloud Functions the app
/// cannot remove a Firebase Auth account, and deleting only the Firestore
/// document would leave a working login attached to no profile — strictly
/// worse than a suspension, which the app actually enforces at sign-in. Real
/// account removal stays an operator task; see
/// `functions/scripts/purge-orphaned-profiles.js`.
class AdminUserService {
  AdminUserService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection('users').doc(uid);

  /// Blocks [uid] from entering the app, recording why.
  ///
  /// [reason] is shown to the suspended user on the screen they are held on,
  /// so it should read as an explanation rather than an internal note.
  static Future<void> suspend(String uid, String reason) async {
    await _ref(uid).update({
      'suspended': true,
      'suspendedAt': FieldValue.serverTimestamp(),
      'suspendedReason': reason.trim(),
    });
  }

  /// Lifts a suspension.
  ///
  /// The fields are cleared rather than deleted so the write touches exactly
  /// the key set the security rule allows — `FieldValue.delete()` still counts
  /// as an affected key, but leaving the shape stable keeps the document and
  /// the rule describing the same three fields.
  static Future<void> reinstate(String uid) async {
    await _ref(uid).update({
      'suspended': false,
      'suspendedAt': null,
      'suspendedReason': '',
    });
  }
}
