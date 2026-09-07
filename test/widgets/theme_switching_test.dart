// test/widgets/theme_switching_test.dart
//
// Guards the bug where flipping Dark Mode left every screen in its old colours
// until you navigated back a couple of times.
//
// The mechanism is worth stating, because the naive version of this test passes
// against the broken code. GetX rebuilds every route on the stack in the same
// frame the theme changes — but MaterialApp animates the change over 200ms and
// ThemeData.lerp only flips `brightness` at the halfway point, so a rebuild in
// that first frame still read the outgoing brightness. That is why the first
// test pumps a *single* frame rather than settling: settling would hide the
// defect behind the animation it is about.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:homegrown/controllers/theme_controller.dart';
import 'package:homegrown/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lightBg = Color(0xFFFAFAF5);
const _darkBg = Color(0xFF0F0F1A);

/// Stands in for any screen in the app: it paints one of AppTheme's semantic
/// getters, and it is reached through the navigator, so it sits behind
/// ModalRoute's page cache exactly like a real one.
Widget _host() => GetMaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Builder(
        builder: (_) => Container(key: const Key('surface'), color: AppTheme.bg),
      ),
    );

Color? _surface(WidgetTester tester) =>
    tester.widget<Container>(find.byKey(const Key('surface'))).color;

Future<void> _pumpApp(WidgetTester tester, {required ThemeMode start}) async {
  SharedPreferences.setMockInitialValues({'theme_mode': start.name});
  AppTheme.isDark = ThemeController.isDarkFor(start);
  Get.put(ThemeController());
  await tester.pumpWidget(_host());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppTheme.isDark = false);

  // Get.reset() only clears GetX's instance map — it does not run onClose, so
  // without the delete the controller stays registered as a
  // WidgetsBindingObserver and keeps reacting to the next test's brightness.
  tearDown(() {
    Get.delete<ThemeController>(force: true);
    Get.reset();
    AppTheme.isDark = false;
  });

  group('turning dark mode on', () {
    testWidgets('repaints a screen that is already open, on the same frame',
        (tester) async {
      await _pumpApp(tester, start: ThemeMode.light);
      expect(_surface(tester), _lightBg);

      await ThemeController.to.setMode(ThemeMode.dark);
      await tester.pump(); // one frame: the theme animation has only just begun

      expect(_surface(tester), _darkBg);
    });

    testWidgets('and back off again', (tester) async {
      await _pumpApp(tester, start: ThemeMode.dark);
      expect(_surface(tester), _darkBg);

      await ThemeController.to.setMode(ThemeMode.light);
      await tester.pump();

      expect(_surface(tester), _lightBg);
    });
  });

  group('following the device', () {
    testWidgets('picks up the phone flipping to dark while the app is open',
        (tester) async {
      await _pumpApp(tester, start: ThemeMode.system);
      expect(_surface(tester), _lightBg);

      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      expect(_surface(tester), _darkBg);
    });

    testWidgets('stops following once an explicit choice is made',
        (tester) async {
      await _pumpApp(tester, start: ThemeMode.system);

      await ThemeController.to.setMode(ThemeMode.light);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      expect(_surface(tester), _lightBg);
    });
  });

  group('savedThemeMode', () {
    test('defaults a fresh install to following the device', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await ThemeController.savedThemeMode(), ThemeMode.system);
    });

    test('keeps a Dark Mode choice made before system mode existed', () async {
      SharedPreferences.setMockInitialValues({'is_dark_mode': true});

      expect(await ThemeController.savedThemeMode(), ThemeMode.dark);
    });

    test('reads back what setMode wrote', () async {
      SharedPreferences.setMockInitialValues({});
      Get.put(ThemeController());

      await ThemeController.to.setMode(ThemeMode.dark);

      expect(await ThemeController.savedThemeMode(), ThemeMode.dark);
    });
  });
}
