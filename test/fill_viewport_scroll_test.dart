// test/fill_viewport_scroll_test.dart
//
// Covers FillViewportScroll, which replaced a hardcoded SizedBox(height: 262)
// that had been pushing the "Next" button down step 1 of every registration
// screen. The fixed gap only landed correctly on the screen size it was
// measured against, so the two cases that matter are a short step (button
// pinned to the bottom) and a tall one (scrolls, no overflow).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/widgets/fill_viewport_scroll.dart';

const _padding = EdgeInsets.fromLTRB(24, 20, 24, 24);
const _footerKey = Key('footer');

/// Sizes the test surface itself rather than nesting a tall SizedBox — a
/// SizedBox taller than the default 800x600 test window is clamped to it, so
/// every "viewport" would otherwise measure the same 600.
Future<void> _pumpAt(
  WidgetTester tester, {
  required double viewport,
  required int fieldCount,
}) async {
  await tester.binding.setSurfaceSize(Size(400, viewport));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: FillViewportScroll(
        padding: _padding,
        child: Column(
          children: [
            for (var i = 0; i < fieldCount; i++)
              const SizedBox(height: 60, child: Text('field')),
            const Spacer(),
            const SizedBox(key: _footerKey, height: 54, child: Text('Next')),
          ],
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('pins the footer to the bottom when the content is short',
      (tester) async {
    await _pumpAt(tester, viewport: 600, fieldCount: 3);

    final footer = tester.getRect(find.byKey(_footerKey));
    // 600 viewport - 24 bottom padding = the footer's expected bottom edge.
    expect(footer.bottom, moreOrLessEquals(576, epsilon: 0.5));
  });

  testWidgets('tracks the viewport rather than the last field',
      (tester) async {
    await _pumpAt(tester, viewport: 750, fieldCount: 3);

    final footer = tester.getRect(find.byKey(_footerKey));
    // The whole point: the same content on a taller screen puts the button
    // at the bottom of that screen, not a fixed distance below the fields.
    expect(footer.bottom, moreOrLessEquals(726, epsilon: 0.5));
  });

  testWidgets('scrolls instead of overflowing when the content is tall',
      (tester) async {
    await _pumpAt(tester, viewport: 400, fieldCount: 12);
    // A RenderFlex overflow would have been reported by now.
    expect(tester.takeException(), isNull);

    // The footer is past the fold, so it takes a scroll to reach it.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.byKey(_footerKey), findsOneWidget);
    expect(tester.getRect(find.byKey(_footerKey)).bottom, lessThan(1000));
  });

  testWidgets('falls back to natural layout when height is unbounded',
      (tester) async {
    // Nested inside another scroll view there is no viewport to fill; the
    // widget must lay out rather than assert on an infinite minHeight.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FillViewportScroll(
            padding: _padding,
            child: Column(children: [
              SizedBox(height: 60, child: Text('field')),
              SizedBox(key: _footerKey, height: 54, child: Text('Next')),
            ]),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.byKey(_footerKey), findsOneWidget);
  });
}
