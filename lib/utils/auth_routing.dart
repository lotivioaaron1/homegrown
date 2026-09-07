// lib/utils/auth_routing.dart

// Where a signed-in user belongs, as a pure decision.
//
// Two places route a user after authentication — SplashScreen on a cold start
// and AuthController.signInWithEmail on a direct sign-in — and they have to
// agree. They previously each carried their own copy of the admin check and
// would drift apart the moment either changed; this is the one place that
// decision lives now.

const String kRouteHome        = '/home';
const String kRouteAdmin       = '/admin';
const String kRouteVerifyEmail = '/verify-email';
const String kRouteSuspended   = '/suspended';

/// Whether the account holds a password credential, given the provider ids on
/// a `FirebaseAuth` user (`user.providerData.map((p) => p.providerId)`).
///
/// Takes ids rather than the `User` itself so this file stays free of a
/// firebase_auth import and remains testable without a Firebase binding.
bool hasPasswordProvider(Iterable<String> providerIds) =>
    providerIds.contains('password');

/// Resolves the landing route for a user who has just authenticated.
///
/// [role] is the `role` field on their Firestore user doc, [emailVerified] is
/// `FirebaseAuth`'s flag for the current user, [hasPasswordProvider] is
/// whether they hold a password credential (as opposed to Google-only), and
/// [suspended] is the `suspended` field the super-admin sets from the account
/// directory.
///
/// The branch order below is load-bearing; see each comment for why.
String landingRoute({
  required String role,
  required bool emailVerified,
  required bool hasPasswordProvider,
  required bool suspended,
}) {
  // Admin is resolved before every other gate on purpose. There is no in-app
  // way to become an admin — the role is hand-set in the Firestore console —
  // so gating it buys no security, while a locked-out super-admin would have
  // no way back into the approval queue. That applies doubly to suspension:
  // only an admin can lift one, so an admin who landed on /suspended could
  // never reach the screen that would undo it.
  if (role == 'admin') return kRouteAdmin;

  // Ahead of the verification gate, because a suspended account has nothing
  // to gain from verifying its email — /suspended is the more accurate and
  // more actionable dead end of the two.
  //
  // Like the verification gate below, this is an in-app gate rather than a
  // security boundary: a script holding the same credentials still reads and
  // writes whatever the Firestore rules allow that account. Enforcing it in
  // the rules would mean an extra get() on the user document for every write
  // in the app, which is not a cost worth paying here.
  if (suspended) return kRouteSuspended;

  // Only password accounts can act on the verification screen. A Google-only
  // account has no password credential, so sendEmailVerification does nothing
  // for it and the screen's single action would be a dead end.
  if (!emailVerified && hasPasswordProvider) return kRouteVerifyEmail;

  return kRouteHome;
}
