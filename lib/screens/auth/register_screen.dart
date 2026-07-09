// lib/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),

              // ── Logo ──────────────────────────
              Container(
                width:  64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                    colors: [AppTheme.accent, AppTheme.accent2],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color:        AppTheme.accent.withValues(alpha: 0.3),
                      blurRadius:   20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'HG',
                    style: TextStyle(
                      color:      AppTheme.buttonFg,
                      fontSize:   22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Join Homegrown',
                style: TextStyle(
                  color:         AppTheme.textPrimary,
                  fontSize:      26,
                  fontWeight:    FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Choose how you want to participate',
                style: TextStyle(color: AppTheme.sub, fontSize: 14),
              ),

              const SizedBox(height: 40),

              // ── Role cards ────────────────────
              _RoleCard(
                emoji:       '🏃',
                label:       'Athlete',
                description: 'Track stats, earn points,\nget discovered by coaches',
                onTap:       () => Get.toNamed('/register/athlete'),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                emoji:       '🧢',
                label:       'Coach',
                description: 'Scout talent, manage your\nroster and team lineup',
                onTap:       () => Get.toNamed('/register/coach'),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                emoji:       '📋',
                label:       'Organizer',
                description: 'Create events, manage\ntournaments and venues',
                onTap:       () => Get.toNamed('/register/organizer'),
              ),

              const Spacer(),

              // ── Sign In link ──────────────────
              GestureDetector(
                onTap: () => Get.offNamed('/login'),
                child: RichText(
                  text: TextSpan(
                    text:  'Already have an account?  ',
                    style: TextStyle(
                        color: AppTheme.sub, fontSize: 14),
                    children: const [
                      TextSpan(
                        text:  'Sign In',
                        style: TextStyle(
                          color:      AppTheme.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Role Card
// ─────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String       emoji;
  final String       label;
  final String       description;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:        AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppTheme.border, width: 1.5),
        ),
        child: Row(
          children: [
            // Icon box
            Container(
              width:  50,
              height: 50,
              decoration: BoxDecoration(
                color:        AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(14),
                border:       Border.all(color: AppTheme.border),
              ),
              child: Center(
                child: Text(emoji,
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color:      AppTheme.textPrimary,
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color:    AppTheme.sub,
                      fontSize: 12,
                      height:   1.5,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.muted,
              size:  16,
            ),
          ],
        ),
      ),
    );
  }
}