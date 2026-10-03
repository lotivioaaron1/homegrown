// lib/widgets/privacy_consent_text.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_links.dart';
import '../theme/app_theme.dart';

/// The consent line shown directly above the button that creates an account:
/// agreement to the Terms of Use and the Privacy Policy, each a link.
///
/// Registration is the moment consent is actually given, so this is where both
/// documents have to be reachable — a link buried in Settings is something a
/// user only finds after they have already handed over their data. Google Play
/// looks for the policy in both places.
class PrivacyConsentText extends StatefulWidget {
  /// What the user is doing that counts as agreeing.
  ///
  /// "By creating an account" on the registration screens. Google sign-ups
  /// already have an account by the time they see this, so their setup screen
  /// says "By continuing" instead.
  final String lead;

  const PrivacyConsentText({super.key, this.lead = 'By creating an account'});

  @override
  State<PrivacyConsentText> createState() => _PrivacyConsentTextState();
}

class _PrivacyConsentTextState extends State<PrivacyConsentText> {
  // Held as fields so they can be disposed: a TapGestureRecognizer created
  // inline in build() leaks on every rebuild.
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => _open(AppLinks.terms);
  late final TapGestureRecognizer _policyTap = TapGestureRecognizer()
    ..onTap = () => _open(AppLinks.privacyPolicy);

  @override
  void dispose() {
    _termsTap.dispose();
    _policyTap.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final opened = await AppLinks.open(url);
    if (!opened) {
      Get.snackbar(
        'Could not open the link',
        'Visit $url in your browser.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.card,
        colorText: AppTheme.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 5),
      );
    }
  }

  static const _linkStyle = TextStyle(
    color: AppTheme.accent,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
    decorationColor: AppTheme.accent,
  );

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(color: AppTheme.muted, fontSize: 11.5, height: 1.5),
        children: [
          TextSpan(text: '${widget.lead} you agree to our '),
          TextSpan(
            text: 'Terms of Use',
            recognizer: _termsTap,
            style: _linkStyle,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            recognizer: _policyTap,
            style: _linkStyle,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
