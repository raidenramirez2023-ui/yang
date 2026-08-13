import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Professional App Theme System — YCPRMS
/// Palette: Deep Emerald (primary/nav) + Muted Gold (accent)
class AppTheme {
  // Deep Emerald Palette & Warm Gold Accents
  static const Color forestGreen = Color(0xFF14332E); // Sidebar & Top Bar background (Deep Emerald)
  static const Color navColor = Color(0xFF14332E); // Unified Top Bar & Sidebar (Deep Emerald)
  static const Color sidebarDivider = Color(0xFF0D2521);
  static const Color sidebarInactiveText = Color(0xFFFFFFFF); // White
  static const Color sidebarInactiveIcon = Color(0xFFFFFFFF); // White
  static const Color sidebarSubtitle = Color(0xFFC7D6D3);
  static const Color activeSidebarItemBackground = Color(0xFF1E4A42); // Active sidebar item background
  static const Color activeSidebarAccent = Color(0xFFD9A441); // Active sidebar indicator/accent (Muted Gold)

  // Admin Side Exact Color Hex Codes — Deep Emerald Scheme
  static const Color adminSidebarBackground = Color(0xFF14332E); // Sidebar Background (Deep Emerald)
  static const Color adminActiveSidebarBackground = Color(0xFF1E4A42); // Active Sidebar Item Background
  static const Color adminActiveSidebarAccent = Color(0xFFD9A441); // Active Sidebar Highlight/Text (Muted Gold)
  static const Color adminSidebarInactiveText = Color(0xFFFFFFFF); // Inactive Text/Icons (White)
  static const Color adminSidebarInactiveIcon = Color(0xFFFFFFFF); // Inactive Icon Color (White)
  static const Color adminMainBackground = Color(0xFFF1F5F9); // Main Background (Crisp Light Slate)
  static const Color adminCardBackground = Color(0xFFFFFFFF); // Card Item Backgrounds (Pure Crisp White)
  static const Color adminPricingBackground = Color(0xFFF8FAFC); // Pricing Section Background (Subtle Slate)
  static const Color adminPrimaryAccent = Color(0xFFC9922E); // Primary Accent Color (Gold Button)
  static const Color adminPrimaryText = Color(0xFF0F172A); // Primary Text Color (Crisp Slate Charcoal)
  static const Color adminSecondaryText = Color(0xFF475569); // Secondary Text Color (Slate Gray)
  static const Color adminFeaturedMetricCard = Color(0xFF1E4A42); // Featured Metric Card (Emerald Gradient base)
  static const Color adminProgressBar1 = Color(0xFF2E7D32); // Progress Bar 1 (Forest Green)
  static const Color adminProgressBar2 = Color(0xFFD9A441); // Progress Bar 2 (Muted Gold)
  static const Color adminConfirmedEventsBg = Color(0xFFE8F5E9); // Confirmed Events Card BG
  static const Color adminConfirmedEventsBorder = Color(0xFF2E7D32); // Confirmed Events Border/Text
  static const Color adminRevenueGraphLine = Color(0xFF14332E); // Revenue Analytics Graph Line (Deep Emerald)
  static const Color adminChatButton = Color(0xFFC9922E); // Chat Button (Gold)
  static const Color adminChatBadge = Color(0xFFDC2626); // Chat Badge (Professional Red)

  // Primary Accent (Active states, CTAs, primary buttons)
  static const Color warmGold = Color(0xFFD9A441);
  static const Color primaryColor = Color(0xFFC9922E); // Primary CTA color
  static const Color primaryDark = Color(0xFF0F221E); // Deep Forest Dark Accent
  static const Color primaryLight = Color(0xFFE6C374); // Light Gold Accent
  static const Color darkBrownText = Color(0xFF412402); // Text on gold accent (never black)

  // Page, Card & Typography Colors
  static const Color backgroundColor = Color(0xFFF7F3EA); // Warm off-white (customer side)
  static const Color adminBackground = Color(0xFFF1F5F9); // Admin side main background (Crisp Light Slate)
  static const Color white = Color(0xFFFFFFFF); // Pure White Card background
  static const Color cardBorder = Color(0xFFE2E8F0); // Light crisp slate gray border
  static const Color darkGrey = Color(0xFF1E293B); // Crisp dark slate body text
  static const Color mediumGrey = Color(0xFF64748B); // Muted slate secondary text
  static const Color lightGrey = Color(0xFFF1F5F9); // Light crisp slate gray

  // Admin-specific aliases for consistency
  static const Color adminTextPrimary = adminPrimaryText;
  static const Color adminTextSecondary = adminSecondaryText;
  static const Color adminCardItemBackground = adminCardBackground;
  static const Color adminBackgroundMain = adminMainBackground;

  // Category Tag & Price Badge Tokens
  static const Color categoryTagText = Color(0xFFB45309); // Warm terracotta
  static const Color priceBadgeBg = Color(0xFF14332E); // Deep emerald
  static const Color priceBadgeText = Color(0xFFF5F1E6); // Off-white

  // Alert Badge (Strictly reserved for notifications/alerts)
  static const Color errorRed = Color(0xFFDC2626); // Professional red, distinct from brand palette

  // Status & Utility Colors
  static const Color successGreen = Color(0xFF34C759);
  static const Color warningOrange = Color(0xFFFF9500);
  static const Color infoBlue = Color(0xFF007AFF);

  // Accent Gradients
  static LinearGradient get goldGradient => const LinearGradient(
    colors: [Color(0xFFE6C374), Color(0xFFD9A441), Color(0xFFC9922E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Admin-specific gradient
  static LinearGradient get adminGradient => const LinearGradient(
    colors: [Color(0xFFE6C374), Color(0xFFD9A441)],
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

  // Accent & Dashboard Status Colors (Consistent with Admin side)
  static const Color regularOrderBlue = Color(0xFF1E88E5);
  static const Color advanceOrderGreen = Color(0xFF2E7D32);
  static const Color reservationPurple = Color(0xFF7B1FA2);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color goldenAmber = Color(0xFFD9A441);

  // Soft Food-App Card & Shadow Styles
  static BoxDecoration foodCardDecoration({bool isHovered = false}) {
    return BoxDecoration(
      color: white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isHovered ? 0.08 : 0.04),
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
          color: primaryColor.withValues(alpha: 0.15),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
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
  static const double radius2Xl = 24;
}