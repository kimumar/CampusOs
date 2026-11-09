import 'package:flutter/material.dart';

class CampusTheme {
  CampusTheme._();

  static const Color violet = Color(0xFF6C55E8);
  static const Color ink = Color(0xFF202037);
  static const Color ivory = Color(0xFFF8F7FC);

  static const double bodySize = 16;
  static const double secondarySize = 14;
  static const double sectionTitleSize = 22;
  static const double headingSize = 32;
  static const double minimumTouchSize = 48;

  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: ivory,
        surface: Colors.white,
        text: ink,
        secondaryText: const Color(0xFF666477),
        accent: violet,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: const Color(0xFF141321),
        surface: const Color(0xFF242239),
        text: const Color(0xFFF7F4FF),
        secondaryText: const Color(0xFFBBB5D0),
        accent: const Color(0xFFC4A2FF),
      );

  static ThemeData get nightComfort => _build(
        brightness: Brightness.dark,
        background: const Color(0xFF1C1928),
        surface: const Color(0xFF2A2638),
        text: const Color(0xFFF0E8E2),
        secondaryText: const Color(0xFFD1C6CF),
        accent: const Color(0xFFC3B3F2),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color text,
    required Color secondaryText,
    required Color accent,
  }) {
    final dark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: dark
          ? const Color(0xFF171422)
          : Colors.white,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: secondaryText,
    );

    final textTheme = TextTheme(
      headlineLarge: TextStyle(
        fontSize: headingSize,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
        color: text,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: text,
      ),
      titleLarge: TextStyle(
        fontSize: sectionTitleSize,
        fontWeight: FontWeight.w800,
        color: text,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      bodyLarge: TextStyle(
        fontSize: bodySize,
        height: 1.5,
        color: text,
      ),
      bodyMedium: TextStyle(
        fontSize: secondarySize,
        height: 1.45,
        color: text,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: secondaryText,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: secondaryText,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),

      iconTheme: IconThemeData(
        color: accent,
        size: 24,
      ),

      dividerColor:
          secondaryText.withValues(alpha: 0.22),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(
            minimumTouchSize,
            minimumTouchSize,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(
            minimumTouchSize,
            minimumTouchSize,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(
          color: secondaryText,
          fontSize: 15,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        side: BorderSide(
          color: secondaryText,
          width: 1.6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor:
            accent.withValues(alpha: 0.18),
        height: 76,
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: text,
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(
            color: accent,
            size: 25,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            dark ? const Color(0xFF464151) : ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
    );
  }
}