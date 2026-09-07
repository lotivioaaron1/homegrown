// lib/controllers/theme_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Owns the light/dark preference, including "follow whatever the phone does".
class ThemeController extends GetxController with WidgetsBindingObserver {
  static ThemeController get to => Get.find();

  static const String _key = 'theme_mode'; // 'system' | 'light' | 'dark'

  /// The preference as it was stored before [ThemeMode.system] was an option:
  /// a plain bool, rewritten every time the old Dark Mode switch was flipped.
  /// Read once, so an install that was already running in dark keeps running in
  /// dark instead of silently handing control to the device.
  static const String _legacyKey = 'is_dark_mode';

  final Rx<ThemeMode> mode = ThemeMode.system.obs;

  /// Whether the app is painting dark *right now*, which under
  /// [ThemeMode.system] depends on the phone rather than on anything stored.
  bool get isDark => isDarkFor(mode.value);

  static bool isDarkFor(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system => _platformIsDark,
      };

  // Deliberately via the binding rather than PlatformDispatcher.instance: the
  // binding's dispatcher is the one a widget test can drive.
  static bool get _platformIsDark =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;

  /// Reads the saved preference without needing the controller to exist yet.
  ///
  /// main() calls this before runApp so GetMaterialApp can be built with the
  /// correct themeMode from the very first frame. Loading it only in onInit
  /// meant the app rendered light, then snapped to dark a moment later — and
  /// because AppTheme's getters are resolved once per build, widgets built
  /// during that gap kept light-mode colours even after the theme changed.
  static Future<ThemeMode> savedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString(_key);
    if (saved != null) {
      return ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    }

    // Nothing under the current key: either an install that predates it, or a
    // fresh one. A legacy bool means the user made an explicit choice.
    final legacy = prefs.getBool(_legacyKey);
    if (legacy != null) return legacy ? ThemeMode.dark : ThemeMode.light;

    return ThemeMode.system;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedTheme();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// The phone switched between light and dark while the app was open.
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (mode.value == ThemeMode.system) _applyTheme();
  }

  Future<void> _loadSavedTheme() async {
    mode.value = await savedThemeMode();
    _applyTheme();
  }

  Future<void> setMode(ThemeMode value) async {
    mode.value = value;
    _applyTheme();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }

  void _applyTheme() {
    // Set this *before* anything below triggers a rebuild — see the comment on
    // AppTheme.isDark for why reading Get.isDarkMode at rebuild time gave every
    // open screen the colours of the theme it was leaving.
    AppTheme.isDark = isDark;

    // Picks between the theme/darkTheme pair GetMaterialApp already declares,
    // which is what restyles the framework's own widgets — app bars, inputs,
    // snackbars.
    //
    // Get.changeTheme is deliberately not used alongside it: that writes into
    // the slot GetMaterialApp passes as MaterialApp.theme, so pinning the dark
    // ThemeData there would make ThemeMode.system render dark on a light phone.
    Get.changeThemeMode(mode.value);

    // Rebuilding MaterialApp is not enough on its own. Every route on the stack
    // keeps its built page in ModalRoute's `_page` cache, so an ancestor
    // rebuilding does not reach it — which is why a toggle used to leave the
    // screens behind it in their old colours until navigation happened to
    // rebuild them. A reassemble is the one thing that marks the whole tree
    // dirty, and it is what GetX itself uses for the same problem on a locale
    // change.
    //
    // This is the synchronous half of Get.forceAppUpdate(), which is the same
    // half hot reload uses. The other half reassembles the render tree and
    // schedules a warm-up frame, neither of which a colour change needs.
    final binding = WidgetsBinding.instance;
    final root = binding.rootElement;
    if (root != null) binding.buildOwner?.reassemble(root);
  }
}
