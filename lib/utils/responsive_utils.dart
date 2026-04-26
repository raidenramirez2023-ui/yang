import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Responsive breakpoints and utilities
class ResponsiveUtils {
  // Modern standard breakpoints
  static const double mobileBreakpoint = 768; // Below 768 -> Mobile
  static const double tabletBreakpoint = 1024; // 768 to 1023 -> Tablet

  // Maximum content widths to prevent extreme stretching on large monitors
  static const double maxDesktopWidth = 1440;
  static const double maxContentWidth = 1200;

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Check if running on web
  static bool isWeb() {
    return kIsWeb;
  }

  /// Check if should use drawer (mobile or small web)
  static bool shouldUseDrawer(BuildContext context) {
    return !isDesktop(context);
  }

  /// Retrieve the maximum safe content width wrapper
  static double getMaxContentWidth() {
    return maxContentWidth;
  }

  /// Get responsive font size
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return mobile;
    } else if (width < tabletBreakpoint) {
      return tablet;
    } else {
      return desktop;
    }
  }

  /// Get responsive icon size
  static double getResponsiveIconSize(
    BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return mobile ?? 20;
    } else if (width < tabletBreakpoint) {
      return tablet ?? 24;
    } else {
      return desktop ?? 28;
    }
  }

  /// Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return const EdgeInsets.all(16);
    } else if (width < tabletBreakpoint) {
      return const EdgeInsets.all(20);
    } else {
      return const EdgeInsets.all(24);
    }
  }

  /// Get responsive margin
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return const EdgeInsets.all(16);
    } else if (width < tabletBreakpoint) {
      return const EdgeInsets.all(20);
    } else {
      return const EdgeInsets.all(24);
    }
  }

  /// Get responsive card padding
  static EdgeInsets getResponsiveCardPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return const EdgeInsets.all(16);
    } else if (width < tabletBreakpoint) {
      return const EdgeInsets.all(20);
    } else {
      return const EdgeInsets.all(24); // Give breathing room on desktop
    }
  }

  /// Get responsive vertical space
  static SizedBox verticalSpace(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    return SizedBox(
      height: getResponsiveFontSize(
        context,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      ),
    );
  }

  /// Get responsive horizontal space
  static SizedBox horizontalSpace(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    return SizedBox(
      width: getResponsiveFontSize(
        context,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      ),
    );
  }

  /// Get responsive border radius
  static double getResponsiveBorderRadius(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return 12; // Adjusted for modern 12-16px aesthetic
    } else if (width < tabletBreakpoint) {
      return 16;
    } else {
      return 16;
    }
  }

  /// Get responsive card elevation
  static double getResponsiveCardElevation(BuildContext context) {
    // Relying more on shadows or subtle colors rather than aggressive elevation
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return 0; 
    } else if (width < tabletBreakpoint) {
      return 0;
    } else {
      return 0;
    }
  }

  /// Get responsive button height
  static double getResponsiveButtonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Human Interface Guidelines: 44px min hit target
    if (width < mobileBreakpoint) {
      return 48; // minimum touch target is larger on mobile
    } else if (width < tabletBreakpoint) {
      return 48;
    } else {
      return 52;
    }
  }

  /// Get responsive dialog max width
  static double getResponsiveDialogMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return width * 0.95;
    } else if (width < tabletBreakpoint) {
      return 500;
    } else {
      return 600;
    }
  }
}
