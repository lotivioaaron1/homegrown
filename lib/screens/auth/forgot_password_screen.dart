// lib/screens/auth/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  bool _isLoading    = false;
  bool _emailSent    = false;
  int  _cooldown     = 0;

  static const _kRadius   = 14.0;
  static const _kErrorRed = Color(0xFFFF5C5C);

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Send reset email ──────────────────────

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      setState(() { _emailSent = true; });
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      _snack('Error', _mapError(e.code), isError: true);
    } catch (e) {
      _snack('Error', 'Something went wrong. Please try again.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      _startCooldown();
      _snack('Email Sent ✉️',
          'A new reset link was sent to ${_emailCtrl.text.trim()}');
    } on FirebaseAuthException catch (e) {
      _snack('Error', _mapError(e.code), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _cooldown--);
      return _cooldown > 0;
    });
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Failed to send reset email. Please try again.';
    }
  }

  void _snack(String t, String m, {bool isError = false}) {
    Get.snackbar(t, m,
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: isError ? const Color(0xFF2A1A1A) : AppTheme.card,
      colorText:       isError ? _kErrorRed : AppTheme.textPrimary,
      margin:          const EdgeInsets.all(16),
      borderRadius:    12,
      duration:        const Duration(seconds: 3));
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border)),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.textPrimary, size: 16)),
              ),
            ]),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _emailSent
                  ? _buildSuccessView()
                  : _buildFormView(),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Form view ─────────────────────────────

  Widget _buildFormView() {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 48),

            // Icon
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color:  AppTheme.accentSurface,
                shape:  BoxShape.circle,
                border: Border.all(color: AppTheme.accent, width: 2)),
              child: const Center(
                  child: Text('🔐', style: TextStyle(fontSize: 38))),
            ),

            const SizedBox(height: 28),

            Text('Forgot Password?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:         AppTheme.textPrimary,
                fontSize:      26,
                fontWeight:    FontWeight.w900,
                letterSpacing: -0.4)),

            const SizedBox(height: 10),

            Text(
              "Enter the email address associated with\n"
              "your account and we'll send you a\n"
              "password reset link.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.sub, fontSize: 14, height: 1.6)),

            const SizedBox(height: 36),

            // Email field
            TextFormField(
              controller:      _emailCtrl,
              keyboardType:    TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendReset(),
              style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText:   'Email address',
                hintStyle:  TextStyle(color: AppTheme.muted, fontSize: 14),
                prefixIcon: Icon(Icons.mail_outline_rounded,
                    color: AppTheme.muted, size: 20),
                filled:    true,
                fillColor: AppTheme.card,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_kRadius),
                    borderSide:   BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_kRadius),
                    borderSide:
                        BorderSide(color: AppTheme.border, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_kRadius),
                    borderSide: const BorderSide(
                        color: AppTheme.accent, width: 1.5)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_kRadius),
                    borderSide: const BorderSide(
                        color: _kErrorRed, width: 1.5)),
                focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_kRadius),
                    borderSide: const BorderSide(
                        color: _kErrorRed, width: 1.5)),
                errorStyle: const TextStyle(
                    color: _kErrorRed, fontSize: 12),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Email is required';
                if (!GetUtils.isEmail(v.trim()))
                  return 'Enter a valid email address';
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Send button
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendReset,
                child: _isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color:       AppTheme.buttonFg))
                    : const Text('Send Reset Link'),
              ),
            ),

            const SizedBox(height: 24),

            // Back to login
            GestureDetector(
              onTap: () => Get.back(),
              child: RichText(
                text: TextSpan(
                  text:  'Remember your password?  ',
                  style: TextStyle(
                      color: AppTheme.sub, fontSize: 14),
                  children: const [
                    TextSpan(
                      text: 'Sign In',
                      style: TextStyle(
                        color:      AppTheme.accent,
                        fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Success view ──────────────────────────

  Widget _buildSuccessView() {
    return SingleChildScrollView(
      key: const ValueKey('success'),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 48),

          // Animated checkmark icon
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color:  const Color(0xFF0D2E20),
              shape:  BoxShape.circle,
              border: Border.all(color: AppTheme.success, width: 2)),
            child: const Center(
                child: Text('✅', style: TextStyle(fontSize: 38))),
          ),

          const SizedBox(height: 28),

          Text('Check Your Email',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:         AppTheme.textPrimary,
              fontSize:      26,
              fontWeight:    FontWeight.w900,
              letterSpacing: -0.4)),

          const SizedBox(height: 10),

          Text(
            "We sent a password reset link to",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.sub, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            _emailCtrl.text.trim(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color:      AppTheme.accent,
              fontSize:   15,
              fontWeight: FontWeight.w700)),

          const SizedBox(height: 28),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: AppTheme.border)),
            child: Column(children: [
              _InfoRow(
                icon:  Icons.inbox_rounded,
                text:  'Check your email inbox (and spam folder)',
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon:  Icons.touch_app_rounded,
                text:  'Click the reset link in the email',
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon:  Icons.lock_reset_rounded,
                text:  'Create a new password and sign in',
              ),
            ]),
          ),

          const SizedBox(height: 28),

          // Back to sign in
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: () => Get.offAllNamed('/login'),
              child: const Text('Back to Sign In'),
            ),
          ),

          const SizedBox(height: 16),

          // Resend
          GestureDetector(
            onTap: _cooldown > 0 ? null : _resend,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _isLoading
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.accent))
                  : Text(
                      _cooldown > 0
                          ? "Resend available in ${_cooldown}s"
                          : "Didn't get it? Resend Email",
                      style: TextStyle(
                        color: _cooldown > 0
                            ? AppTheme.muted : AppTheme.accent,
                        fontSize:   13,
                        fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Info Row Widget
// ─────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color:        AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: AppTheme.accent)),
          child: Icon(icon, color: AppTheme.accent, size: 16)),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(text, style: TextStyle(
                color:  AppTheme.textPrimary,
                fontSize: 13, height: 1.4)),
          ),
        ),
      ]);
  }
}