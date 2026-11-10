import 'package:flutter/material.dart';

class NotionTheme {
  // Pure Black & White Dark Palette
  static const Color bg = Color(0xFF000000); // True OLED Black
  static const Color surface = Color(0xFF121212); // Deep Charcoal
  static const Color card = Color(0xFF181818); // Elevated Card
  static const Color border = Color(0xFF262626); // Subtle Border
  static const Color divider = Color(0xFF1F1F1F); // Clean Divider
  static const Color textPrimary = Color(0xFFFFFFFF); // Crisp White
  static const Color textSecondary = Color(0xFFA0A0A0); // Muted Silver
  static const Color textMuted = Color(0xFF666666); // Darker Silver
  static const Color accent = Color(0xFFFFFFFF); // Clean White Accent

  // Text Highlighting Palette for Notes / Content
  static const List<HighlightColor> highlightColors = [
    HighlightColor(name: 'Default', color: Color(0xFFFFFFFF), bg: Colors.transparent),
    HighlightColor(name: 'Red', color: Color(0xFFEF5350), bg: Color(0xFF331414)),
    HighlightColor(name: 'Green', color: Color(0xFF66BB6A), bg: Color(0xFF122E17)),
    HighlightColor(name: 'Blue', color: Color(0xFF42A5F5), bg: Color(0xFF0F253C)),
    HighlightColor(name: 'Amber', color: Color(0xFFFFA726), bg: Color(0xFF382305)),
    HighlightColor(name: 'Purple', color: Color(0xFFAB47BC), bg: Color(0xFF2B1033)),
    HighlightColor(name: 'Grey', color: Color(0xFF9E9E9E), bg: Color(0xFF222222)),
  ];

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      cardColor: card,
      dividerColor: divider,
      canvasColor: surface,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        surface: surface,
        onSurface: textPrimary,
        outline: border,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary, size: 20),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: TextStyle(
          color: textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class HighlightColor {
  final String name;
  final Color color;
  final Color bg;

  const HighlightColor({
    required this.name,
    required this.color,
    required this.bg,
  });
}
