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
  static const String restaurantManagementSystem =
      'Restaurant Management System';
  static const String staffPOSSystem = 'Staff POS System';
  static const String forgotPassword = 'Forgot Password?';
  static const String signIn = 'Sign In';
  static const String logout = 'Logout';
  static const String cancel = 'Cancel';
  static const String areYouSureLogout = 'Are you sure you want to logout?';

  // ==================== NEW: RESERVATION ENHANCEMENTS ====================

  // Reservation constraints (defaults - can be overridden from app_settings)
  static const int defaultMinGuestCount = 2;
  static const int defaultMaxGuestCount = 500;
  static const int defaultMinReservationDaysAhead = 4;
  static const int defaultMaxReservationDaysAhead = 365;

  // Operating hours (24-hour format) - defaults
  static const int defaultOperatingHoursStart = 10; // 10 AM
  static const int defaultOperatingHoursEnd = 22; // 10 PM

  // Duration options
  static const List<String> defaultBaseDurations = ['2 Hours', '3 Hours'];
  static const List<String> defaultExtraTimeOptions = [
    '30 Minutes',
    '1 Hour',
    '1 Hour 30 Minutes',
    '2 Hours',
  ];

  // Refund policy - defaults
  static const int defaultRefundPolicyDays =
      7; // 100% refund if cancelled 7+ days before
  static const int defaultRefundPercentageWithinWindow =
      50; // 50% refund if within window

  // Feature flags - defaults
  static const bool defaultEnableSpecialRequests = true;
  static const bool defaultEnableEmailNotifications = true;

  // Event types
  static const List<String> eventTypes = [
    'Birthday Party',
    'Wedding',
    'Meeting',
    'Anniversary',
    'Corporate Event',
    'Family Gathering',
  ];

  // Cancellation reasons
  static const List<String> cancellationReasons = [
    'Change of plans',
    'Emergency',
    'Found alternative venue',
    'Budget constraints',
    'Date conflict',
    'Health reasons',
  ];

  // Email notification types
  static const String emailTypeConfirmation = 'confirmation';
  static const String emailTypeApproved = 'approved';
  static const String emailTypeRejected = 'rejected';
  static const String emailTypeCancelled = 'cancelled';
  static const String emailTypeReminder = 'reminder';
  static const String emailTypeReviewRequest = 'review_request';
  static const String emailTypeRefundProcessed = 'refund_processed';

  // Refund status values
  static const String refundStatusNone = 'none';
  static const String refundStatusPending = 'pending';
  static const String refundStatusCompleted = 'completed';
  static const String refundStatusFailed = 'failed';

  // Special request categories
  static const List<String> dietaryRestrictions = [
    'Vegetarian',
    'Vegan',
    'Gluten-Free',
    'Dairy-Free',
    'Nut Allergy',
    'Shellfish Allergy',
    'Halal',
    'Kosher',
    'No Pork',
    'Other',
  ];

  // Accessibility needs
  static const List<String> accessibilityNeeds = [
    'Wheelchair Access',
    'Parking Assistance',
    'High Chair',
    'Booster Seat',
    'Hearing Assistance',
    'Visual Assistance',
    'Other',
  ];
}
