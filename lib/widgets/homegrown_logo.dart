// lib/widgets/homegrown_logo.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The "HG" wordmark — a gradient-filled text mark with no background
/// shape or frame. Proportions are derived from the golden ratio (φ ≈
/// 1.618) rather than picked by eye:
///   - Cap height  = [size] ÷ φ   (the letters occupy the larger of
///                                 the two golden-section parts of the
///                                 given box height)
///   - Tracking    = -[size] ÷ φ⁵ (a small negative letter-spacing,
///                                 scaled down the same ratio again,
///                                 so it tightens proportionally on
///                                 larger sizes instead of looking
///                                 loose)
///
/// Usage:
///   const HomegrownLogo(size: 120)               // splash screen hero
///   const HomegrownLogo(size: 64)                // role-select header
class HomegrownLogo extends StatelessWidget {
  /// The height of the box the wordmark is sized against — NOT the
  /// literal font size. Cap height is derived from this via φ.
  final double size;

  /// Gradient colors, top-left to bottom-right. Defaults to the
  /// app's existing accent → accent2 gradient for consistency with
  /// buttons and other branded surfaces.
  final List<Color>? colors;

  const HomegrownLogo({super.key, this.size = 120, this.colors});

  static const double _phi = 1.618033988749895;

  @override
  Widget build(BuildContext context) {
    final double fontSize = size / _phi;
    final double tracking = -size / (_phi * _phi * _phi * _phi * _phi);
    final gradientColors =
        colors ?? [AppTheme.accent, AppTheme.accent2];

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      ).createShader(bounds),
      child: Text(
        'HG',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: tracking,
          height: 1.0,
          // Overridden by ShaderMask — required so the widget has an
          // opaque base to mask against.
          color: Colors.white,
        ),
      ),
    );
  }
}