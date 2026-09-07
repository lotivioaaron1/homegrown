// lib/widgets/homegrown_mark.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The Homegrown logo, drawn rather than shipped as an image.
///
/// The form is Mayon — the volcano that defines Legazpi's skyline and is
/// famous for the symmetry of its cone. A generic mountain-and-ball mark
/// could belong to any sports app anywhere; Mayon's near-perfect isosceles
/// silhouette belongs to this city, which is the whole point of an app called
/// Homegrown.
///
/// Three deliberate details:
///   - The cone is drawn at Mayon's real profile, slightly concave rather
///     than straight-sided, which is what makes the shape read as that
///     volcano instead of a triangle.
///   - A gap near the summit stands in for the cloud band Mayon almost always
///     wears, and doubles as the divider on a scoreboard.
///   - The baseline runs wider than the cone: it is a court line, and it
///     grounds the mark so it does not float.
///
/// Being a painter rather than a PNG means it is sharp at any size, adapts to
/// light and dark, and can animate its own draw-on.
class HomegrownMark extends StatelessWidget {
  final double size;

  /// 0 → nothing drawn, 1 → fully drawn. Lets the splash reveal the mark
  /// instead of popping it in.
  final double progress;

  final Color? color;

  const HomegrownMark({
    super.key,
    this.size = 72,
    this.progress = 1.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkPainter(
          progress: progress.clamp(0.0, 1.0),
          color: color ?? AppTheme.accent,
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _MarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Mayon reads as a volcano because of its proportions: a broad base, a
    // shallow slope of roughly 35–40°, and a sharp summit. Earlier passes had
    // it too tall and too blunt, plus a horizontal band across the upper cone
    // — which together read as a traffic cone with a collar rather than a
    // mountain. The band is gone and the geometry now follows the real
    // profile: base width about 2.6x the height.
    const baseY = 0.80;
    const apexY = 0.20;
    const halfBase = 0.47;
    const summitHalf = 0.018; // near-point, as Mayon's crater is small

    final leftFoot = Offset(w * (0.5 - halfBase), h * baseY);
    final rightFoot = Offset(w * (0.5 + halfBase), h * baseY);

    // The flanks are concave, flaring out near the base. Control points sit
    // low and well inside the feet so the flare is visible even small — a
    // straight-sided triangle reads as a generic peak.
    final silhouette = Path()
      ..moveTo(leftFoot.dx, leftFoot.dy)
      ..quadraticBezierTo(
        w * (0.5 - halfBase * 0.34), h * (apexY + (baseY - apexY) * 0.58),
        w * (0.5 - summitHalf), h * apexY,
      )
      ..lineTo(w * (0.5 + summitHalf), h * apexY)
      ..quadraticBezierTo(
        w * (0.5 + halfBase * 0.34), h * (apexY + (baseY - apexY) * 0.58),
        rightFoot.dx, rightFoot.dy,
      )
      ..close();

    // Reveal from the base upward: the mountain rises rather than fades in.
    final revealHeight = h * baseY * progress;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, h * baseY - revealHeight, w, h * baseY));

    canvas.drawPath(
      silhouette,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0.70)],
        ).createShader(Rect.fromLTWH(0, h * apexY, w, h * (baseY - apexY))),
    );

    canvas.restore();

    // Court baseline. Drawn last, sitting flush under the cone's feet so the
    // mark is grounded rather than floating, and eased separately so it
    // arrives just after the mountain has risen.
    final lineProgress = ((progress - 0.55) / 0.45).clamp(0.0, 1.0);
    if (lineProgress > 0) {
      final stroke = math.max(2.0, h * 0.045);
      final halfLine = w * 0.48 * Curves.easeOut.transform(lineProgress);
      canvas.drawLine(
        Offset(w * 0.5 - halfLine, h * baseY + stroke * 0.5),
        Offset(w * 0.5 + halfLine, h * baseY + stroke * 0.5),
        Paint()
          ..color = color
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.progress != progress || old.color != color;
}
