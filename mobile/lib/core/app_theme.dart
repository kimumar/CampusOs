import 'package:flutter/material.dart';

class CampusColors {
  CampusColors._();

  static const Color violet = Color(0xFF6C55E8);
  static const Color mint = Color(0xFFA8F0D0);
  static const Color ivory = Color(0xFFF8F7FC);
  static const Color gold = Color(0xFFF7C979);
  static const Color ink = Color(0xFF202037);
  static const Color muted = Color(0xFF77758C);
  static const Color white = Color(0xFFFFFFFF);
}

class CampusTheme {
  CampusTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: CampusColors.violet,
      brightness: Brightness.light,
      surface: CampusColors.ivory,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(
        primary: CampusColors.violet,
        onPrimary: CampusColors.white,
        surface: CampusColors.ivory,
        onSurface: CampusColors.ink,
      ),
      scaffoldBackgroundColor: CampusColors.ivory,
      appBarTheme: const AppBarTheme(
        backgroundColor: CampusColors.ivory,
        foregroundColor: CampusColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: CampusColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CampusColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CampusColors.violet,
          foregroundColor: CampusColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}