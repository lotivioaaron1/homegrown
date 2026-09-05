// test/widgets/auth_hero_test.dart
//
// The photographic band shared by login and the signup role picker.
//
// Asset bundles are empty under flutter_test, so every case here exercises the
// errorBuilder path. That is the point worth pinning: a missing or unloadable
// image must degrade to the gradient rather than throw, because the fallback
// is what keeps layout intact on a device where decoding fails.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/widgets/auth_hero.dart';

Widget _host({
  double height = 200,
  Alignment alignment = Alignment.center,
  Widget? child,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            AuthHero(
              asset: 'assets/images/onboard_volleyball.jpg',
              height: height,
              alignment: alignment,
              child: child,
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('renders without throwing when the asset cannot load',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(AuthHero), findsOneWidget);
  });

  testWidgets('occupies exactly the height it was given', (tester) async {
    await tester.pumpWidget(_host(height: 173));
    await tester.pump();

    expect(tester.getSize(find.byType(AuthHero)).height, 173);
  });

  testWidgets('stretches to the full width available', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    final width = tester.getSize(find.byType(AuthHero)).width;
    expect(width, tester.getSize(find.byType(Scaffold)).width);
  });

  testWidgets('passes its alignment to the image', (tester) async {
    await tester.pumpWidget(_host(alignment: const Alignment(0, -0.62)));
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.alignment, const Alignment(0, -0.62));
    expect(image.fit, BoxFit.cover);
  });

  group('child', () {
    testWidgets('is not built when none is given', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump();

      expect(find.byType(SafeArea), findsNothing);
    });

    // Inset from the status bar rather than the top of the band, so anything
    // placed here does not end up under the system clock.
    testWidgets('is shown inside a top SafeArea when given', (tester) async {
      await tester.pumpWidget(_host(child: const Text('over the photo')));
      await tester.pump();

      expect(find.text('over the photo'), findsOneWidget);

      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
      expect(safeArea.top, isTrue);
      expect(safeArea.bottom, isFalse,
          reason: 'the band has no bottom system inset to avoid');
    });
  });
}
