// lib/services/contact_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_helpers.dart';

/// A user's contact details, held apart from their public profile.
typedef ContactDetails = ({String email, String phoneNumber});

/// Reads and writes `users/{uid}/private/contact`.
///
/// Email and phone number used to sit on the user document itself, which every
/// signed-in account can read — leaderboards, Scout, rosters and profile
/// sheets all legitimately need a stranger's name, role and sport, and
/// Firestore read rules are document-level, so there is no way to serve those
/// fields while withholding the contact ones. Moving contact details into a
/// subcollection with its own rule is what makes the distinction expressible:
/// the public half stays readable, this half is owner-and-admin only.
class ContactService {
  ContactService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// The single document holding one user's contact details.
  static DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('contact');

  /// Writes (or overwrites) a user's contact details.
  ///
  /// Callers are registration paths, which write the public profile document
  /// and this one together. Kept as a merge so a later phone-number edit does
  /// not have to resupply the email.
  static Future<void> write({
    required String uid,
    required String email,
    String phoneNumber = '',
  }) async {
    await _ref(uid).set({
      'email': email,
      'phoneNumber': phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Reads a user's contact details, falling back to the legacy top-level
  /// fields on their profile document.
  ///
  /// [legacyProfile] is the already-fetched `users/{uid}` data when the caller
  /// has it — passing it avoids a second read on accounts that predate the
  /// split. The fallback exists because the backfill and the client rollout
  /// cannot land at the same instant: until every old document is migrated,
  /// an admin opening the approval queue would otherwise see blank contact
  /// details for exactly the organizers who registered before this shipped.
  ///
  /// Once the migration has run with --delete-legacy, this fallback is dead
  /// weight and the `legacyProfile` parameter can be dropped.
  static Future<ContactDetails> read(
    String uid, {
    Map<String, dynamic>? legacyProfile,
  }) async {
    final snap = await _ref(uid).get();
    final data = snap.data();
    if (data != null) {
      return (
        email: asString(data['email']),
        phoneNumber: asString(data['phoneNumber']),
      );
    }
    return contactFromLegacyProfile(legacyProfile);
  }

  /// Pulls contact details out of a pre-split profile document.
  ///
  /// Separate from [read] so the fallback shape can be tested without a
  /// Firestore binding, and so the migration script's expectations and the
  /// app's agree on which field names count as legacy.
  static ContactDetails contactFromLegacyProfile(
      Map<String, dynamic>? profile) {
    return (
      email: asString(profile?['email']),
      phoneNumber: asString(profile?['phoneNumber']),
    );
  }
}
