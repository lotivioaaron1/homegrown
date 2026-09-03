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
/// `FirebaseAuth`'s flag for the current user, and [hasPasswordProvider] is
/// whether they hold a password credential (as opposed to Google-only).
String landingRoute({
  required String role,
  required bool emailVerified,
  required bool hasPasswordProvider,
}) {
  // Admin is resolved before the verification gate on purpose. There is no
  // in-app way to become an admin — the role is hand-set in the Firestore
  // console — so gating it buys no security, while a locked-out super-admin
  // would have no way back into the approval queue.
  if (role == 'admin') return kRouteAdmin;

  // Only password accounts can act on the verification screen. A Google-only
  // account has no password credential, so sendEmailVerification does nothing
  // for it and the screen's single action would be a dead end.
  if (!emailVerified && hasPasswordProvider) return kRouteVerifyEmail;

  return kRouteHome;
}
