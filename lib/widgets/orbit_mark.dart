// lib/widgets/orbit_mark.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Where the orbiting icon sits relative to the centre of the ring.
///
/// [turns] is a fraction of one revolution, measured clockwise from the top so
/// the icon starts at twelve o'clock rather than on the mark's flank — which
/// is where the bare `cos`/`sin` pair would put it.
///
/// A pure function on purpose: the geometry is the only part of this file with
/// real arithmetic in it, and this way it can be tested without pumping a
/// widget or rasterising a frame.
Offset orbitOffset({required double turns, required double radius}) {
  final theta = turns * 2 * math.pi - math.pi / 2;
  return Offset(math.cos(theta) * radius, math.sin(theta) * radius);
}

/// A centred mark ringed by a dashed orbit, with a small icon travelling
/// around it.
///
/// The mark arrives first, the ring draws itself on around it, and only then
/// does the icon start its lap — so the screen reads as one gesture settling
/// rather than three things appearing at once.
///
/// Takes the mark as a [child] instead of drawing one. The artwork at the
/// centre is still being replaced, and this way the animation does not depend
/// on knowing its shape: anything square-ish drops in without touching this
/// file.
class OrbitMark extends StatefulWidget {
  /// Overall extent. The ring is inset by [iconSize] so the travelling icon
  /// stays inside these bounds instead of being clipped at the edges.
  final double size;

  /// The mark at the centre.
  final Widget child;

  final IconData icon;
  final double iconSize;

  /// Defaults to the brand gold via [AppTheme.accent]. The splash passes its
  /// own ink because that screen commits to a fixed dark palette in both
  /// themes and cannot use the theme-aware getters.
  final Color? ringColor;
  final Color? iconColor;

  /// One full lap. Slow on purpose — this sits under a wordmark someone is
  /// reading, so it should register as ambient, not as something to watch.
  final Duration orbitDuration;

  const OrbitMark({
    super.key,
    required this.child,
    this.size = 168,
    this.icon = Icons.sports_basketball,
    this.iconSize = 26,
    this.ringColor,
    this.iconColor,
    this.orbitDuration = const Duration(milliseconds: 4200),
  });

  @override
  State<OrbitMark> createState() => _OrbitMarkState();
}

class _OrbitMarkState extends State<OrbitMark> with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _orbit;

  late final Animation<double> _markAnim;
  late final Animation<double> _ringAnim;

  /// Whether the OS asked for no motion. Resolved in didChangeDependencies
  /// because MediaQuery is not available during initState.
  bool _reducedMotion = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _orbit = AnimationController(vsync: this, duration: widget.orbitDuration);

    // The mark lands well before the ring finishes, so the ring reads as
    // being drawn *around* something already there.
    _markAnim = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    );
    _ringAnim = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.22, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_started) return;
    _started = true;

    if (_reducedMotion) {
      // Show the finished state. Leaving the repeating controller stopped
      // matters beyond honouring the setting: a permanently scheduled frame
      // means a widget test can never settle.
      _entrance.value = 1.0;
      return;
    }

    _entrance.forward().whenComplete(() {
      if (mounted) _orbit.repeat();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.ringColor ?? AppTheme.accent;
    final iconColor = widget.iconColor ?? AppTheme.accent;

    // Inset by the icon so a glyph sitting on the path is not half outside.
    final ringDiameter = widget.size - widget.iconSize;
    final ringRadius = ringDiameter / 2;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _orbit]),
        builder: (context, child) {
          final turns = _reducedMotion ? 0.0 : _orbit.value;
          final offset = orbitOffset(turns: turns, radius: ringRadius);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Ring
              SizedBox(
                width: ringDiameter,
                height: ringDiameter,
                child: CustomPaint(
                  painter: _DashedRingPainter(
                    sweep: _ringAnim.value,
                    color: ringColor,
                  ),
                ),
              ),

              // The mark, scaled up from just under full size. A larger scale
              // range reads as a bounce, which fights the calm this screen is
              // going for.
              Opacity(
                opacity: _markAnim.value,
                child: Transform.scale(
                  scale: 0.92 + (0.08 * _markAnim.value),
                  child: child,
                ),
              ),

              // Travelling icon. Fades in with the tail of the ring sweep so
              // it does not pop into existence at a random point on the path.
              Transform.translate(
                offset: offset,
                child: Opacity(
                  opacity: _ringAnim.value,
                  child: Icon(
                    widget.icon,
                    size: widget.iconSize,
                    color: iconColor,
                    // Decorative: the wordmark beside it already names the
                    // brand, so this must not be announced separately.
                    semanticLabel: null,
                  ),
                ),
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  /// 0 → nothing drawn, 1 → the full circle.
  final double sweep;
  final Color color;

  _DashedRingPainter({required this.sweep, required this.color});

  // 36 dashes divides 360° evenly, so the ring closes without a seam where
  // the last dash meets the first.
  static const int _dashCount = 36;
  static const double _dashFill = 0.55; // rest of each slot is the gap

  @override
  void paint(Canvas canvas, Size size) {
    if (sweep <= 0) return;

    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.55);

    const full = 2 * math.pi;
    const slot = full / _dashCount;
    const dash = slot * _dashFill;

    // Start at the top so the ring grows from where the eye already is.
    const start = -math.pi / 2;
    final drawn = full * sweep.clamp(0.0, 1.0);

    for (var i = 0; i < _dashCount; i++) {
      final slotStart = i * slot;
      if (slotStart >= drawn) break;

      // Clip the dash the sweep is currently partway through, so the ring
      // grows smoothly instead of one whole dash at a time.
      final length = math.min(dash, drawn - slotStart);
      canvas.drawArc(rect, start + slotStart, length, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) =>
      old.sweep != sweep || old.color != color;
}
