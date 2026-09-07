// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// Whether the getters below resolve to their dark values.
  ///
  /// [ThemeController] owns this and sets it before it triggers the rebuild
  /// that repaints the app.
  ///
  /// It is a plain flag rather than `Get.isDarkMode` on purpose. That reads
  /// `Theme.of(context).brightness`, MaterialApp animates a theme change over
  /// 200ms, and `ThemeData.lerp` only flips `brightness` at the halfway point —
  /// so a screen rebuilding in the frame the toggle fires still saw the theme
  /// it was *leaving*, re-rendered in the old colours, and stayed that way
  /// because nothing marked it dirty again once the animation finished.
  static bool isDark = false;

  static bool get _isDark => isDark;

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
  ///
  /// The dark value used to be 0xFF8888AA — the exact same colour as [muted],
  /// which collapsed the three text tiers into two in dark mode only. Light
  /// mode always had the separation; dark mode now matches it.
  static Color get sub => _isDark
      ? const Color(0xFFA0A0BE)
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

  // ── Error / success surfaces ─────────────────────────────────────────────
  //
  // The app was built dark-first, so every red or green panel hardcoded a
  // dark-only hex (0xFF2A1A1A, 0xFF0D2E20, …) and stayed dark on the light
  // background. These follow the accentSurface/accentText precedent above:
  // the dark values are the hexes that were already in use, so dark mode is
  // unchanged; light mode finally has somewhere to switch to.

  /// Error-tinted surface (destructive card, warning banner)
  static Color get errorSurface => _isDark
      ? const Color(0xFF2A1A1A)
      : const Color(0xFFFDECEC);

  /// Nested surface sitting *on* an [errorSurface] — e.g. an icon tile
  static Color get errorSurfaceStrong => _isDark
      ? const Color(0xFF3A1A1A)
      : const Color(0xFFFAD9D9);

  /// Error text/icon colour. [error] is the raw status red and fails contrast
  /// on white (3.0:1) — use this for anything the user has to read.
  static Color get errorText => _isDark
      ? const Color(0xFFFF5C5C)
      : const Color(0xFFB3261E);

  /// Success-tinted surface (open-to-recruitment chip, confirmation panel)
  static Color get successSurface => _isDark
      ? const Color(0xFF0D2E20)
      : const Color(0xFFE7F6EC);

  /// Success text/icon colour. [success] is 2.3:1 on white — same caveat as
  /// [errorText].
  static Color get successText => _isDark
      ? const Color(0xFF22C55E)
      : const Color(0xFF15803D);

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