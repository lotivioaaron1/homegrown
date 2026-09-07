// lib/screens/auth/suspended_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/firestore_helpers.dart';

/// Where a suspended account is held, in place of the app.
///
/// `landingRoute` sends any non-admin user carrying `suspended: true` here,
/// ahead of the email-verification gate — verifying an email does nothing for
/// a suspended account, so routing them there would name the wrong problem.
///
/// The reason is read live rather than passed as a route argument so that a
/// reinstatement lands without the user having to guess when to try again:
/// the moment an admin lifts the suspension, this screen swaps itself for a
/// "you're back in" state.
class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: uid == null
                  ? null
                  : FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? const {};
                // Default to still-suspended while the document is loading.
                // Briefly flashing "you're back in" at someone who isn't would
                // be a much worse error than a moment of the correct message.
                final lifted = snapshot.hasData && data['suspended'] != true;
                final reason = asString(data['suspendedReason']).trim();

                return lifted
                    ? _liftedBody()
                    : _suspendedBody(reason);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _suspendedBody(String reason) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _icon(LucideIcons.ban, AppTheme.error, AppTheme.errorSurface),
          const SizedBox(height: 24),
          Text('Your account is suspended',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            reason.isEmpty
                ? 'An administrator has paused access to this account. '
                    'Get in touch with the Homegrown organizers to sort it out.'
                : reason,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.sub, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 28),
          _signOutButton(),
        ],
      );

  Widget _liftedBody() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _icon(LucideIcons.circleCheck, AppTheme.success,
              AppTheme.successSurface),
          const SizedBox(height: 24),
          Text("You're back in",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            'The suspension on this account has been lifted. '
            'Sign in again to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.sub, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 28),
          _signOutButton(label: 'Sign in again'),
        ],
      );

  Widget _icon(IconData icon, Color tint, Color surface) => Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
        child: Icon(icon, color: tint, size: 32),
      );

  /// The only action either state offers. Signing out is what actually gets a
  /// reinstated user back into the app — `landingRoute` re-runs on the next
  /// sign-in and, with the flag cleared, sends them to /home.
  Widget _signOutButton({String label = 'Sign out'}) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => AuthController.to.signOut(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.buttonFg,
            padding: const EdgeInsets.symmetric(vertical: 15),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      );
}
