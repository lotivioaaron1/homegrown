// lib/screens/auth/email_verification_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer?  _pollTimer;
  bool    _isChecking  = false;
  bool    _isResending = false;
  int     _cooldown    = 0;
  Timer?  _cooldownTimer;

  static const _kMaxFormWidth = 440.0; // caps width on tablets/large screens

  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    // Poll every 3s to auto-detect verification without user tapping
    _pollTimer = Timer.periodic(
        const Duration(seconds: 3), (_) => _silentCheck());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentCheck() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
      _pollTimer?.cancel();
      if (mounted) Get.offAllNamed('/home');
    }
  }

  Future<void> _checkNow() async {
    setState(() => _isChecking = true);
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (mounted) setState(() => _isChecking = false);

    if (verified) {
      Get.offAllNamed('/home');
    } else {
      Get.snackbar(
        'Not Verified Yet',
        'Please check your inbox and click the verification link.',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: AppTheme.card,
        colorText:       AppTheme.textPrimary,
        margin:          const EdgeInsets.all(16),
        borderRadius:    12,
      );
    }
  }

  Future<void> _resendEmail() async {
    if (_cooldown > 0) return;
    setState(() => _isResending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      Get.snackbar(
        'Email Sent ✉️',
        'A new verification link was sent to $_email',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: AppTheme.accentSurface,
        colorText:       AppTheme.accentText,
        margin:          const EdgeInsets.all(16),
        borderRadius:    12,
      );
      _startCooldown();
    } catch (e) {
      Get.snackbar(
        'Error',
        friendlyError(e),
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF2A1A1A),
        colorText:       const Color(0xFFFF5C5C),
        margin:          const EdgeInsets.all(16),
        borderRadius:    12,
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  void _signOut() {
    FirebaseAuth.instance.signOut();
    Get.offAllNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Same scaling as the other auth screens instead of a flat 28.
    final horizontalPadding = (size.width * 0.07).clamp(20.0, 32.0);
    final isCompactHeight = size.height < 700;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: ConstrainedBox(
                // Guarantees at least a full viewport tall so the centered
                // content still sits mid-screen instead of collapsing to
                // the top, while still scrolling if content ever overflows
                // (large system font sizes, small phones).
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── Icon ──────────────────────
                        Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.accentSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.accent, width: 2)),
                          child: const Center(
                              child: Icon(LucideIcons.mailCheck,
                                  color: AppTheme.accent, size: 42)),
                        ),

                        const SizedBox(height: 32),

                        Text('Verify Your Email', textAlign: TextAlign.center,
                          style: TextStyle(
                            color:      AppTheme.textPrimary,
                            fontSize:   24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4)),

                        const SizedBox(height: 12),

                        Text(
                          "We've sent a verification link to",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.sub, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(_email, textAlign: TextAlign.center,
                          style: const TextStyle(
                            color:      AppTheme.accent,
                            fontSize:   15,
                            fontWeight: FontWeight.w700)),

                        const SizedBox(height: 28),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(LucideIcons.info,
                                  color: AppTheme.muted, size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Text(
                                "Click the link in your email, then return here. "
                                "This screen will update automatically once verified.",
                                style: TextStyle(
                                    color: AppTheme.sub, fontSize: 12, height: 1.5))),
                            ]),
                        ),

                        const SizedBox(height: 28),

                        // ── I've verified button ──────
                        SizedBox(
                          width: double.infinity, height: 54,
                          child: ElevatedButton(
                            onPressed: _isChecking ? null : _checkNow,
                            child: _isChecking
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: AppTheme.buttonFg))
                                : const Text("I've Verified — Continue"),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Resend ─────────────────────
                        GestureDetector(
                          onTap: (_isResending || _cooldown > 0) ? null : _resendEmail,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: _isResending
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppTheme.accent))
                                : Text(
                                    _cooldown > 0
                                        ? 'Resend available in ${_cooldown}s'
                                        : "Didn't get it? Resend Email",
                                    style: TextStyle(
                                      color: _cooldown > 0
                                          ? AppTheme.muted : AppTheme.accent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── Sign out / change account ─
                        GestureDetector(
                          onTap: _signOut,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('Use a different account',
                                style: TextStyle(color: AppTheme.sub, fontSize: 13)),
                          ),
                        ),

                        SizedBox(height: isCompactHeight ? 20 : 28),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}