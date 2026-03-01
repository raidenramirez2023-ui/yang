import 'package:flutter/material.dart';

/// Professional App Theme System
class AppTheme {
  // Primary Colors
  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color primaryRedDark = Color(0xFFB71C1C);
  static const Color primaryRedLight = Color(0xFFEF5350);

  // Neutral Colors
  static const Color darkGrey = Color(0xFF212121);
  static const Color mediumGrey = Color(0xFF757575);
  static const Color lightGrey = Color(0xFFEEEEEE);
  static const Color white = Color(0xFFFFFFFF);
  static const Color backgroundColor = Color(0xFFFAFAFA);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkMediumGrey = Color(0xFF2C2C2C);

  // Accent Colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFFA726);
  static const Color errorRed = Color(0xFFE53935);
  static const Color infoBlue = Color(0xFF2196F3);

  // Get light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryRed,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: Colors.black,
        elevation: 2,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryRed,
          side: const BorderSide(color: primaryRed, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryRed,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryRed, width: 2),
        ),
        labelStyle: const TextStyle(
          color: mediumGrey,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: mediumGrey,
        filled: false,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: darkGrey,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: darkGrey,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: darkGrey,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkGrey,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkGrey,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkGrey,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: darkGrey,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: darkGrey,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: darkGrey,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: mediumGrey,
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: white,
        elevation: 2,
      ),
    );
  }

  // Get dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryRed,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.dark(
        primary: primaryRed,
        secondary: primaryRedLight,
        surface: darkSurface,
        background: darkBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: darkSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryRedLight,
          side: const BorderSide(color: primaryRedLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkMediumGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkMediumGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryRedLight, width: 2),
        ),
        labelStyle: const TextStyle(
          color: lightGrey,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: lightGrey,
        filled: true,
        fillColor: darkMediumGrey,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: white,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: white,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: white,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: white,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: white,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: white,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: white,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: white,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: lightGrey,
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: darkSurface,
        elevation: 2,
      ),
    );
  }

  // Spacing constants
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Border radius
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
}