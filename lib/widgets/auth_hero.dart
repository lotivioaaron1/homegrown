// lib/widgets/auth_hero.dart
import 'package:flutter/material.dart';

/// The photographic band at the top of an auth screen.
///
/// Login and the signup role picker both open on one, which is why this is a
/// widget rather than a private method on either. The scrim below is the part
/// worth sharing: its shape is the result of getting it wrong once, and it is
/// not obvious enough to reproduce correctly from memory.
class AuthHero extends StatelessWidget {
  /// The photograph. The three `onboard_*.jpg` assets are the intended
  /// source — they already ship, and reusing them keeps the auth flow
  /// photographic like the rest of the app.
  final String asset;

  final double height;

  /// Where the cover crop sits. Worth setting per photograph rather than
  /// leaving centred: these are tall portrait frames being shown in a short
  /// wide window, so the default centre crop lands on whatever happens to be
  /// halfway down — on the basketball frame, the player's shorts.
  final Alignment alignment;

  /// Optional content over the photograph, inset from the status bar.
  final Widget? child;

  const AuthHero({
    super.key,
    required this.asset,
    required this.height,
    this.alignment = Alignment.center,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: alignment,
            // Falls back to a themed gradient if the asset is missing, the
            // same way the onboarding panels do, so layout never breaks.
            errorBuilder: (context, error, stackTrace) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1200), Color(0xFF0F0F1A)],
                ),
              ),
            ),
          ),

          // Two jobs, and only two: keep the system status bar's white icons
          // legible against a bright photograph, and darken the bottom edge so
          // what sits below does not cut against a light band. The middle is
          // left nearly clear — a flat scrim across the whole photograph
          // washed it out to grey and took the picture with it.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.30, 0.72, 1.0],
                colors: [
                  const Color(0xFF07070C).withValues(alpha: 0.62),
                  const Color(0xFF07070C).withValues(alpha: 0.16),
                  const Color(0xFF07070C).withValues(alpha: 0.10),
                  const Color(0xFF07070C).withValues(alpha: 0.46),
                ],
              ),
            ),
          ),

          if (child != null)
            SafeArea(bottom: false, child: child!),
        ],
      ),
    );
  }
}
