// lib/controllers/theme_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeController extends GetxController {
  static ThemeController get to => Get.find();

  static const String _key = 'is_dark_mode';

  final RxBool isDark = false.obs; // default: light mode

  /// Reads the saved preference without needing the controller to exist yet.
  ///
  /// main() calls this before runApp so GetMaterialApp can be built with the
  /// correct themeMode from the very first frame. Loading it only in onInit
  /// meant the app rendered light, then snapped to dark a moment later — and
  /// because AppTheme's getters are resolved once per build, widgets built
  /// during that gap kept light-mode colours even after the theme changed.
  static Future<ThemeMode> savedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_key) ?? false) ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  void onInit() {
    super.onInit();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDark.value = prefs.getBool(_key) ?? false; // false = light
    _applyTheme();
  }

  Future<void> toggleTheme() async {
    isDark.value = !isDark.value;
    _applyTheme();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark.value);
  }

  void _applyTheme() {
    // Set this *before* anything below triggers a rebuild — see the comment on
    // AppTheme.isDark for why reading Get.isDarkMode at rebuild time gave every
    // open screen the colours of the theme it was leaving.
    AppTheme.isDark = isDark.value;

    // Picks between the theme/darkTheme pair GetMaterialApp already declares,
    // which is what restyles the framework's own widgets — app bars, inputs,
    // snackbars.
    //
    // Get.changeTheme is deliberately not used alongside it: it writes into the
    // slot GetMaterialApp passes as MaterialApp.theme, which then disagrees
    // with themeMode about which of the two themes is the light one.
    Get.changeThemeMode(isDark.value ? ThemeMode.dark : ThemeMode.light);

    // Rebuilding MaterialApp is not enough on its own. Every route on the stack
    // keeps its built page in ModalRoute's `_page` cache, so an ancestor
    // rebuilding never reaches it — which is why a toggle used to leave the
    // screens behind this one in their old colours until navigation happened to
    // rebuild them.
    //
    // This is the synchronous half of Get.forceAppUpdate(), which is the same
    // half hot reload uses. The other half reassembles the render tree and
    // schedules a warm-up frame, neither of which a colour change needs.
    final binding = WidgetsBinding.instance;
    final root = binding.rootElement;
    if (root != null) binding.buildOwner?.reassemble(root);
  }
}
