// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fill_viewport_scroll.dart';

/// Deliberately not built like login.
///
/// A photographic header was tried here, to make signup read as login's
/// sibling. It is gone by preference: this screen is a set of choices, and the
/// cards are what should carry it, so it keeps its own plain ground rather
/// than borrowing the hero-and-sheet construction from the screen before it.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        // Scrolls rather than overflows. The cards fit on a normal phone, but
        // three of them plus a two-line subtitle do not survive the largest
        // system text sizes. Invisible while it fits, and the Spacer still
        // pushes the sign-in link down whenever there is room.
        child: FillViewportScroll(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 56),
              Text(
                'Where do you fit in?',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Athletes compete. Coaches scout.\nOrganizers run the show.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppTheme.sub, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 36),
              _RoleCard(
                icon: LucideIcons.zap,
                iconColor: const Color(0xFFFF8A34),
                label: 'Athlete',
                description:
                    'Track stats, earn points,\nget discovered by coaches',
                onTap: () => Get.toNamed('/register/athlete'),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                icon: LucideIcons.binoculars,
                iconColor: const Color(0xFF4AB3FF),
                label: 'Coach',
                description:
                    'Scout talent, manage your\nroster and team lineup',
                onTap: () => Get.toNamed('/register/coach'),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                icon: LucideIcons.calendarDays,
                iconColor: const Color(0xFF5FE0A0),
                label: 'Organizer',
                description: 'Create events, manage\ntournaments and venues',
                onTap: () => Get.toNamed('/register/organizer'),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Get.offNamed('/login'),
                child: RichText(
                  text: TextSpan(
                    text: 'Already have an account?  ',
                    style: TextStyle(color: AppTheme.sub, fontSize: 14),
                    children: const [
                      TextSpan(
                        text: 'Sign In',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final VoidCallback onTap;
  const _RoleCard({
    required this.icon,
    required this.iconColor,
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
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 1.5),
        ),
        child: Row(
          children: [
            // Icon badge — outline glyph over a soft tinted surface,
            // same treatment used across the Features and Sport
            // Selection cards for a consistent icon system.
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    iconColor.withValues(alpha: 0.22),
                    iconColor.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: iconColor.withValues(alpha: 0.32)),
              ),
              child: Icon(icon, size: 22, color: iconColor),
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
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppTheme.sub,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: AppTheme.muted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
