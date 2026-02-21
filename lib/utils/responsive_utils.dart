import 'package:flutter/material.dart';

/// Responsive breakpoints and utilities
class ResponsiveUtils {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;

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

  /// Get device type for enum usage
  static String getDeviceType(BuildContext context) {
    if (isMobile(context)) {
      return 'mobile';
    } else if (isTablet(context)) {
      return 'tablet';
    } else {
      return 'desktop';
    }
  }
}
