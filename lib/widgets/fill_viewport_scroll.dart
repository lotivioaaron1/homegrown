// lib/widgets/fill_viewport_scroll.dart

import 'package:flutter/material.dart';

/// A scroll view that stretches its child to at least the viewport height, so
/// a [Spacer] inside can push a footer — a "Next" button, typically — down to
/// the bottom of the screen.
///
/// A plain [SingleChildScrollView] hands its child unbounded height. That
/// makes [Spacer] unusable inside one and invites a fixed-height spacer
/// instead, which only lands correctly on the screen it was measured against:
/// taller phones show a gap above the button, shorter ones have to scroll to
/// reach it. This fills the viewport when the content is shorter than it and
/// scrolls normally when the content is taller — including when the keyboard
/// opens and the viewport shrinks.
class FillViewportScroll extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const FillViewportScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          // The padding sits outside the constrained box, so the minimum has
          // to leave room for it — otherwise the content is always taller
          // than the viewport by exactly the padding and always scrolls.
          //
          // An unbounded height (a parent that scrolls too) leaves nothing to
          // fill, so fall back to the natural layout rather than asserting.
          final fill = constraints.maxHeight.isFinite
              ? (constraints.maxHeight - padding.vertical)
                  .clamp(0.0, double.infinity)
              : 0.0;

          return SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: fill),
              // Gives the column a bounded height, which is what a Spacer
              // inside it needs in order to have anything to expand into.
              child: IntrinsicHeight(child: child),
            ),
          );
        },
      );
}
