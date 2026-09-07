// test/widgets/theme_switching_test.dart
//
// Guards the bug where flipping Dark Mode left every screen in its old colours
// until you navigated back a couple of times.
//
// The mechanism is worth stating, because the naive version of this test passes
// against the broken code. MaterialApp animates a theme change over 200ms and
// ThemeData.lerp only flips `brightness` at the halfway point, so anything
// rebuilt in the frame the toggle fired still read the outgoing brightness —
// and the screens on the navigator stack were not being rebuilt at all, because
// ModalRoute caches each route's built page. That is why these tests pump a
// *single* frame rather than settling: settling would hide the first half of
// the defect behind the animation it is about.

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

Future<void> _pumpApp(WidgetTester tester, {required bool startDark}) async {
  SharedPreferences.setMockInitialValues({'is_dark_mode': startDark});
  AppTheme.isDark = startDark;
  Get.put(ThemeController());
  await tester.pumpWidget(_host());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppTheme.isDark = false);

  // Get.reset() only clears GetX's instance map — it does not run onClose, so
  // the controller is deleted explicitly rather than left half-disposed.
  tearDown(() {
    Get.delete<ThemeController>(force: true);
    Get.reset();
    AppTheme.isDark = false;
  });

  testWidgets('repaints a screen that is already open, on the same frame',
      (tester) async {
    await _pumpApp(tester, startDark: false);
    expect(_surface(tester), _lightBg);

    await ThemeController.to.toggleTheme();
    await tester.pump(); // one frame: the theme animation has only just begun

    expect(_surface(tester), _darkBg);
  });

  testWidgets('and turns back off again just as immediately', (tester) async {
    await _pumpApp(tester, startDark: true);
    expect(_surface(tester), _darkBg);

    await ThemeController.to.toggleTheme();
    await tester.pump();

    expect(_surface(tester), _lightBg);
  });

  testWidgets('remembers the choice for the next launch', (tester) async {
    await _pumpApp(tester, startDark: false);

    await ThemeController.to.toggleTheme();

    expect(await ThemeController.savedThemeMode(), ThemeMode.dark);
  });
}
