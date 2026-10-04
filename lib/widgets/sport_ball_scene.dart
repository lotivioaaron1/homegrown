// lib/widgets/sport_ball_scene.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Where the balls in a [SportBallScene] come to rest.
///
/// The splash has two looks, and the balls are arranged for what sits
/// beneath them in each.
enum SportBallLayout {
  /// Spread over the space above a left-aligned headline: the basketball high
  /// on the left, the volleyball lower on the right, and the shuttlecock low
  /// in between. The opening screen's arrangement.
  overHeadline,

  /// A V around a wordmark centred below them: the basketball and the
  /// volleyball high on either side, and the shuttlecock between them
  /// pointing down at it. The arrangement after Sign out.
  aroundCentre,
}

/// The welcome scene: a basketball, a volleyball and a shuttlecock, one per
/// sport the app covers, dropping in from above the screen and then hanging in
/// the air.
///
/// Each moves like the thing it is. The basketball falls and bounces highest,
/// the softer volleyball comes back lower and settles sooner, and the
/// shuttlecock does not bounce at all: it floats down cork first, as a real
/// one does, and rocks to a stop.
///
/// Drawn rather than shipped as artwork so the seams can turn while the light
/// stays put. A ball exported as a picture has its shading baked in, so
/// spinning it spins the highlight and the shadow with it, which no ball under
/// a fixed light does. Every ball here is lit from the same top-right point and
/// only the seams move, which is also what makes the three read as one scene
/// rather than three stickers.
///
/// It paints outside its own box on purpose. The splash gives it the half of
/// the screen above the wordmark, and a ball only ever bounces upwards from
/// where it comes to rest, so none can end up behind the wordmark; [bleed]
/// reaches past the column's side padding so the balls can run off the screen
/// edges, and each starts its fall above the box's top edge, off the screen.
///
/// Decorative, so it is hidden from screen readers.
class SportBallScene extends StatefulWidget {
  /// Drives the arrival, 0 (nothing on screen) to 1 (every ball at rest).
  ///
  /// Each ball takes its own slice of it, so one animation staggers all three.
  final Animation<double> entrance;

  /// Whether the balls drift once they have arrived.
  ///
  /// Only worth it while someone is looking at the scene with nothing else
  /// happening — the welcome state, not the launch — so the caller decides.
  final bool idle;

  /// Holds the balls perfectly still. The caller is expected to have finished
  /// [entrance] already, which is how the splash presents its end state.
  final bool reducedMotion;

  /// How far past its left and right edges the scene paints.
  final double bleed;

  /// Where the balls come to rest, which depends on what sits beneath them.
  final SportBallLayout layout;

  const SportBallScene({
    super.key,
    required this.entrance,
    this.idle = false,
    this.reducedMotion = false,
    this.bleed = 0,
    this.layout = SportBallLayout.overHeadline,
  });

  @override
  State<SportBallScene> createState() => _SportBallSceneState();
}

class _SportBallSceneState extends State<SportBallScene>
    with SingleTickerProviderStateMixin {
  /// One loop of the idle drift. Slow enough to read as hanging in the air
  /// rather than bobbing.
  static const _kDriftPeriod = Duration(seconds: 6);

  late final AnimationController _drift =
      AnimationController(vsync: this, duration: _kDriftPeriod);

  @override
  void initState() {
    super.initState();
    _syncDrift();
  }

  @override
  void didUpdateWidget(SportBallScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idle != widget.idle ||
        oldWidget.reducedMotion != widget.reducedMotion) {
      _syncDrift();
    }
  }

  void _syncDrift() {
    if (widget.idle && !widget.reducedMotion) {
      if (!_drift.isAnimating) _drift.repeat();
    } else {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([widget.entrance, _drift]),
          builder: (context, _) => CustomPaint(
            painter: SportBallScenePainter(
              entrance: widget.entrance.value,
              drift: _drift.value,
              bleed: widget.bleed,
              layout: widget.layout,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the whole scene for one moment of the arrival and the drift.
///
/// Public for the tests, which check it repaints only when what it shows has
/// changed.
class SportBallScenePainter extends CustomPainter {
  /// 0..1, as [SportBallScene.entrance].
  final double entrance;

  /// 0..1 position in the idle loop. 0 is the rest position, so a scene that
  /// starts drifting picks up from exactly where it stopped arriving.
  final double drift;

  /// As [SportBallScene.bleed].
  final double bleed;

  /// As [SportBallScene.layout].
  final SportBallLayout layout;

  const SportBallScenePainter({
    required this.entrance,
    this.drift = 0,
    this.bleed = 0,
    this.layout = SportBallLayout.overHeadline,
  });

  // ── Motion ────────────────────────────────────
  //
  // Each ball's slice of [entrance]. They start about 120ms apart over the
  // splash's 1150ms window, so the eye can follow one at a time.

  static const _kBasketball = (begin: 0.0, end: 0.90);
  static const _kVolleyball = (begin: 0.10, end: 0.95);
  static const _kShuttle = (begin: 0.20, end: 1.0);

  /// The liveliest ball, so it bounces highest and longest.
  static const _kBasketballBounce = BounceCurve(restitution: 0.5, bounces: 3);

  /// A volleyball is softer: it comes back lower and settles sooner.
  static const _kVolleyballBounce = BounceCurve(restitution: 0.42, bounces: 2);

  /// Where in [entrance] the basketball first hits the ground.
  ///
  /// The splash lands its wordmark on this beat, and reads it from here so
  /// that retuning the bounce moves the wordmark with it.
  static double get basketballLanding =>
      _kBasketball.begin +
      (_kBasketball.end - _kBasketball.begin) * _kBasketballBounce.landing;

  /// A strong ease-out for things arriving: fast off the mark, long settle.
  static const _kArrive = Cubic(0.23, 1, 0.32, 1);

  /// Settles slightly past its mark and back, for the shuttlecock's tilt.
  static const _kOvershoot = Cubic(0.34, 1.36, 0.64, 1);

  /// How far above the top of the scene a ball starts, clear of the edge.
  static const _kOffscreen = 8.0;

  /// How much a ball flattens on its hardest touchdown. Small on purpose:
  /// these are lit, solid-looking balls, and a cartoon squash would fight that.
  static const _kSquash = 0.08;

  /// How far each ball drifts while idle, in logical pixels.
  static const _kDriftPx = 4.0;

  /// Where each ball sits on its idle loop, so they never move in step.
  static const _kDriftPhase = (basketball: 0.0, volleyball: 2.1, shuttle: 4.2);

  /// Rest angles. The basketball's seams are tilted off the vertical so it
  /// does not read as a diagram. The volleyball's are turned so its left
  /// half, the half left on screen, shows panels running across the top and
  /// down the side. The shuttlecock's depend on the layout — see [_rest].
  static const _kBasketballRest = -0.35;
  static const _kVolleyballRest = 0.26;

  /// Where each ball comes to rest in [layout], as fractions of the scene's
  /// bled width and of its height, and the angles the shuttlecock swings
  /// between as it settles.
  ///
  /// Over the headline the shuttlecock lands well tilted, at the bottom of a
  /// loose diagonal from the basketball. Around the centred wordmark it leans
  /// only a little, so it still points down at the wordmark below it, and
  /// swings in from leaning the other way.
  ({
    Offset basketball,
    Offset volleyball,
    Offset shuttle,
    double shuttleFrom,
    double shuttleTo,
  }) get _rest => switch (layout) {
        SportBallLayout.overHeadline => (
            basketball: const Offset(0.22, 0.30),
            volleyball: const Offset(0.86, 0.56),
            shuttle: const Offset(0.40, 0.76),
            shuttleFrom: 0.15,
            shuttleTo: 0.6,
          ),
        SportBallLayout.aroundCentre => (
            basketball: const Offset(0.16, 0.36),
            volleyball: const Offset(0.86, 0.46),
            shuttle: const Offset(0.50, 0.70),
            shuttleFrom: -0.25,
            shuttleTo: 0.25,
          ),
      };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final left = -bleed;
    final width = size.width + bleed * 2;
    final height = size.height;
    final rest = _rest;
    Offset at(Offset f) => Offset(left + width * f.dx, height * f.dy);

    // One unit for every ball's size. Width alone would grow them into each
    // other on a short screen; height alone would make them tiny on a narrow
    // one. Capped so a tablet does not get beach balls.
    final unit = math.min(math.min(width, height * 0.95), 480.0);

    // Farthest first, so the basketball overlaps the volleyball and not the
    // other way round if a very short screen ever pushes them together.
    _volleyball(canvas, at(rest.volleyball), unit);
    _basketball(canvas, at(rest.basketball), unit);
    _shuttlecock(canvas, at(rest.shuttle), unit, rest.shuttleFrom,
        rest.shuttleTo);
  }

  void _basketball(Canvas canvas, Offset rest, double unit) {
    final p = _slice(_kBasketball);
    if (p == 0) return;
    final r = unit * 0.29;

    // Dropped from just above the top of the screen: falls, lands, and
    // bounces to a stop. Never below its resting point, so it never comes
    // down towards the wordmark.
    final drop = rest.dy + r + _kOffscreen;
    final fall = (1 - _kBasketballBounce.transform(p)) * drop;
    final c = rest.translate(0, -fall + _sway(_kDriftPhase.basketball));
    final spin = _kBasketballRest - 0.6 * (1 - _kArrive.transform(p));

    _squashed(canvas, c, r, _kBasketballBounce.impact(p),
        () => paintBasketball(canvas, c, r, spin));
  }

  void _volleyball(Canvas canvas, Offset rest, double unit) {
    final p = _slice(_kVolleyball);
    if (p == 0) return;
    final r = unit * 0.25;

    // Dropped the same way, its panels turning a little as it falls.
    final drop = rest.dy + r + _kOffscreen;
    final fall = (1 - _kVolleyballBounce.transform(p)) * drop;
    final c = rest.translate(0, -fall + _sway(_kDriftPhase.volleyball));
    final spin = _kVolleyballRest + 0.5 * (1 - _kArrive.transform(p));

    _squashed(canvas, c, r, _kVolleyballBounce.impact(p),
        () => paintVolleyball(canvas, c, r, spin));
  }

  void _shuttlecock(Canvas canvas, Offset rest, double unit, double tiltFrom,
      double tiltTo) {
    final p = _slice(_kShuttle);
    if (p == 0) return;
    final length = unit * 0.34;

    // Floats down cork first, the way a shuttlecock actually falls. It does
    // not bounce: its feathers drag it to a gentle stop instead, and its tilt
    // swings slightly past its mark and back.
    final drop = rest.dy + length / 2 + _kOffscreen;
    final fall = (1 - _kArrive.transform(p)) * drop;
    final c = rest.translate(0, -fall + _sway(_kDriftPhase.shuttle));
    final tilt = tiltFrom + (tiltTo - tiltFrom) * _kOvershoot.transform(p);

    paintShuttlecock(canvas, c, length, tilt);
  }

  /// This ball's progress through its own slice of [entrance].
  double _slice(({double begin, double end}) s) =>
      ((entrance - s.begin) / (s.end - s.begin)).clamp(0.0, 1.0);

  /// Vertical idle offset. Zero at the start of the loop whatever the phase,
  /// so the drift starting never makes a ball jump.
  double _sway(double phase) =>
      (math.sin(drift * 2 * math.pi + phase) - math.sin(phase)) * _kDriftPx;

  /// Paints a ball of radius [r] at [c] flattened by [impact] (0..1) against
  /// the ground it is hitting.
  ///
  /// Pinned at its lowest point, so the squash never pushes it past where it
  /// touched down, and widened by half what it loses in height so it keeps
  /// roughly its volume, as a real ball does.
  void _squashed(Canvas canvas, Offset c, double r, double impact,
      VoidCallback paintBall) {
    if (impact == 0) {
      paintBall();
      return;
    }
    final q = _kSquash * impact;
    final ground = c.dy + r;
    canvas.save();
    canvas.translate(c.dx, ground);
    canvas.scale(1 + q / 2, 1 - q);
    canvas.translate(-c.dx, -ground);
    paintBall();
    canvas.restore();
  }

  @override
  bool shouldRepaint(SportBallScenePainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.drift != drift ||
      oldDelegate.bleed != bleed ||
      oldDelegate.layout != layout;
}

/// Falls under gravity, then bounces on the spot where it lands — what a real
/// ball dropped onto a floor does.
///
/// Each rebound leaves the ground at [restitution] times the speed the ball
/// hit it, so each hop climbs [restitution]² as high as the one before and
/// lasts [restitution] times as long. With 0.5 and three bounces that is
/// exactly [Curves.bounceOut]; the parameters let each ball bounce like itself.
///
/// Accelerating into each landing is deliberate here even though ease-in is
/// wrong for interface motion: this is a ball falling, and a ball that slows
/// down as it nears the ground reads as being lowered on a string.
class BounceCurve extends Curve {
  /// The fraction of its speed the ball keeps through each bounce.
  final double restitution;

  /// How many times it leaves the ground again before it settles.
  final int bounces;

  const BounceCurve({this.restitution = 0.5, this.bounces = 3})
      : assert(restitution > 0 && restitution < 1),
        assert(bounces >= 0);

  /// How long a touchdown is felt either side of the moment of contact, in
  /// lengths of the first fall: a frame or two at the speeds used here.
  static const _kContact = 0.06;

  /// The whole motion, in lengths of the first fall.
  double get _span {
    var span = 1.0;
    var e = 1.0;
    for (var k = 0; k < bounces; k++) {
      e *= restitution;
      span += 2 * e;
    }
    return span;
  }

  /// Where in 0..1 the ball first touches down.
  double get landing => 1 / _span;

  /// How hard the ball is meeting the ground at [t], for squash: 1 on the
  /// first touchdown, [restitution] on the next and so on, fading to nothing
  /// a moment either side of each.
  ///
  /// The final settle is not counted. It is the gentlest contact anyway, and
  /// it is where the ball stays — a ball at rest is round.
  double impact(double t) {
    final x = t * _span;
    var touchdown = 1.0;
    var e = 1.0;
    for (var k = 0; k < bounces; k++) {
      final near = 1 - (x - touchdown).abs() / _kContact;
      if (near > 0) return e * near;
      e *= restitution;
      touchdown += 2 * e;
    }
    return 0;
  }

  @override
  double transformInternal(double t) {
    var x = t * _span;
    if (x < 1) return x * x;
    x -= 1;
    var e = 1.0;
    for (var k = 0; k < bounces; k++) {
      e *= restitution;
      final hop = 2 * e;
      if (x < hop) {
        final s = x / hop;
        return 1 - e * e * 4 * s * (1 - s);
      }
      x -= hop;
    }
    return 1;
  }
}

// ── The balls ─────────────────────────────────────
//
// Each is painted in the same four passes: a base lit from the top right, the
// seams (the only part that turns), a shadow laid over the seams so they sink
// into the dark side instead of staying crisp across it, and a thin gold rim
// on the lit edge — the stadium light, and the one place the brand colour
// touches the scene.

const _kInk = Color(0xFF07070C);

/// Where the light hits, as a point on each ball's own box.
const _kLight = Alignment(0.45, -0.5);

Paint _seamPaint(double r) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = math.max(1.0, r * 0.024)
  ..strokeCap = StrokeCap.round
  ..color = const Color(0xE60B0B0F);

void _base(Canvas canvas, Offset c, double r, List<Color> colors) {
  final rect = Rect.fromCircle(center: c, radius: r);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: _kLight,
        radius: 0.85,
        colors: colors,
        stops: const [0.0, 0.3, 0.68, 1.0],
      ).createShader(rect),
  );
}

void _shade(Canvas canvas, Path silhouette, Rect bounds) {
  canvas.drawPath(
    silhouette,
    Paint()
      ..shader = LinearGradient(
        begin: const Alignment(0.75, -0.75),
        end: const Alignment(-0.85, 0.85),
        colors: [
          _kInk.withValues(alpha: 0),
          _kInk.withValues(alpha: 0.18),
          _kInk.withValues(alpha: 0.94),
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(bounds),
  );
}

void _rim(Canvas canvas, Offset c, double r) {
  final stroke = math.max(1.0, r * 0.035);
  final rect = Rect.fromCircle(center: c, radius: r - stroke / 2);
  // Centred on the top-right, where the light is.
  const sweep = math.pi * 0.74;
  const start = -math.pi / 4 - sweep / 2;
  canvas.drawArc(
    rect,
    start,
    sweep,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        endAngle: sweep,
        colors: [
          AppTheme.accent.withValues(alpha: 0),
          AppTheme.accent.withValues(alpha: 0.6),
          AppTheme.accent.withValues(alpha: 0),
        ],
        transform: const GradientRotation(start),
      ).createShader(rect),
  );
}

/// A basketball of radius [r] centred on [c], its seams turned by [spin].
void paintBasketball(Canvas canvas, Offset c, double r, double spin) {
  _base(canvas, c, r, const [
    Color(0xFFF7A35A),
    Color(0xFFE8731E),
    Color(0xFF8A3A0A),
    _kInk,
  ]);

  final ball = Rect.fromCircle(center: c, radius: r);
  final outline = Path()..addOval(ball);
  final seam = _seamPaint(r);

  canvas.save();
  canvas.clipPath(outline);
  canvas.translate(c.dx, c.dy);
  canvas.rotate(spin);
  canvas.drawLine(Offset(0, -r), Offset(0, r), seam);
  canvas.drawLine(Offset(-r, 0), Offset(r, 0), seam);
  // The two side seams bow in towards the middle, like brackets facing out.
  for (final side in const [-1.0, 1.0]) {
    canvas.drawPath(
      Path()
        ..moveTo(side * r * 0.66, -r * 0.82)
        ..quadraticBezierTo(side * r * 0.18, 0, side * r * 0.66, r * 0.82),
      seam,
    );
  }
  canvas.restore();

  _shade(canvas, outline, ball);
  _rim(canvas, c, r);
}

/// A volleyball of radius [r] centred on [c], its panels turned by [spin].
///
/// Three seams curl out from the middle like a pinwheel, and each third of the
/// ball between two of them is split into three strips — the silhouette
/// people recognise from the ball itself, without drawing all eighteen panels.
void paintVolleyball(Canvas canvas, Offset c, double r, double spin) {
  _base(canvas, c, r, const [
    Color(0xFFFFFFFF),
    Color(0xFFE4E4EA),
    Color(0xFF8C8C94),
    _kInk,
  ]);

  final ball = Rect.fromCircle(center: c, radius: r);
  final outline = Path()..addOval(ball);
  final seam = _seamPaint(r);

  // Each seam is an arc of a circle the ball's own size, centred on its rim,
  // so it starts at the middle and curls out to the rim; three of them a
  // third of a turn apart make the pinwheel. The middle, that centre and the
  // point where the seam meets the rim are all one radius apart, so the seam
  // runs a sixth of the way round its circle and lands on the rim a sixth of
  // a turn on from its centre.
  const third = 2 * math.pi / 3;
  const curl = math.pi / 3;
  Offset hub(double turn) => Offset(math.cos(turn), math.sin(turn)) * r;

  canvas.save();
  canvas.clipPath(outline);
  canvas.translate(c.dx, c.dy);
  canvas.rotate(spin);
  for (var k = 0; k < 3; k++) {
    final a = k * third;
    final seamCircle = Rect.fromCircle(center: hub(a), radius: r);
    final nextCircle = Rect.fromCircle(center: hub(a + third), radius: r);

    // Anticlockwise from the middle, the way the panels turn on the ball.
    canvas.drawArc(seamCircle, math.pi + a, -curl, false, seam);

    // The third of the ball this seam bulges into: out along it, clockwise
    // round the rim to the next seam, and back in along that one.
    final sector = Path()
      ..moveTo(0, 0)
      ..arcTo(seamCircle, math.pi + a, -curl, false)
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: r * 1.02),
          a + curl, third, false)
      ..arcTo(nextCircle, math.pi + a + third - curl, curl, false)
      ..close();

    canvas.save();
    canvas.clipPath(sector);
    // Two lines follow the bulge of this seam and split the sector into
    // three strips, each running from the rim until it meets the next seam,
    // which is how a volleyball's panels actually run. They are circles
    // around the seam's own centre, so they keep their distance from it the
    // whole way; on this, its outer side, they are wider than the seam and
    // flatter. On the inner side the same circles curve tighter than the
    // seam and read as a target. Each is drawn whole and left to the sector
    // clip, which it crosses only once, to trim it.
    for (final spread in const [1.38, 1.74]) {
      canvas.drawCircle(hub(a), r * spread, seam);
    }
    canvas.restore();
  }
  canvas.restore();

  _shade(canvas, outline, ball);
  _rim(canvas, c, r);
}

/// A shuttlecock [length] long centred on [c], cork pointing down and turned
/// clockwise by [tilt].
///
/// The light stays fixed while it turns: the geometry is built upright and
/// then rotated as a path, so the gradients are laid on in screen space.
void paintShuttlecock(Canvas canvas, Offset c, double length, double tilt) {
  final w = length * 0.62; // across the open end of the skirt
  final corkR = length * 0.17;
  final top = -length / 2;
  final corkC = length / 2 - corkR;
  final bandTop = corkC - corkR * 0.35;
  final skirtBase = corkR * 0.9; // half-width where the skirt meets the cork

  final turn = Matrix4.translationValues(c.dx, c.dy, 0)..rotateZ(tilt);
  Path placed(Path p) => p.transform(turn.storage);

  // Skirt: a cone of feathers flaring from the cork to a scalloped rim.
  const feathers = 8;
  final skirt = Path()..moveTo(-skirtBase, bandTop);
  skirt.lineTo(-w / 2, top + length * 0.04);
  for (var i = 0; i < feathers; i++) {
    final x0 = -w / 2 + w * i / feathers;
    final x1 = -w / 2 + w * (i + 1) / feathers;
    skirt.quadraticBezierTo((x0 + x1) / 2, top - length * 0.04, x1,
        top + length * 0.04);
  }
  skirt
    ..lineTo(skirtBase, bandTop)
    ..close();

  final cork = Path()
    ..addArc(Rect.fromCircle(center: Offset(0, corkC), radius: corkR), 0,
        math.pi)
    ..lineTo(-corkR, bandTop)
    ..lineTo(corkR, bandTop)
    ..close();

  final skirtPlaced = placed(skirt);
  final corkPlaced = placed(cork);
  final bounds = skirtPlaced.getBounds().expandToInclude(corkPlaced.getBounds());

  canvas.drawPath(
    skirtPlaced,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment(0.8, -0.8),
        end: Alignment(-0.8, 0.8),
        colors: [Color(0xFFFFFFFF), Color(0xFFD9D9E0), Color(0xFF6E6E78)],
      ).createShader(bounds),
  );
  // The cork is lit on its own box rather than the whole shuttlecock's: it
  // sits at the shadowed end, and on the shared gradient it went black and
  // took the shuttlecock's most recognisable part with it.
  canvas.drawPath(
    corkPlaced,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment(0.8, -0.8),
        end: Alignment(-0.8, 0.8),
        colors: [Color(0xFFFFFDF8), Color(0xFFE2DCCF), Color(0xFF8E8778)],
      ).createShader(corkPlaced.getBounds()),
  );

  // The band where the feathers meet the cork, in the brand gold.
  final band = placed(Path()
    ..addRect(
        Rect.fromLTRB(-corkR, bandTop, corkR, bandTop + corkR * 0.34)));
  canvas.drawPath(
    band,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment(0.8, -0.8),
        end: Alignment(-0.8, 0.8),
        colors: [AppTheme.accentLight, AppTheme.accent, AppTheme.accent2],
      ).createShader(band.getBounds()),
  );

  // Feather shafts from the cork to each scallop, and the two rings of
  // thread that hold them — the detail that makes it a shuttlecock and not
  // a cone.
  final seam = _seamPaint(length * 0.5)
    ..strokeWidth = math.max(1.0, length * 0.012);
  final shafts = Path();
  for (var i = 0; i <= feathers; i++) {
    final x = -w / 2 + w * i / feathers;
    shafts
      ..moveTo(-skirtBase + 2 * skirtBase * i / feathers, bandTop)
      ..lineTo(x, top + length * 0.04);
  }
  for (final at in const [0.38, 0.62]) {
    final y = bandTop + (top - bandTop) * at;
    final half = skirtBase + (w / 2 - skirtBase) * at;
    shafts
      ..moveTo(-half, y)
      ..lineTo(half, y);
  }
  canvas.drawPath(placed(shafts), seam);

  // Only the feathers take the shared shadow, for the same reason the cork
  // is lit on its own.
  _shade(canvas, skirtPlaced, bounds);
}
