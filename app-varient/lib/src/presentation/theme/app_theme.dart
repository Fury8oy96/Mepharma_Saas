import 'package:flutter/material.dart';

/// Modern, clean Vuexy-inspired design system for MePharma.
abstract final class AppTheme {
  // Brand Palette
  static const Color primary = Color(0xFF7367F0); // Signature Violet
  static const Color darkPrimary = Color(0xFF818CF8); // Indigo 400
  static const Color secondary = Color(0xFF00CFE8); // Cyan Accent
  static const Color success = Color(0xFF28C76F); // Emerald
  static const Color warning = Color(0xFFFF9F43); // Orange
  static const Color error = Color(0xFFEA5455); // Crimson

  // Light Tokens (Vuexy Modern Light)
  static const Color _lightCanvas = Color(0xFFF8F7FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceVariant = Color(0xFFF1F0F5);
  static const Color _lightBorder = Color(0xFFDBDADE);
  static const Color _lightTextPrimary = Color(0xFF5D596C);
  static const Color _lightTextMuted = Color(0xFF6F6B7D);

  // Dark Tokens (Vuexy Modern Dark)
  static const Color _darkCanvas = Color(0xFF161D31);
  static const Color _darkSurface = Color(0xFF283046);
  static const Color _darkSurfaceVariant = Color(0xFF1F263B);
  static const Color _darkBorder = Color(0xFF3B4253);
  static const Color _darkTextPrimary = Color(0xFFD0D2D6);
  static const Color _darkTextMuted = Color(0xFFB4B7BD);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      tertiary: success,
      surface: _lightSurface,
      surfaceContainerHighest: _lightSurfaceVariant,
      outlineVariant: _lightBorder,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _lightCanvas,
      dividerColor: _lightBorder,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: _lightTextPrimary),
        bodyMedium: TextStyle(color: _lightTextPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightSurface,
        foregroundColor: primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _lightBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: _lightTextMuted),
        prefixIconColor: _lightTextMuted,
        suffixIconColor: _lightTextMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: primary.withValues(alpha: 0.12),
          selectedForegroundColor: primary,
          side: const BorderSide(color: _lightBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: darkPrimary,
      secondary: secondary,
      tertiary: success,
      surface: _darkSurface,
      surfaceContainerHighest: _darkSurfaceVariant,
      outlineVariant: _darkBorder,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkCanvas,
      dividerColor: _darkBorder,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: _darkTextPrimary),
        bodyMedium: TextStyle(color: _darkTextPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: _darkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: darkPrimary, width: 2),
        ),
        labelStyle: const TextStyle(color: _darkTextMuted),
        prefixIconColor: _darkTextMuted,
        suffixIconColor: _darkTextMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: _darkCanvas,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: _darkCanvas,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: darkPrimary),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: darkPrimary.withValues(alpha: 0.15),
          selectedForegroundColor: darkPrimary,
          side: const BorderSide(color: _darkBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
