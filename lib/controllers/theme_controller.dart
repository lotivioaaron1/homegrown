// lib/controllers/theme_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeController extends GetxController {
  static ThemeController get to => Get.find();

  static const String _key = 'is_dark_mode';

  final RxBool isDark = false.obs; // default: light mode

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
    Get.changeTheme(
      isDark.value ? AppTheme.darkTheme : AppTheme.lightTheme,
    );
    Get.changeThemeMode(
      isDark.value ? ThemeMode.dark : ThemeMode.light,
    );
  }
}