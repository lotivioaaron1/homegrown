// lib/widgets/gradient_button.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The primary call to action: a full-width gold gradient button that dips
/// slightly when pressed.
///
/// `ElevatedButton` cannot carry a gradient — its `backgroundColor` is a flat
/// colour — so the fill is an `Ink` decoration with an `InkWell` over it,
/// which keeps the ripple and the button semantics a bare `GestureDetector`
/// would lose.
///
/// The press dip is the same idea as the tile at home_screen.dart:1808, just
/// gentler: 0.86 reads as playful on a small square and as unstable on a
/// full-width bar.
class GradientButton extends StatefulWidget {
  /// Null disables the button — it stops responding and drops to a flat muted
  /// fill, so it never looks tappable while inert.
  final VoidCallback? onPressed;

  final Widget child;
  final double height;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 54,
    this.borderRadius = 16,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final radius = BorderRadius.circular(widget.borderRadius);

    return AnimatedScale(
      // Only the enabled button reacts; scaling a dead control still reads as
      // a response and invites a second tap.
      scale: _pressed && enabled ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: enabled
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.accent, AppTheme.accent2],
                    )
                  : null,
              color: enabled ? null : AppTheme.border,
            ),
            child: InkWell(
              onTap: widget.onPressed,
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              borderRadius: radius,
              child: Center(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: enabled ? AppTheme.buttonFg : AppTheme.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
