// test/widgets/no_internet_overlay_test.dart
//
// Covers the full-screen offline gate. Three of these guard defects the polish
// pass fixed rather than styling:
//
//   * two of the three waiting dots used to freeze after about a second,
//   * the panel could not scroll, so it overflowed in landscape or at a large
//     font scale,
//   * "Try Again" gave no feedback during a DNS lookup that can take five
//     seconds.
//
// ConnectivityService cannot be used as-is: its onInit hits the
// connectivity_plus platform channel and then does a real DNS lookup, neither
// of which exists under flutter_test. The fake below skips onInit and drives
// the same observables by hand.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:homegrown/services/connectivity_service.dart';
import 'package:homegrown/widgets/no_internet_overlay.dart';

class _FakeConnectivity extends ConnectivityService {
  /// Completed by the test to control how long a retry appears to take.
  Completer<void>? retryGate;
  int retryCalls = 0;

  // Deliberately does not call super: the real onInit reaches for the
  // connectivity_plus platform channel and then the network, and neither is
  // available here. Skipping it is the whole point of the fake.
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> retryConnection() async {
    retryCalls++;
    if (retryGate != null) await retryGate!.future;
  }
}

// GetMaterialApp, not MaterialApp: AppTheme's semantic getters switch on
// Get.isDarkMode, which needs Get's theme in scope.
Widget _host({
  bool disableAnimations = true,
  TextScaler textScaler = TextScaler.noScaling,
}) =>
    GetMaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: textScaler,
        ),
        child: NoInternetOverlay(child: child ?? const SizedBox.shrink()),
      ),
      home: const Scaffold(body: Center(child: Text('app content'))),
    );

/// The panel is taller than the default 800x600 test viewport, so the retry
/// button sits below the fold and cannot be tapped. Give those tests a phone-
/// shaped viewport that fits the whole thing.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late _FakeConnectivity service;

  setUp(() {
    service = _FakeConnectivity();
    Get.put<ConnectivityService>(service);
  });

  tearDown(Get.reset);

  group('visibility', () {
    testWidgets('stays out of the way while connected', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.text('app content'), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing);
    });

    testWidgets('covers the app once the connection drops', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      service.isConnected.value = false;
      await tester.pumpAndSettle();

      expect(find.text('No Internet Connection'), findsOneWidget);
    });

    // The dish and the three tips are things the screen was built with. A
    // later restyle is free to move them; it should not quietly drop them.
    testWidgets('keeps the dish and all three tips', (tester) async {
      await tester.pumpWidget(_host());
      service.isConnected.value = false;
      await tester.pumpAndSettle();

      // The dish is now a Lucide icon rather than the 📡 emoji — the same
      // element, drawn from the app's icon set.
      expect(find.byIcon(LucideIcons.satelliteDish), findsOneWidget);
      expect(find.text('Check your Wi-Fi connection'), findsOneWidget);
      expect(find.text('Check your mobile data'), findsOneWidget);
      expect(find.text('Make sure Airplane mode is off'), findsOneWidget);
    });
  });

  group('subtitle', () {
    testWidgets('blames the connection when there is no adapter',
        (tester) async {
      await tester.pumpWidget(_host());
      service.isConnected.value = false;
      service.hasNetworkButNoInternet.value = false;
      await tester.pumpAndSettle();

      expect(find.textContaining('requires an internet connection'),
          findsOneWidget);
    });

    // "Check your Wi-Fi" is useless advice to someone staring at a connected
    // Wi-Fi icon, so a captive portal has to say something else.
    testWidgets('blames the network when the adapter is up', (tester) async {
      await tester.pumpWidget(_host());
      service.isConnected.value = false;
      service.hasNetworkButNoInternet.value = true;
      await tester.pumpAndSettle();

      expect(find.textContaining('this network has no internet'),
          findsOneWidget);
    });
  });

  group('waiting dots', () {
    Color dotColor(WidgetTester tester, int i) {
      final container = tester.widget<Container>(
        find.byKey(ValueKey(dotKey(i))),
      );
      return (container.decoration as BoxDecoration).color!;
    }

    // The regression this rewrite exists for. Three controllers were started
    // with repeat(), then nudged out of phase with forward() from a delayed
    // callback — but forward() cancels a repeat, so dots 1 and 2 ran one pass
    // and stopped at full opacity. Sampling the row as a whole would not
    // notice, because dot 0 kept going.
    testWidgets('all three keep pulsing, not just the first', (tester) async {
      await tester.pumpWidget(_host(disableAnimations: false));
      service.isConnected.value = false;
      await tester.pump();

      final seen = {0: <double>{}, 1: <double>{}, 2: <double>{}};
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 175));
        for (var i = 0; i < 3; i++) {
          seen[i]!.add(double.parse(dotColor(tester, i).a.toStringAsFixed(3)));
        }
      }

      for (var i = 0; i < 3; i++) {
        expect(seen[i]!.length, greaterThan(1),
            reason: 'dot $i never changed opacity — it is frozen');
      }

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('are out of phase with each other', (tester) async {
      await tester.pumpWidget(_host(disableAnimations: false));
      service.isConnected.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(dotColor(tester, 0).a, isNot(closeTo(dotColor(tester, 1).a, 0.01)));
      expect(dotColor(tester, 1).a, isNot(closeTo(dotColor(tester, 2).a, 0.01)));

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('reduced motion', () {
    // Both the dots and the radar rings run on repeating controllers. Under
    // Reduce Motion they must not start — the user asked for no motion, and a
    // permanently scheduled frame means pumpAndSettle can never return.
    testWidgets('settles when animations are disabled', (tester) async {
      await tester.pumpWidget(_host(disableAnimations: true));
      service.isConnected.value = false;

      // Would time out if either controller were repeating.
      await tester.pumpAndSettle();

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps animating when motion is allowed', (tester) async {
      await tester.pumpWidget(_host(disableAnimations: false));
      service.isConnected.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('layout', () {
    // The column was fixed-height and unscrollable, so a short viewport or a
    // large font scale produced an overflow stripe over the whole screen.
    testWidgets('does not overflow a short viewport at a large font scale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(textScaler: const TextScaler.linear(1.5)),
      );
      service.isConnected.value = false;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('still centres its content when there is room',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host());
      service.isConnected.value = false;
      await tester.pumpAndSettle();

      final title = tester.getCenter(find.text('No Internet Connection'));
      // Roughly mid-screen rather than pinned to the top, which is what a
      // plain SingleChildScrollView would have given.
      expect(title.dy, greaterThan(200));
      expect(title.dy, lessThan(800));
    });
  });

  group('retry', () {
    testWidgets('shows a busy state instead of sitting inert',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_host());
      service.isConnected.value = false;
      service.retryGate = Completer<void>();
      await tester.pumpAndSettle();

      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(find.text('Checking…'), findsOneWidget);
      expect(find.text('Try Again'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      service.retryGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Try Again'), findsOneWidget);
    });

    // A five-second lookup with no feedback used to invite repeat taps, each
    // one starting another lookup.
    testWidgets('ignores further taps while a check is in flight',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_host());
      service.isConnected.value = false;
      service.retryGate = Completer<void>();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell));
      await tester.pump();
      await tester.tap(find.byType(InkWell), warnIfMissed: false);
      await tester.tap(find.byType(InkWell), warnIfMissed: false);
      await tester.pump();

      expect(service.retryCalls, 1);

      service.retryGate!.complete();
      await tester.pumpAndSettle();
    });

    // A successful retry tears the overlay down while the await is still
    // pending, disposing the button mid-flight.
    testWidgets('survives the overlay being torn down mid-check',
        (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(_host());
      service.isConnected.value = false;
      service.retryGate = Completer<void>();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      // What retryConnection does on success: flips the observable, which
      // removes the panel and disposes _RetryButton.
      service.isConnected.value = true;
      await tester.pumpAndSettle();

      service.retryGate!.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'setState after dispose must be guarded');
      expect(find.text('app content'), findsOneWidget);
    });
  });
}
