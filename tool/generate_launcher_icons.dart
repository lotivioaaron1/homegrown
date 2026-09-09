// tool/generate_launcher_icons.dart
//
// Draws the Homegrown launcher-icon candidates as vector geometry and
// rasterises them to PNG.
//
// Run it with an explicit path so it is NOT picked up by the default
// `test/**/*_test.dart` glob during a normal `flutter test`:
//
//   # contact sheet of every candidate, into the scratchpad
//   flutter test tool/generate_launcher_icons.dart
//
//   # once a candidate is chosen, also write the real masters
//   flutter test tool/generate_launcher_icons.dart \
//     --dart-define=concept=m2 --dart-define=colorway=goldPlate
//
// concept is one of m1/m2/m3/m4 (the motion treatments); colorway is
// inkPlate or goldPlate.
//
// It runs under flutter_test purely because `Picture.toImage` needs a live
// engine; there is no Python or ImageMagick on this machine, so the Flutter
// toolchain is the only rasteriser available. Nothing in lib/ imports this.
//
// ---------------------------------------------------------------------------
// Why the marks are sized the way they are
// ---------------------------------------------------------------------------
// flutter_launcher_icons drops the source PNG into the 108dp adaptive layer,
// and the generated mipmap-anydpi-v26/ic_launcher.xml then insets it by 16%,
// so the artwork lives across 73.4dp. The launcher's safe circle is 66dp.
//
// The mask is a circle, so `sourceFraction` is the diameter of the mark's
// MINIMUM ENCLOSING CIRCLE as a fraction of the canvas — not a bounding-box
// width. The hard ceiling is 66/73.44 = 0.899; we draw at 0.82, leaving about
// 9% radial margin so the mark does not appear to graze the mask.
//
// Measuring radially rather than by bounding box matters for a shape like the
// house, whose extreme points are its two bottom corners. Fitting its box
// centred the shape geometrically but not optically: the base crowded the mask
// while the roof peak left room unused. The enclosing-circle fit re-centres it
// and, because the shape's optimal centre sits above its box centre, allows a
// noticeably larger mark at the same safe-circle limit.
//
// The icon being replaced was configured at 50%, i.e. 36.7dp inside a 66dp
// circle — about 31% of the visible area. That is why it read as a small mark
// stranded in a white plate.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// --- Brand colours (mirrored from lib/theme/app_theme.dart) -----------------

const Color kGold = Color(0xFFFFB800);
const Color kInk = Color(0xFF07070C); // matches the splash background

/// Neutral ground for the contact sheet: mid grey reads fairly against both a
/// gold plate and an ink plate, so neither colourway gets flattered.
const Color kSheetBg = Color(0xFF7A7A82);

// --- Chosen candidate, supplied on the command line -------------------------

const String kConcept = String.fromEnvironment('concept');
const String kColorway = String.fromEnvironment('colorway');

const String kScratch =
    r'C:\Users\ADMIN\AppData\Local\Temp\claude\c--flutter-homegrown\bc25afb5-509b-493a-95b0-a3f2de2d7101\scratchpad\icons';

// ---------------------------------------------------------------------------
// Concepts
// ---------------------------------------------------------------------------

/// A candidate mark, described as a path inside the unit square (0,0)-(1,1).
///
/// Every concept must be a single filled path with no stroked lines: a stroke
/// thin enough to look right at 1024px is sub-pixel at 48dp, which is exactly
/// how the outgoing icon's speed lines turned into grey mush.
abstract class Concept {
  String get id;

  /// Fraction of the 1024px master the mark should span. See the header.
  double get sourceFraction;

  /// Corner softening, as a fraction of the mark's span. Applied by stroking
  /// the silhouette with a round join on top of the fill, which rounds the
  /// outer corners and the corners of any knocked-out counter in one pass —
  /// `dart:ui` has no path-offset operation to do it geometrically.
  double get roundness => 0.0;

  Path unitPath();

  /// The mark split into two independently coloured pieces, or null when the
  /// concept is a single silhouette. Used only for the two-tone colourway;
  /// `unitPath()` stays the authority for sizing and for the monochrome layer,
  /// where Android flattens everything to one tint anyway.
  (Path primary, Path secondary)? unitParts() => null;
}

/// A — "Home-court H": two heavy uprights with a ball wedged between them as
/// the crossbar. The ball overlaps both posts, so the silhouette is one
/// connected piece and survives being flattened to a single tint by Android's
/// themed icons.
class ConceptA extends Concept {
  @override
  String get id => 'a';

  @override
  double get sourceFraction => 0.82;

  @override
  Path unitPath() {
    const postW = 0.21;
    const r = Radius.circular(0.045);

    final posts = Path()
      ..addRRect(RRect.fromLTRBR(0, 0, postW, 1, r))
      ..addRRect(RRect.fromLTRBR(1 - postW, 0, 1, 1, r));

    // A real crossbar, not just the ball. Without it the mark read as a
    // bracket — "|o|" — because the two open counters above and below a bare
    // circle are what the eye latches onto. The bar establishes the H first;
    // the ball then reads as a bulge in it rather than a floating dot.
    final crossbar = Path()
      ..addRect(const Rect.fromLTRB(0.15, 0.42, 0.85, 0.58));

    final ball = Path()
      ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.5), radius: 0.23));

    var mark = Path.combine(PathOperation.union, posts, crossbar);
    return Path.combine(PathOperation.union, mark, ball);
  }
}

/// B — "House with H cut out": a solid house pentagon with the letter H
/// removed as negative space. Keeps the "home" idea of the house-and-trophy
/// sketch, but as one shape with no outline stroke and no baked glow.
class ConceptB extends Concept {
  ConceptB({required this.id, this.roundness = 0.0});

  @override
  final String id;

  @override
  final double roundness;

  @override
  double get sourceFraction => 0.82;

  @override
  Path unitPath() {
    final house = Path()
      ..moveTo(0.5, 0.0)
      ..lineTo(1.0, 0.40)
      ..lineTo(1.0, 1.0)
      ..lineTo(0.0, 1.0)
      ..lineTo(0.0, 0.40)
      ..close();

    // The H is the hole. Its uprights stop short of the wall bottom (0.92 vs
    // 1.0) and start below the eaves (0.50 vs 0.40) so the gold around it stays
    // one connected region — an H knocked clean through would shed islands.
    const x0 = 0.24, x1 = 0.76;
    const yTop = 0.51, yBot = 0.93;
    const sw = 0.155; // upright thickness
    const cbTop = 0.66, cbBot = 0.78; // crossbar

    final h = Path()
      ..addRect(const Rect.fromLTRB(x0, yTop, x0 + sw, yBot))
      ..addRect(const Rect.fromLTRB(x1 - sw, yTop, x1, yBot))
      ..addRect(const Rect.fromLTRB(x0, cbTop, x1, cbBot));

    return Path.combine(PathOperation.difference, house, h);
  }
}

/// C — "Sprout ball": a solid ball with a sprout breaking out of the top, for
/// the "grown" half of the name. A disc is the ideal shape for a round
/// launcher mask, so this one is allowed to run larger than A and B.
class ConceptC extends Concept {
  @override
  String get id => 'c';

  @override
  double get sourceFraction => 0.82;

  static const _center = Offset(0.5, 0.66);
  static const _radius = 0.34;

  @override
  Path unitPath() {
    var mark = Path()
      ..addOval(Rect.fromCircle(center: _center, radius: _radius));

    // Stem runs down into the ball so the union is connected.
    mark = Path.combine(
      PathOperation.union,
      mark,
      Path()
        ..addRRect(RRect.fromLTRBR(
            0.465, 0.10, 0.535, 0.42, const Radius.circular(0.035))),
    );

    mark = Path.combine(PathOperation.union, mark, _leaf(mirrored: false));
    mark = Path.combine(PathOperation.union, mark, _leaf(mirrored: true));

    // Two seams, knocked out as constant-width crescents (the band between two
    // concentric circles). Flutter cannot convert a stroke to a fillable path,
    // and a crescent gives a real filled shape we can subtract.
    for (final band in _seams()) {
      mark = Path.combine(PathOperation.difference, mark, band);
    }

    return mark;
  }

  Path _leaf({required bool mirrored}) {
    double x(double v) => mirrored ? 1.0 - v : v;
    final p = Path()
      ..moveTo(x(0.50), 0.30)
      ..quadraticBezierTo(x(0.28), 0.34, x(0.16), 0.14)
      ..quadraticBezierTo(x(0.36), 0.16, x(0.50), 0.21)
      ..close();
    return p;
  }

  List<Path> _seams() {
    const bandWidth = 0.07;

    // The seams must run pole to pole or the disc reads as fruit rather than a
    // ball. An arc through both poles (0.5, 0.32) and (0.5, 1.0) that bulges
    // out to x = 0.60 has a chord of 0.68 and a sagitta of 0.10, so its radius
    // is (0.34^2)/(2*0.10) + 0.10/2 = 0.628, centred level with the ball.
    const arcRadius = 0.628;
    const centres = [0.5 - 0.528, 0.5 + 0.528];

    return [
      for (final dx in centres)
        Path.combine(
          PathOperation.difference,
          Path()
            ..addOval(Rect.fromCircle(
                center: Offset(dx, _center.dy),
                radius: arcRadius + bandWidth / 2)),
          Path()
            ..addOval(Rect.fromCircle(
                center: Offset(dx, _center.dy),
                radius: arcRadius - bandWidth / 2)),
        ),
    ];
  }
}

/// How the "speed" cue is expressed. The original artwork stacked six hairline
/// trails, which is precisely what died at 48dp; every option here is drawn
/// thick enough to survive, and they differ in where the motion lives.
enum Motion {
  /// Three tapered wedges instead of six hairlines. Closest to the original.
  trails,

  /// No external trails — diagonal gaps knocked through the letters, as though
  /// speed had sliced them. Keeps the mark compact so the letters stay large.
  cuts,

  /// One thick arc sweeping under the lockup, doubling as a baseline.
  swoosh,

  /// No motion marks at all: a harder italic carries the speed by itself.
  shear,
}

/// The "HG" monogram. The brand's own letters are the only thing that is
/// uniquely Homegrown's, which is why this replaced the pictorial marks.
///
/// The letters are constructed geometrically rather than set in a typeface:
/// nothing is bundled (google_fonts fetches at runtime), and building the forms
/// by hand is what lets the motion treatment be a parameter instead of a redraw.
class ConceptHG extends Concept {
  ConceptHG({required this.id, required this.motion, this.shearDeg = 12.0});

  @override
  final String id;

  final Motion motion;

  /// Italic slant. Motion.shear leans harder because the slant is doing all the
  /// work on its own.
  final double shearDeg;

  @override
  double get sourceFraction => 0.82;

  /// Weight of both letters, as a fraction of a letter's own box.
  static const _weight = 0.30;

  /// Each letter's size within the lockup.
  static const _letter = 0.56;

  /// Where the G sits relative to the H. Tuned so the H's right leg only
  /// notches the G's upper-left shoulder: placed symmetrically on the diagonal
  /// the leg swallowed the G's whole top arc and it read as a hook, not a G.
  static const _gOffset = Offset(0.47, 0.44);

  /// Gap knocked out of the G where the H crosses it.
  static const _gap = 0.05;

  static Path _hForm() => Path()
    ..addRect(const Rect.fromLTRB(0, 0, _weight, 1))
    ..addRect(const Rect.fromLTRB(1 - _weight, 0, 1, 1))
    ..addRect(const Rect.fromLTRB(0, 0.40, 1, 0.60));

  static Path _gForm() {
    final ring = Path.combine(
      PathOperation.difference,
      Path()..addOval(const Rect.fromLTRB(0, 0, 1, 1)),
      Path()..addOval(
          const Rect.fromLTRB(_weight, _weight, 1 - _weight, 1 - _weight)),
    );

    // Open the upper right, or the ring is an O.
    final opened = Path.combine(
      PathOperation.difference,
      ring,
      Path()..addRect(const Rect.fromLTRB(0.52, -0.05, 1.05, 0.44)),
    );

    // The spur — the stroke that makes a G a G. It stops at 0.52 rather than
    // reaching deep into the counter: at 0.42 it closed the counter almost
    // completely and the G rendered as a blob with a notch.
    return Path.combine(
      PathOperation.union,
      opened,
      Path()..addRect(const Rect.fromLTRB(0.52, 0.44, 1.0, 0.60)),
    );
  }

  static Path _place(Path p, double dx, double dy, double s) {
    final m = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
    return p.transform(m.storage);
  }

  /// H upper-left, G lower-right. The diagonal arrangement is far closer to
  /// square than the old side-by-side lockup, whose 1.617:1 box is what forced
  /// the letters small once inscribed in a circular mask.
  (Path, Path) _letters() {
    final h = _place(_hForm(), 0, 0, _letter);
    var g = _place(_gForm(), _gOffset.dx, _gOffset.dy, _letter);

    // The gap is cut out of the G, not the H. The original artwork stacks the
    // H over the G, so the H must stay whole and the G takes the notch —
    // cutting it the other way round ate the H's right leg. The gap itself is
    // what keeps "HG" readable once a themed icon flattens both to one tint.
    final grownH = _place(_hForm(), -_gap, -_gap, _letter + 2 * _gap);
    g = Path.combine(PathOperation.difference, g, grownH);

    return (h, g);
  }

  /// Tapered wedge, thick where it meets the letter and pointed at the tail.
  static Path _wedge(double y, double t, double x0, double x1) => Path()
    ..moveTo(x0, y)
    ..lineTo(x1, y - t / 2)
    ..lineTo(x1, y + t / 2)
    ..close();

  static Path _trails() => Path()
    ..addPath(_wedge(0.09, 0.085, -0.40, 0.12), Offset.zero)
    ..addPath(_wedge(0.26, 0.085, -0.34, 0.12), Offset.zero)
    ..addPath(_wedge(0.43, 0.085, -0.28, 0.12), Offset.zero);

  /// Narrow diagonal slits, cut through the H only.
  ///
  /// A first pass ran wide bands through both letters and simply destroyed
  /// them — the H fell into floating fragments. Keeping the slits thin and
  /// confined to the H reads as streaking rather than damage, and leaves the G
  /// whole to anchor the mark.
  /// Two slits, not three: at three the H read as a zebra and fell apart into
  /// stripes by 48dp. Wider each, so they survive the downscale.
  static List<Path> _slashes() => [
        for (final y in [0.17, 0.37])
          Path()
            ..moveTo(-0.30, y)
            ..lineTo(1.30, y - 0.52)
            ..lineTo(1.30, y - 0.52 + 0.07)
            ..lineTo(-0.30, y + 0.07)
            ..close(),
      ];

  /// A constant-width arc under the lockup: the band between two concentric
  /// circles, clipped to the sweep that actually passes beneath the letters.
  static Path _swoosh() {
    // Thick on purpose: at t = 0.10 this was a hairline that vanished by 48dp,
    // the exact failure that killed the original speed lines.
    //
    // The two circles are deliberately NOT concentric. A constant-width arc
    // read as a bowl under the letters; offsetting the inner centre makes the
    // band wide at the left and narrow at the right, so it tapers like a
    // stroke of speed instead.
    final band = Path.combine(
      PathOperation.difference,
      Path()
        ..addOval(Rect.fromCircle(
            center: const Offset(0.5, -0.30), radius: 1.47)),
      Path()
        ..addOval(Rect.fromCircle(
            center: const Offset(0.62, -0.26), radius: 1.35)),
    );
    return Path.combine(PathOperation.intersect, band,
        Path()..addRect(const Rect.fromLTRB(-0.30, 0.80, 1.35, 1.40)));
  }

  Matrix4 _shear() {
    final k = math.tan(shearDeg * math.pi / 180);
    // x' = x + k * (0.5 - y): the top leans right, pivoting about mid-height.
    return Matrix4.identity()
      ..translateByDouble(k * 0.5, 0, 0, 1)
      ..setEntry(0, 1, -k);
  }

  (Path, Path) _built() {
    var (h, g) = _letters();

    switch (motion) {
      case Motion.trails:
        h = Path.combine(PathOperation.union, h, _trails());
      case Motion.cuts:
        // The H only — see _slashes().
        for (final s in _slashes()) {
          h = Path.combine(PathOperation.difference, h, s);
        }
      case Motion.swoosh:
        g = Path.combine(PathOperation.union, g, _swoosh());
      case Motion.shear:
        break;
    }

    final m = _shear();
    return (h.transform(m.storage), g.transform(m.storage));
  }

  @override
  Path unitPath() {
    final (h, g) = _built();
    return Path.combine(PathOperation.union, h, g);
  }

  @override
  (Path, Path)? unitParts() => _built();
}

/// The two colourways under consideration. Rendered side by side rather than
/// argued about: the ink plate keeps the brand's two-tone character, the gold
/// plate is bolder at 48dp and matches the plate chosen for the house mark.
enum Colourway { inkPlate, goldPlate }

(Color plate, Color primary, Color secondary) _palette(Colourway w) =>
    switch (w) {
      Colourway.inkPlate => (kInk, const Color(0xFFF2F2F5), kGold),
      Colourway.goldPlate => (kGold, kInk, kInk),
    };

final concepts = <Concept>[
  ConceptHG(id: 'm1', motion: Motion.trails),
  ConceptHG(id: 'm2', motion: Motion.cuts),
  ConceptHG(id: 'm3', motion: Motion.swoosh),
  ConceptHG(id: 'm4', motion: Motion.shear, shearDeg: 18),
];

/// The pictorial marks this replaced. Kept so the earlier round can be
/// regenerated without rewriting it, but no longer rendered.
final retiredConcepts = <Concept>[
  ConceptA(),
  ConceptB(id: 'b'),
  ConceptB(id: 'b2', roundness: 0.055),
  ConceptC(),
];

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Samples points along every contour of [p], for the enclosing-circle fit.
List<Offset> _samplePath(Path p) {
  final pts = <Offset>[];
  for (final metric in p.computeMetrics()) {
    final n = math.max(24, (metric.length * 200).round());
    for (var i = 0; i <= n; i++) {
      final t = metric.getTangentForOffset(metric.length * i / n);
      if (t != null) pts.add(t.position);
    }
  }
  return pts;
}

/// Smallest circle enclosing [pts], found by repeatedly stepping the centre
/// toward whichever point is currently farthest with a shrinking step.
(Offset centre, double radius) _enclosingCircle(List<Offset> pts) {
  var c = pts.first;
  for (final p in pts) {
    c = Offset(c.dx + p.dx, c.dy + p.dy);
  }
  c = Offset(c.dx / (pts.length + 1), c.dy / (pts.length + 1));

  var f = 0.1;
  for (var i = 0; i < 6000; i++) {
    var far = pts.first;
    var best = -1.0;
    for (final p in pts) {
      final d = (p - c).distanceSquared;
      if (d > best) {
        best = d;
        far = p;
      }
    }
    c = Offset(c.dx + (far.dx - c.dx) * f, c.dy + (far.dy - c.dy) * f);
    f *= 0.9988;
  }

  var r = 0.0;
  for (final p in pts) {
    r = math.max(r, (p - c).distance);
  }
  return (c, r);
}

/// Scales a concept's unit path so its ENCLOSING CIRCLE spans [fraction] of a
/// [side]-px canvas, and centres that circle on the canvas.
///
/// Fitting the bounding box instead would centre the house geometrically while
/// its mass sits low: the wide base crowded the launcher's circular mask while
/// the roof peak wasted the room above it. The mask is a circle, so the fit
/// that matters is radial — which both re-centres the mark optically and lets
/// it be meaningfully larger at the same safe-circle limit.
/// Returned as a matrix rather than a transformed path so that a two-tone
/// concept can place its two pieces with the SAME fit — the fit is computed
/// once from the whole silhouette, never per piece.
Matrix4 _fitMatrix(Concept c, double side, double fraction) {
  final unit = c.unitPath();
  final pts = _samplePath(unit);
  final (tight, _) = _enclosingCircle(pts);

  // The tight centre maximises size but leaves the house sitting visibly high,
  // because its optimal centre is 0.125 below the box centre and placing that
  // on the canvas centre lifts the shape by the same amount. Halfway back
  // recovers most of the balance and costs only about 6% of the size.
  final centre = Offset.lerp(tight, unit.getBounds().center, 0.5)!;

  var radius = 0.0;
  for (final p in pts) {
    radius = math.max(radius, (p - centre).distance);
  }

  final scale = (side * fraction / 2) / radius;

  return Matrix4.identity()
    ..translateByDouble(
      side / 2 - centre.dx * scale,
      side / 2 - centre.dy * scale,
      0,
      1,
    )
    ..scaleByDouble(scale, scale, 1, 1);
}

Future<ui.Image> _renderTile({
  required Concept concept,
  required int px,
  required Color? plate,
  required Color mark,
  Color? markSecondary,
  required bool circleMask,
  double? fractionOverride,
}) async {
  final side = px.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, side, side));

  if (circleMask) {
    canvas.clipPath(
        Path()..addOval(Rect.fromLTWH(0, 0, side, side)));
  }

  if (plate != null) {
    canvas.drawRect(Rect.fromLTWH(0, 0, side, side), Paint()..color = plate);
  }

  // Preview tiles stand in for the VISIBLE masked icon (66dp), not the 108dp
  // layer, so the source fraction is rescaled by 73.4/66.
  final fraction =
      fractionOverride ?? (concept.sourceFraction * 73.4 / 66.0);

  // The roundness stroke is centred, so it dilates the silhouette by half its
  // width on every side. Shrink the fill first so fill + stroke together span
  // exactly `fraction` — without this the mark overflowed the safe circle and
  // the launcher's circular mask clipped the house's bottom corners.
  final effective = fraction / (1 + concept.roundness);
  final m = _fitMatrix(concept, side, effective);

  void fill(Path unit, Color colour) {
    final path = unit.transform(m.storage);
    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..isAntiAlias = true,
    );
    if (concept.roundness > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = colour
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..strokeWidth = side * effective * concept.roundness,
      );
    }
  }

  final parts = concept.unitParts();
  if (markSecondary != null && parts != null) {
    fill(parts.$1, mark);
    fill(parts.$2, markSecondary);
  } else {
    // Single tone — and always this branch for the monochrome layer, since a
    // themed icon has only one tint to give.
    fill(concept.unitPath(), mark);
  }

  return recorder.endRecording().toImage(px, px);
}

Future<void> _writePng(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
}

Future<ui.Image> _loadPng(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  return (await codec.getNextFrame()).image;
}

/// Renders the OUTGOING icon the way a launcher actually composites it, so the
/// reference row is a fair comparison rather than a flattering one: the source
/// foreground fills the 108dp layer, the anydpi-v26 XML insets it by 16%
/// leaving 73.4dp of art, and the visible circle is 66dp.
Future<ui.Image> _renderCurrentTile(ui.Image fg, int px, bool mono) async {
  final side = px.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, side, side));

  canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, side, side)));
  canvas.drawRect(
    Rect.fromLTWH(0, 0, side, side),
    Paint()..color = mono ? const Color(0xFF3C3C42) : const Color(0xFFFFFFFF),
  );

  final draw = side * 73.44 / 66.0;
  final paint = Paint()..filterQuality = FilterQuality.high;
  if (mono) {
    // Themed icons tint the foreground's alpha channel — which is exactly why
    // reusing this artwork as the monochrome layer flattens H, G and every
    // speed line into one shape.
    paint.colorFilter =
        const ColorFilter.mode(Color(0xFFE6E6EA), BlendMode.srcIn);
  }

  canvas.drawImageRect(
    fg,
    Rect.fromLTWH(0, 0, fg.width.toDouble(), fg.height.toDouble()),
    Rect.fromCenter(
        center: Offset(side / 2, side / 2), width: draw, height: draw),
    paint,
  );

  return recorder.endRecording().toImage(px, px);
}

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render launcher icon candidates', () async {
    // Columns: what each cell shows, left to right.
    const columns = <(int px, Colourway way, bool mono)>[
      (192, Colourway.inkPlate, false),
      (192, Colourway.goldPlate, false),
      (96, Colourway.inkPlate, false),
      (96, Colourway.goldPlate, false),
      (48, Colourway.inkPlate, false),
      (48, Colourway.goldPlate, false),
      (96, Colourway.inkPlate, true),
    ];

    const cell = 200.0, gap = 16.0, margin = 24.0;
    final rows = concepts.length + 1; // +1 reference row for the current icon
    final sheetW = margin * 2 + columns.length * cell + (columns.length - 1) * gap;
    final sheetH = margin * 2 + rows * cell + (rows - 1) * gap;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, sheetW, sheetH));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, sheetW, sheetH), Paint()..color = kSheetBg);

    for (var r = 0; r < concepts.length; r++) {
      final concept = concepts[r];
      for (var c = 0; c < columns.length; c++) {
        final (px, way, mono) = columns[c];
        final (plate, primary, secondary) = _palette(way);

        final tile = await _renderTile(
          concept: concept,
          px: px,
          // Themed icons tint the alpha channel against the system ground, so
          // the monochrome preview is a flat tint on neutral grey — and it
          // deliberately passes no secondary colour, because a themed icon
          // cannot show two.
          plate: mono ? const Color(0xFF3C3C42) : plate,
          mark: mono ? const Color(0xFFE6E6EA) : primary,
          markSecondary: mono ? null : secondary,
          circleMask: true,
        );

        _drawCentred(canvas, tile, margin, gap, cell, r, c);
      }
    }

    // Reference row: the icon being replaced, simulated the way the launcher
    // actually composites it, so the comparison is honest.
    final currentFg = await _loadPng(
        r'c:\flutter\homegrown\assets\launcher_icon\foreground.png');
    for (var c = 0; c < columns.length; c++) {
      final (px, _, mono) = columns[c];
      final tile = await _renderCurrentTile(currentFg, px, mono);
      _drawCentred(canvas, tile, margin, gap, cell, concepts.length, c);
    }

    final sheet = await recorder
        .endRecording()
        .toImage(sheetW.round(), sheetH.round());
    await _writePng(sheet, '$kScratch\\contact_sheet.png');

    // Also drop each candidate large, for judging the shape itself.
    for (final concept in concepts) {
      for (final way in Colourway.values) {
        final (plate, primary, secondary) = _palette(way);
        final img = await _renderTile(
          concept: concept,
          px: 512,
          plate: plate,
          mark: primary,
          markSecondary: secondary,
          circleMask: true,
        );
        await _writePng(img, '$kScratch\\${concept.id}_${way.name}_512.png');
      }
    }

    // ----- masters, only once a candidate has been chosen -------------------
    if (kConcept.isNotEmpty) {
      final chosen = concepts.firstWhere((c) => c.id == kConcept);
      final way = Colourway.values.firstWhere((w) => w.name == kColorway);
      final (plate, primary, secondary) = _palette(way);
      const out = r'c:\flutter\homegrown\assets\launcher_icon';

      // Foreground: mark only, transparent, at the true source fraction.
      await _writePng(
        await _renderTile(
          concept: chosen,
          px: 1024,
          plate: null,
          mark: primary,
          markSecondary: secondary,
          circleMask: false,
          fractionOverride: chosen.sourceFraction,
        ),
        '$out\\foreground.png',
      );

      // Legacy (API 24-25): plate baked in, since a transparent legacy icon
      // renders as a hole.
      await _writePng(
        await _renderTile(
          concept: chosen,
          px: 1024,
          plate: plate,
          mark: primary,
          markSecondary: secondary,
          circleMask: false,
          fractionOverride: chosen.sourceFraction,
        ),
        '$out\\legacy.png',
      );

      // Monochrome: its own file, always an opaque silhouette. Reusing the
      // foreground here is what made the outgoing themed icon unreadable.
      await _writePng(
        await _renderTile(
          concept: chosen,
          px: 1024,
          plate: null,
          mark: const Color(0xFF000000),
          circleMask: false,
          fractionOverride: chosen.sourceFraction,
        ),
        '$out\\monochrome.png',
      );

      // ignore: avoid_print
      print('Wrote masters for concept $kConcept ($kColorway) to $out');
    }

    // ignore: avoid_print
    print('Contact sheet: $kScratch\\contact_sheet.png');
  });
}

void _drawCentred(Canvas canvas, ui.Image img, double margin, double gap,
    double cell, int row, int col) {
  _drawImageAt(canvas, img, margin, gap, cell, row, col,
      img.width.toDouble());
}

void _drawImageAt(Canvas canvas, ui.Image img, double margin, double gap,
    double cell, int row, int col, double drawSize) {
  final cx = margin + col * (cell + gap) + cell / 2;
  final cy = margin + row * (cell + gap) + cell / 2;
  canvas.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    Rect.fromCenter(center: Offset(cx, cy), width: drawSize, height: drawSize),
    Paint()..filterQuality = FilterQuality.high,
  );
}
