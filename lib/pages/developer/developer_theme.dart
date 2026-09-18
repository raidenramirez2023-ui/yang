import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeveloperTheme {
  // Dark Slate & Cyber IT Palette
  static const Color bgDark = Color(0xFF0B0F17);
  static const Color bgSurface = Color(0xFF131B2A);
  static const Color bgCard = Color(0xFF1A2333);
  static const Color bgCardHover = Color(0xFF222F45);
  static const Color borderSubtle = Color(0xFF26354D);
  static const Color borderLight = Color(0xFF334566);

  // Accents
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentPurple = Color(0xFF8B5CF6);

  // Text Colors
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Card Decoration
  static BoxDecoration cardDecoration({
    Color? color,
    Color? borderColor,
    double borderRadius = 12,
    bool glow = false,
    Color glowColor = accentIndigo,
  }) {
    return BoxDecoration(
      color: color ?? bgCard,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? borderSubtle,
        width: 1.0,
      ),
      boxShadow: glow
          ? [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.15),
                blurRadius: 16,
                spreadRadius: 2,
              )
            ]
          : [
              const BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
    );
  }

  // Monospaced Code Text
  static TextStyle monoText({
    double fontSize = 13,
    Color color = textPrimary,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }

  // Section Header
  static TextStyle headingLarge({Color color = textPrimary}) {
    return GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: -0.5,
    );
  }

  static TextStyle headingMedium({Color color = textPrimary}) {
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  static TextStyle bodySmall({Color color = textSecondary}) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: color,
    );
  }
}
