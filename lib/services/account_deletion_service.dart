// lib/services/account_deletion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thrown for expected, user-facing problems during deletion, so the UI can
/// show a clean message instead of a raw FirebaseException string.
class AccountDeletionException implements Exception {
  final String message;
  AccountDeletionException(this.message);
  @override
  String toString() => message;
}

/// Permanently deletes the signed-in user's account.
///
/// Google Play requires any app offering sign-up to also offer deletion, and
/// this is what satisfies that. It is deliberately NOT a hard delete of
/// everything the user touched: their uid appears inside other people's
/// records — the `sideA`/`sideB` arrays on matches, `athleteId` on stats,
/// `organizerId` on events — and erasing those would destroy opponents' game
/// history and delete events other people joined.
///
/// Instead every piece of *personal* data is erased and `users/{uid}` is
/// replaced by a minimal tombstone, so shared records still resolve to a name
/// ("Deleted user") and nobody else's history breaks. The retained records no
/// longer identify the person, which is what keeps this compliant.
///
/// Ordering is load-bearing: all Firestore and Storage work happens *before*
/// the Auth user is removed. Once that account is gone `request.auth` is null
/// and every security rule denies, stranding the data permanently.
class AccountDeletionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Firestore caps a batch at 500 writes; stay under it with headroom.
  static const int _batchSize = 400;

  /// True when the account signs in with a password rather than Google, and
  /// therefore needs the password supplied to re-authenticate.
  static bool get requiresPassword {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  /// Erases the current user's personal data, tombstones their profile, and
  /// deletes the Auth account.
  ///
  /// [password] is required for password accounts; Google accounts re-consent
  /// through the Google picker instead. [onProgress] reports a short status
  /// string for the UI.
  static Future<void> deleteAccount({
    String? password,
    void Function(String status)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AccountDeletionException('You are not signed in.');
    }
    final uid = user.uid;

    onProgress?.call('Confirming it\'s you');
    await _reauthenticate(user, password);

    onProgress?.call('Deleting your photos');
    await _deleteStorage(uid);

    onProgress?.call('Deleting your activity');
    await _deleteSubcollection(uid, 'media');
    await _deleteSubcollection(uid, 'ratingHistory');
    await _deleteQuery(_db.collection('notifications').where('userId', isEqualTo: uid));
    await _deleteQuery(
        _db.collection('teamMemberships').where('athleteId', isEqualTo: uid));
    await _deleteQuery(
        _db.collection('teamMemberships').where('coachId', isEqualTo: uid));

    onProgress?.call('Removing your profile');
    await _tombstone(uid);

    onProgress?.call('Closing your account');
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AccountDeletionException(
            'For security, please sign in again and retry deleting your account.');
      }
      throw AccountDeletionException(
          'Your data was removed but the account could not be closed. '
          'Sign in again and retry.');
    }
  }

  // ── Re-authentication ────────────────────────────
  // Firebase refuses to delete an account whose sign-in is more than a few
  // minutes old, so this is required rather than merely good practice. It
  // doubles as the confirmation step: proving identity is a better gate on a
  // destructive action than a checkbox.
  static Future<void> _reauthenticate(User user, String? password) async {
    try {
      if (requiresPassword) {
        if (password == null || password.isEmpty) {
          throw AccountDeletionException(
              'Enter your password to confirm.');
        }
        final cred = EmailAuthProvider.credential(
            email: user.email ?? '', password: password);
        await user.reauthenticateWithCredential(cred);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          throw AccountDeletionException('Deletion cancelled.');
        }
        final googleAuth = await googleUser.authentication;
        final cred = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(cred);
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw AccountDeletionException('That password is incorrect.');
        case 'user-mismatch':
          throw AccountDeletionException(
              'That Google account does not match the one you are signed in with.');
        case 'too-many-requests':
          throw AccountDeletionException(
              'Too many attempts. Wait a few minutes and try again.');
        default:
          throw AccountDeletionException(
              'Could not confirm your identity. Try again.');
      }
    }
  }

  // ── Storage ──────────────────────────────────────
  // Best-effort per object: a missing file is a fine outcome for a delete, and
  // one stray failure must not abort the rest of the erasure.
  static Future<void> _deleteStorage(String uid) async {
    await _deleteObject('profile_photos/$uid/photo.jpg');
    await _deleteObject('organizer_verification/$uid/document.jpg');
    await _deleteFolder('profile_media/$uid');
    await _deleteFolder('team_logos/$uid');
  }

  static Future<void> _deleteObject(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      debugPrint('AccountDeletionService: could not delete $path (${e.code})');
    }
  }

  static Future<void> _deleteFolder(String path) async {
    try {
      final listing = await _storage.ref(path).listAll();
      for (final item in listing.items) {
        await _deleteObject(item.fullPath);
      }
    } on FirebaseException catch (e) {
      debugPrint('AccountDeletionService: could not list $path (${e.code})');
    }
  }

  // ── Firestore ────────────────────────────────────
  static Future<void> _deleteSubcollection(String uid, String name) =>
      _deleteQuery(_db.collection('users').doc(uid).collection(name));

  /// Deletes every document a query matches, committing in chunks so a large
  /// result set cannot exceed Firestore's 500-write batch limit.
  static Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    final snap = await query.get();
    for (var i = 0; i < snap.docs.length; i += _batchSize) {
      final batch = _db.batch();
      final end = (i + _batchSize).clamp(0, snap.docs.length);
      for (final doc in snap.docs.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Replaces the profile with a minimal marker.
  ///
  /// Uses `set()` rather than `update()` with a field list on purpose: set
  /// overwrites the whole document, so no personal field can survive by being
  /// forgotten here. The three role-specific registration screens each write a
  /// different shape, and enumerating their fields would rot the moment one
  /// changes.
  ///
  /// `role` is carried over unchanged because firestore.rules only permits a
  /// self-update when the role is untouched.
  static Future<void> _tombstone(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final existing = await ref.get();
    final role = existing.data()?['role'] as String? ?? '';

    await ref.set({
      'uid': uid,
      'role': role,
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'fullName': 'Deleted user',
    });
  }
}
