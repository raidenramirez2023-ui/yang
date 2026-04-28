import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Professional App Theme System
class AppTheme {
  // Primary Colors (Refined for better contrast and modern feel)
  static const Color primaryColor = Color(0xFFC62828); // Deeper, more elegant red
  static const Color primaryDark = Color(0xFF8E0000);

  // Primary gradient (welcome banner, sidebar header)
  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [primaryColor, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Consistent section heading style
  static const TextStyle sectionHeaderStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: darkGrey,
    letterSpacing: -0.3,
  );

  // Spacing helper — returns a vertical SizedBox
  static SizedBox gap(double height) => SizedBox(height: height);

  static const Color primaryLight = Color(0xFFFF5F52);

  // Neutral Colors (Warmer undertones for red theme)
  static const Color darkGrey = Color(0xFF2C1E1E);
  static const Color mediumGrey = Color(0xFF9E8E8E);
  static const Color lightGrey = Color(0xFFF0E8E8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color backgroundColor = Color(0xFFFFF9F9); // Subtle off-white red background
  static const Color navColor = Color(0xFFB71C1C); // Deep Crimson for nav & header

  // Accent Colors
  static const Color successGreen = Color(0xFF34C759);
  static const Color warningOrange = Color(0xFFFF9500);
  static const Color errorRed = Color(0xFFFF3B30);
  static const Color infoBlue = Color(0xFF007AFF);

  // Get light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      // Default typography refined for modern geometric appearance
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: white,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        iconTheme: const IconThemeData(color: white),
        titleTextStyle: GoogleFonts.lora(
          color: white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0, // We will use custom shadow containers or rely on M3 subtle elevations
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: white,
        margin: EdgeInsets.zero, // Clean margins
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) return lightGrey;
            return primaryColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) return mediumGrey;
            return white;
          }),
          elevation: WidgetStateProperty.resolveWith<double>((states) {
            if (states.contains(WidgetState.hovered)) return 6;
            if (states.contains(WidgetState.pressed)) return 2;
            if (states.contains(WidgetState.disabled)) return 0;
            return 2; // Default subtle elevation
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) return mediumGrey;
            return primaryColor;
          }),
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(color: lightGrey, width: 1.5);
            }
            return const BorderSide(color: primaryColor, width: 1.5);
          }),
          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.hovered)) {
              return primaryColor.withValues(alpha: 0.04);
            }
            if (states.contains(WidgetState.pressed)) {
              return primaryColor.withValues(alpha: 0.12);
            }
            return null;
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) return mediumGrey;
            return primaryColor;
          }),
          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.hovered)) {
              return primaryColor.withValues(alpha: 0.04);
            }
            return null;
          }),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16, // Slightly taller for modern look
        ),
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        labelStyle: const TextStyle(
          color: mediumGrey,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: mediumGrey,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: darkGrey,
            letterSpacing: -0.5,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: darkGrey,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: darkGrey,
            letterSpacing: -0.5,
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
            color: mediumGrey,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: darkGrey,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: darkGrey,
            height: 1.4,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: mediumGrey,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: white,
        elevation: 2,
        selectedIconTheme: IconThemeData(color: primaryColor),
        unselectedIconTheme: IconThemeData(color: mediumGrey),
        selectedLabelTextStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: TextStyle(color: mediumGrey),
      ),
    );
  }

  // Pre-defined BoxDecorations for modern cards with smooth shadows
  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Bottom navigation pill bar decoration
  static BoxDecoration navBarDecoration() {
    return BoxDecoration(
      color: white,
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
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
