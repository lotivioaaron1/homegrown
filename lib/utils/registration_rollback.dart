// lib/utils/registration_rollback.dart

// Registration is two systems in sequence: Firebase Auth creates the account,
// then Firestore stores the profile behind it. Only the first is atomic. If a
// Firestore write fails afterwards, the Auth account survives with nothing
// behind it, and the person is locked out of their own email address forever —
// every retry fails with 'email-already-in-use' against an account they cannot
// use and cannot see.
//
// athlete_register_screen's _uploadProfilePhoto already avoided this by
// swallowing its own failures, but that only works because a missing avatar is
// recoverable later from Edit Profile. The profile document and the contact
// details are not optional in that way, so they need the opposite treatment:
// undo the account and let the person try again cleanly.

/// Runs the writes a new account cannot function without, deleting the account
/// itself if any of them fail.
///
/// [writes] should contain only writes that are genuinely required; anything
/// recoverable later belongs outside it, so a transient failure doesn't throw
/// away an otherwise good registration.
Future<void> withRegistrationRollback({
  required Future<void> Function() writes,
  required Future<void> Function() deleteAccount,
}) async {
  try {
    await writes();
  } catch (_) {
    // A failed rollback leaves the stranded account this exists to prevent,
    // but there is nothing further the client can do about it, and reporting
    // the cleanup error would bury the failure the user actually needs to see.
    try {
      await deleteAccount();
    } catch (_) {
      // Intentionally ignored — see above.
    }
    rethrow;
  }
}
