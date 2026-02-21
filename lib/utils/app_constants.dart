class AppConstants {
  // App Info
  static const String appName = 'Yang Chow Restaurant Management System';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String usersCollection = 'users';

  // Routes
  static const String loginRoute = '/';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String adminDashboardRoute = '/dashboard';
  static const String staffDashboardRoute = '/staff-dashboard';

  // User Roles
  static const String adminRole = 'Admin';
  static const String staffRole = 'Staff';

  // Animation Durations
  static const Duration logoAnimationDuration = Duration(seconds: 2);
  static const Duration navigationDelay = Duration(milliseconds: 500);

  // Breakpoints
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1024;

  // Asset Paths
  static const String logoPath = 'assets/images/ycplogo.png';
  static const String logoJpgPath = 'assets/images/logo.jpg';

  // Error Messages
  static const String emptyFieldsError = 'Please enter email and password';
  static const String invalidEmailError = 'Please enter a valid email address';
  static const String userNotFoundError = 'User not found in database';
  static const String invalidRoleError = 'Invalid role. You are registered as';
  static const String loginSuccessMessage = 'Login successful as';
  static const String generalErrorMessage = 'An error occurred:';

  // UI Text
  static const String secureLoginPortal = 'Secure Login Portal';
  static const String restaurantManagementSystem = 'Restaurant Management System';
  static const String staffPOSSystem = 'Staff POS System';
  static const String forgotPassword = 'Forgot Password?';
  static const String signIn = 'Sign In';
  static const String logout = 'Logout';
  static const String cancel = 'Cancel';
  static const String areYouSureLogout = 'Are you sure you want to logout?';
}
