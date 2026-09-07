// lib/widgets/skeleton.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Loading placeholders that mirror the shape of the content they stand in
/// for, instead of a spinner in the middle of an empty screen.
///
/// A spinner says "something is happening"; a skeleton says "a list of games
/// is about to appear here", which makes the wait read as shorter even when
/// it is not. It also stops the layout jumping when real data lands, because
/// the placeholder already occupies roughly the right space.
///
/// Wrap a group of [SkeletonBox]es in a single [Shimmer] so one animation
/// drives the whole screen — a separate controller per box would drift out of
/// phase and look like noise.

/// Sweeps a highlight across everything inside it.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Honour the OS "reduce motion" setting: a constantly sweeping highlight
    // is exactly the kind of thing it exists to switch off. The static
    // placeholders still convey the loading state.
    if (MediaQuery.of(context).disableAnimations) return widget.child;

    final base = AppTheme.cardNested;
    final highlight = AppTheme.border;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [base, highlight, base],
          stops: const [0.1, 0.5, 0.9],
          // Travels from fully off-screen left to fully off-screen right.
          transform: _SlideGradient(_c.value * 2 - 1),
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Shifts a gradient horizontally by a fraction of the painted width.
class _SlideGradient extends GradientTransform {
  final double slide;
  const _SlideGradient(this.slide);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0, 0);
}

/// A single placeholder block. Give it the dimensions of the thing it
/// replaces so the layout does not shift when real content arrives.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  /// A line of text. [widthFactor] lets a paragraph end raggedly rather than
  /// as a suspiciously perfect rectangle.
  const SkeletonBox.text({super.key, this.width})
      : height = 12,
        radius = 6;

  const SkeletonBox.circle({super.key, required double diameter})
      : width = diameter,
        height = diameter,
        radius = diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.cardNested,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A card-shaped placeholder matching the app's list rows: leading circle,
/// two stacked text lines, trailing value.
class SkeletonListTile extends StatelessWidget {
  final bool showLeading;
  final bool showTrailing;

  const SkeletonListTile({
    super.key,
    this.showLeading = true,
    this.showTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        if (showLeading) ...[
          const SkeletonBox.circle(diameter: 40),
          const SizedBox(width: 12),
        ],
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 130, height: 13),
              SizedBox(height: 8),
              SkeletonBox(width: 84, height: 10),
            ],
          ),
        ),
        if (showTrailing) ...[
          const SizedBox(width: 12),
          const SkeletonBox(width: 44, height: 24, radius: 8),
        ],
      ]),
    );
  }
}

/// Stand-in for the home dashboard while Firestore is still answering.
///
/// Mirrors the real layout — greeting, points card, then a short run of rows
/// — so the transition to live content is a swap rather than a reflow.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 120, height: 12),
            const SizedBox(height: 10),
            const SkeletonBox(width: 180, height: 24),
            const SizedBox(height: 10),
            const SkeletonBox(width: 140, height: 22, radius: 11),
            const SizedBox(height: 22),
            Container(
              height: 132,
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border),
              ),
            ),
            const SizedBox(height: 22),
            const SkeletonBox(width: 92, height: 11),
            const SizedBox(height: 12),
            const SkeletonListTile(),
            const SizedBox(height: 10),
            const SkeletonListTile(showTrailing: true),
            const SizedBox(height: 22),
            const SkeletonBox(width: 110, height: 11),
            const SizedBox(height: 12),
            const SkeletonListTile(showTrailing: true),
          ],
        ),
      ),
    );
  }
}
