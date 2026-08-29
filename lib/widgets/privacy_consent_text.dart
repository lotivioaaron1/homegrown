// lib/widgets/privacy_consent_text.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_links.dart';
import '../theme/app_theme.dart';

/// The consent line shown directly above a "Create Account" button.
///
/// Registration is the moment consent is actually given, so this is where the
/// policy has to be reachable — a link buried in Settings is something a user
/// only finds after they have already handed over their data. Google Play
/// looks for the policy in both places.
class PrivacyConsentText extends StatefulWidget {
  const PrivacyConsentText({super.key});

  @override
  State<PrivacyConsentText> createState() => _PrivacyConsentTextState();
}

class _PrivacyConsentTextState extends State<PrivacyConsentText> {
  // Held as a field so it can be disposed: a TapGestureRecognizer created
  // inline in build() leaks on every rebuild.
  late final TapGestureRecognizer _tap = TapGestureRecognizer()
    ..onTap = _openPolicy;

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  Future<void> _openPolicy() async {
    final opened = await AppLinks.open(AppLinks.privacyPolicy);
    if (!opened) {
      Get.snackbar(
        'Could not open the link',
        'Visit ${AppLinks.privacyPolicy} in your browser.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.card,
        colorText: AppTheme.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(color: AppTheme.muted, fontSize: 11.5, height: 1.5),
        children: [
          const TextSpan(text: 'By creating an account you agree to our '),
          TextSpan(
            text: 'Privacy Policy',
            recognizer: _tap,
            style: TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: AppTheme.accent,
            ),
          ),
          const TextSpan(
              text: ', which explains what we collect and how to delete it.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
