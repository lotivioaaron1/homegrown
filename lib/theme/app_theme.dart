// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────
  // Brand — Gold Scale
  // ─────────────────────────────────────────────

  static const Color accent      = Color(0xFFFFB800); // ⭐ Gold primary
  static const Color accent2     = Color(0xFFCC9500); // Gold deep (gradient end)
  static const Color accentLight = Color(0xFFFFD04D); // Gold tint

  // ─────────────────────────────────────────────
  // Status — same both modes
  // ─────────────────────────────────────────────

  static const Color success = Color(0xFF22C55E);
  static const Color error   = Color(0xFFFF5C5C);
  static const Color warning = Color(0xFFFF9500);
  static const Color info    = Color(0xFF3B8BFF);

  // ─────────────────────────────────────────────
  // Semantic — theme-aware getters
  // ─────────────────────────────────────────────

  static bool get _isDark => Get.isDarkMode;

  /// Scaffold background
  static Color get bg => _isDark
      ? const Color(0xFF0F0F1A)
      : const Color(0xFFFAFAF5);

  /// Card / primary surface
  static Color get card => _isDark
      ? const Color(0xFF1A1A2E)
      : Colors.white;

  /// Nested card / secondary surface
  static Color get cardNested => _isDark
      ? const Color(0xFF1E1E35)
      : const Color(0xFFF5F4EE);

  /// Input field fill
  static Color get inputFill => _isDark
      ? const Color(0xFF252540)
      : const Color(0xFFEDEAE0);

  /// Border / divider
  static Color get border => _isDark
      ? const Color(0xFF2A2A3E)
      : const Color(0xFFE8E4D0);

  /// Primary text
  static Color get textPrimary => _isDark
      ? Colors.white
      : const Color(0xFF1A1A2E);

  /// Secondary / subtitle text
  static Color get sub => _isDark
      ? const Color(0xFF8888AA)
      : const Color(0xFF555566);

  /// Tertiary text — captions, hints, disabled states.
  ///
  /// Was a single value for both modes, which left it at roughly 3.5:1 on the
  /// light background — under the 4.5:1 needed for body text. The dark-mode
  /// value is unchanged; only light mode darkens.
  static Color get muted => _isDark
      ? const Color(0xFF8888AA)
      : const Color(0xFF6B6B80);

  /// Gold-tinted surface (chip bg, highlight card bg)
  static Color get accentSurface => _isDark
      ? const Color(0xFF2E1F00)
      : const Color(0xFFFFF8E6);

  /// Accent text colour — bright on dark, deep on light
  static Color get accentText => _isDark
      ? const Color(0xFFFFB800)
      : const Color(0xFF996B00);

  /// Button foreground (always dark for gold buttons)
  static const Color buttonFg = Color(0xFF1A1100);

  // ─────────────────────────────────────────────
  // ThemeData — Dark
  // ─────────────────────────────────────────────

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness:              Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F0F1A),

    colorScheme: const ColorScheme.dark(
      primary:   Color(0xFFFFB800),
      secondary: Color(0xFFCC9500),
      surface:   Color(0xFF1A1A2E),
      error:     Color(0xFFFF5C5C),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor:  Color(0xFF0F0F1A),
      foregroundColor:  Colors.white,
      elevation:        0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFB800),
        foregroundColor: const Color(0xFF1A1100),
        elevation:       0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize:   16,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFFB800),
        side: const BorderSide(color: Color(0xFF2A2A3E), width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled:    true,
      fillColor: const Color(0xFF1A1A2E),

      // Was 0xFF1A1A2E — the exact same value as fillColor above, which made
      // every input label invisible in dark mode.
      labelStyle: const TextStyle(color: Color(0xFF8888AA)),
      floatingLabelStyle: const TextStyle(color: Color(0xFFFFB800)),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A2A3E), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFFB800), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF5C5C), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF5C5C), width: 1.5),
      ),
      hintStyle: const TextStyle(color: Color(0xFF8888AA), fontSize: 14),
      errorStyle: const TextStyle(color: Color(0xFFFF5C5C), fontSize: 11),
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF1A1A2E),
      contentTextStyle: TextStyle(color: Colors.white),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A2A3E),
      thickness: 1,
    ),
  );

  // ─────────────────────────────────────────────
  // ThemeData — Light
  // ─────────────────────────────────────────────

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness:              Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFAFAF5),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF1A1A2E)), 
      bodyMedium: TextStyle(color: Color(0xFF1A1A2E)),
    ),

    colorScheme: const ColorScheme.light(
      primary:   Color(0xFFFFB800),
      secondary: Color(0xFFCC9500),
      surface:   Colors.white,
      onSurface: Color(0xFF1A1A2E),
      error:     Color(0xFFFF5C5C),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor:  Color(0xFFFAFAF5),
      foregroundColor:  Color(0xFF1A1A2E),
      elevation:        0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFB800),
        foregroundColor: const Color(0xFF1A1100),
        elevation:       0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize:   16,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF996B00),
        side: const BorderSide(color: Color(0xFFE8E4D0), width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled:    true,
      fillColor: Colors.white,

      labelStyle: const TextStyle(color: Color(0xFF555566)),
      hintStyle: const TextStyle(color: Color(0xFF8888AA), fontSize: 14),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE8E4D0), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFFB800), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF5C5C), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF5C5C), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFF5C5C), fontSize: 11),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.white,
      contentTextStyle: const TextStyle(color: Color(0xFF1A1A2E)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE8E4D0)),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFE8E4D0),
      thickness: 1,
    ),

    cardTheme: CardThemeData(
      color:     Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}