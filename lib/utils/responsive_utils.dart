import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Responsive breakpoints and utilities
class ResponsiveUtils {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;

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

  /// Check if should use drawer (web mobile)
  static bool shouldUseDrawer(BuildContext context) {
    return isWeb() && isMobile(context);
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
      return const EdgeInsets.all(12);
    } else if (width < tabletBreakpoint) {
      return const EdgeInsets.all(16);
    } else {
      return const EdgeInsets.all(20);
    }
  }

  /// Get responsive card padding
  static EdgeInsets getResponsiveCardPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return const EdgeInsets.all(12);
    } else if (width < tabletBreakpoint) {
      return const EdgeInsets.all(16);
    } else {
      return const EdgeInsets.all(20);
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
      return 8;
    } else if (width < tabletBreakpoint) {
      return 12;
    } else {
      return 16;
    }
  }

  /// Get responsive card elevation
  static double getResponsiveCardElevation(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return 1;
    } else if (width < tabletBreakpoint) {
      return 2;
    } else {
      return 4;
    }
  }

  /// Get responsive button height
  static double getResponsiveButtonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return 36;
    } else if (width < tabletBreakpoint) {
      return 40;
    } else {
      return 48;
    }
  }

  /// Get responsive dialog max width
  static double getResponsiveDialogMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return width * 0.9;
    } else if (width < tabletBreakpoint) {
      return 400;
    } else {
      return 500;
    }
  }
}
