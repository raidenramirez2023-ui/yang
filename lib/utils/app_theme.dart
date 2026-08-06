import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Professional App Theme System
class AppTheme {
  // Deep Forest Green Palette & Warm Gold Accents
  static const Color forestGreen = Color(0xFF16302A); // Sidebar & Top Bar background
  static const Color navColor = Color(0xFF16302A); // Unified Top Bar & Sidebar
  static const Color sidebarDivider = Color(0xFF2B4941);
  static const Color sidebarInactiveText = Color(0xFFDDE5E0);
  static const Color sidebarInactiveIcon = Color(0xFF9DB5AB);
  static const Color sidebarSubtitle = Color(0xFF8FA89E);

  // Primary Accent (Active states, CTAs, primary buttons)
  static const Color warmGold = Color(0xFFE8B84B);
  static const Color primaryColor = Color(0xFFE8B84B); // Primary CTA color
  static const Color primaryDark = Color(0xFF0F221E); // Deep Forest Dark Accent
  static const Color primaryLight = Color(0xFFF3C766); // Light Gold Accent
  static const Color darkBrownText = Color(0xFF412402); // Text on gold accent (never black)

  // Page, Card & Typography Colors
  static const Color backgroundColor = Color(0xFFF7F3EA); // Warm off-white (customer side)
  static const Color adminBackground = Color(0xFFF1F5F9); // Clean slate grey (admin side)
  static const Color white = Color(0xFFFFFFFF); // Card background
  static const Color cardBorder = Color(0xFFE5E0D2); // Light warm gray border
  static const Color darkGrey = Color(0xFF2C2C2A); // Near-black warm gray body text
  static const Color mediumGrey = Color(0xFF8FA89E); // Muted secondary text
  static const Color lightGrey = Color(0xFFE5E0D2); // Light warm gray

  // Category Tag & Price Badge Tokens
  static const Color categoryTagText = Color(0xFF993C1D); // Rust/coral
  static const Color priceBadgeBg = Color(0xFF16302A); // Deep forest green
  static const Color priceBadgeText = Color(0xFFF5F1E6); // Off-white

  // Alert Badge (Strictly reserved for notifications/alerts)
  static const Color errorRed = Color(0xFFFF3B30);

  // Status & Utility Colors
  static const Color successGreen = Color(0xFF34C759);
  static const Color warningOrange = Color(0xFFFF9500);
  static const Color infoBlue = Color(0xFF007AFF);

  // Accent Gradients
  static LinearGradient get goldGradient => const LinearGradient(
    colors: [Color(0xFFF3C766), Color(0xFFE8B84B), Color(0xFFD6A232)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get primaryGradient => goldGradient;

  // Consistent section heading style
  static const TextStyle sectionHeaderStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: darkGrey,
    letterSpacing: -0.3,
  );

  // Spacing helper — returns a vertical SizedBox
  static SizedBox gap(double height) => SizedBox(height: height);

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
              return primaryColor.withOpacity(0.04);
            }
            if (states.contains(WidgetState.pressed)) {
              return primaryColor.withOpacity(0.12);
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
              return primaryColor.withOpacity(0.04);
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

  // Accent & Dashboard Status Colors (Consistent with Admin side)
  static const Color regularOrderBlue = Color(0xFF1E88E5);
  static const Color advanceOrderGreen = Color(0xFF2E7D32);
  static const Color reservationPurple = Color(0xFF7B1FA2);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color goldenAmber = Color(0xFFFFB300);

  // Soft Food-App Card & Shadow Styles
  static BoxDecoration foodCardDecoration({bool isHovered = false}) {
    return BoxDecoration(
      color: white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isHovered ? 0.08 : 0.04),
          blurRadius: isHovered ? 24 : 16,
          offset: Offset(0, isHovered ? 8 : 4),
          spreadRadius: isHovered ? 2 : 0,
        ),
      ],
    );
  }

  // Floating CTA bar / Bottom sheet container decoration
  static BoxDecoration floatingBarDecoration() {
    return BoxDecoration(
      color: white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withOpacity(0.15),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Pre-defined BoxDecorations for modern cards with smooth shadows
  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
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
          color: primaryColor.withOpacity(0.12),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
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
  static const double radius2Xl = 24;
}

