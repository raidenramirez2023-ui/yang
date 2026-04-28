import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:yang_chow/utils/app_theme.dart';

import 'package:yang_chow/utils/app_constants.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/pages/customer/edit_profile_page.dart';

import 'package:yang_chow/pages/customer/customer_chat_page.dart';

import 'package:yang_chow/pages/customer/customer_reviews_page.dart';
import 'package:yang_chow/pages/customer/menu_selection_page.dart';

import 'package:yang_chow/pages/customer/transactions_page.dart';
import 'package:yang_chow/pages/customer/gcash_payment_page.dart';

import 'package:yang_chow/services/notification_service.dart';

import 'package:yang_chow/services/app_settings_service.dart';

import 'package:yang_chow/services/reservation_service.dart';

import 'package:yang_chow/services/menu_service.dart';

import 'package:yang_chow/services/menu_reservation_service.dart';

import 'package:intl/intl.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:yang_chow/models/menu_item.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> with SingleTickerProviderStateMixin {

  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

  int _selectedIndex = 0;

  bool _isLoading = false;

  final ReservationService _reservationService = ReservationService();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '58922100698-jmttb6okfltmpcco2f2rrh8rmppappk6.apps.googleusercontent.com' // Web Client ID
        : '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com', // Android Client ID
  );

  List<Map<String, dynamic>> customerReservations = [];
  bool _isEligibleForReview = false;
  Map<String, dynamic>? _customerReview;

  Stream<List<Map<String, dynamic>>>? _notificationsStream;

  String? _lastSeenNotificationId;

  // Menu selection state

  Map<String, int> _selectedMenuItems = {};

  final MenuReservationService _menuReservationService =
      MenuReservationService();

  // Services

  late AppSettingsService _appSettings;

  // Configuration values (will be loaded from app_settings)

  int _minGuestCount = AppConstants.defaultMinGuestCount;

  int _maxGuestCount = AppConstants.defaultMaxGuestCount;

  int _operatingHoursStart = AppConstants.defaultOperatingHoursStart;

  int _operatingHoursEnd = AppConstants.defaultOperatingHoursEnd;

  late List<String> _baseDurations;

  late List<String> _extraTimeOptions;

  bool _enableSpecialRequests = AppConstants.defaultEnableSpecialRequests;

  // Form controllers

  final TextEditingController _eventController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();

  final TextEditingController _durationController = TextEditingController();

  final TextEditingController _guestsController = TextEditingController();

  final TextEditingController _specialRequestsController =
      TextEditingController();

  // Carousel state
  late PageController _heroPageController;
  Timer? _heroTimer;
  int _currentHeroPage = 0;

  // New state variables for form improvements

  String? _selectedEventType;

  String? _selectedBaseDuration;

  bool _addExtraTime = false;

  String? _selectedExtraTime;

  final List<String> _eventTypes = AppConstants.eventTypes;
  String _reservationType = 'Event Place';
  String _advanceOrderType = 'Dine In';

  @override
  void initState() {
    super.initState();

    _appSettings = AppSettingsService();

    _loadConfigurationSettings();
    _loadCustomerReservations();
    _loadReviewEligibility();

    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser != null) {
      _notificationsStream =
          NotificationService.getCustomerAdminNotificationsStream(
            currentUser.email!,
          );
    }

    _heroPageController = PageController(initialPage: 0);
    _startHeroTimer();
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_heroPageController.hasClients) {
        final Map<String, List<MenuItem>> allMenu = MenuService.getMenu();
        final List<MenuItem> items = _getTopSellingItems(allMenu);
        
        if (_currentHeroPage < items.length - 1) {
          _currentHeroPage++;
        } else {
          _currentHeroPage = 0;
        }
        
        _heroPageController.animateToPage(
          _currentHeroPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  Future<void> _loadReviewEligibility() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final isEligible = await _reservationService.isEligibleForReview(currentUser.email!);
      Map<String, dynamic>? review;
      if (isEligible) {
        review = await _reservationService.getCustomerReview(currentUser.email!);
      }

      if (mounted) {
        setState(() {
          _isEligibleForReview = isEligible;
          _customerReview = review;
        });
      }
    } catch (e) {
      debugPrint('Error loading review eligibility: $e');
    }
  }

  /// Load configuration settings from app_settings table

  void _loadConfigurationSettings() {
    _minGuestCount = _appSettings.getMinGuestCount();

    _maxGuestCount = _appSettings.getMaxGuestCount();

    _operatingHoursStart = _appSettings.getOperatingHoursStart();

    _operatingHoursEnd = _appSettings.getOperatingHoursEnd();

    _baseDurations = _appSettings.getBaseDurations();

    _extraTimeOptions = _appSettings.getExtraTimeOptions();

    _enableSpecialRequests = _appSettings.isSpecialRequestsEnabled();
  }

  Future<void> _loadCustomerReservations() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (currentUser == null) return;

      // Fetch from both tables in parallel
      final results = await Future.wait([
        Supabase.instance.client
            .from('reservations')
            .select('*')
            .eq('customer_email', currentUser.email!)
            .order('created_at', ascending: false),
        Supabase.instance.client
            .from('advance_orders')
            .select('*')
            .eq('customer_email', currentUser.email!)
            .order('created_at', ascending: false),
      ]);

      final reservations = List<Map<String, dynamic>>.from(results[0]).map((r) {
        return {...r, '_db_table': 'reservations'};
      }).toList();

      final advanceOrders = List<Map<String, dynamic>>.from(results[1]).map((o) {
        return {
          ...o,
          'event_type': 'Advance Order (${o['order_type']})',
          'event_date': o['order_date'],
          'start_time': o['order_time'],
          'duration_hours': 0,
          '_db_table': 'advance_orders',
        };
      }).toList();

      final combined = [...reservations, ...advanceOrders];

      // Sort combined results by created_at descending
      combined.sort((a, b) {
        final aTime = DateTime.parse(a['created_at'] ?? DateTime.now().toIso8601String());
        final bTime = DateTime.parse(b['created_at'] ?? DateTime.now().toIso8601String());
        return bTime.compareTo(aTime);
      });

      setState(() {
        customerReservations = combined;
      });
    } catch (e) {
      debugPrint('Error loading customer records: $e');
    }
  }

  @override
  void dispose() {
    _heroPageController.dispose();
    _heroTimer?.cancel();
    _eventController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _durationController.dispose();
    _guestsController.dispose();
    _specialRequestsController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _loadCustomerReservations(),
      _loadReviewEligibility(),
    ]);
    _loadConfigurationSettings();
    if (mounted) setState(() {});
  }

  String _getUserDisplayName() {
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;

    if (metadata != null) {
      if (metadata['firstname'] != null && metadata['lastname'] != null) {
        return '${metadata['firstname']} ${metadata['lastname']}';
      }

      final fullName = metadata['full_name']?.replaceAll('User', '');

      if (fullName != null && fullName.isNotEmpty) return fullName;

      final name = metadata['name']?.replaceAll('User', '');

      if (name != null && name.isNotEmpty) return name;
    }

    return 'User';
  }

  void _navigateToMenuSelection() async {
    final guestCount = int.tryParse(_guestsController.text.trim()) ?? 1;

    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (context) => MenuSelectionPage(
          reservationType: _reservationType,

          guestCount: guestCount,

          initialSelection: _selectedMenuItems,

          onMenuSelected: (selectedItems) {
            setState(() {
              _selectedMenuItems = selectedItems;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: isDesktop ? Colors.white : AppTheme.navColor,
        systemNavigationBarIconBrightness: isDesktop ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDesktop ? AppTheme.backgroundColor : AppTheme.navColor,

        appBar: isDesktop
            ? null
            : _buildDashboardAppBar(_getAppBarTitle()),

        body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Home';

      case 1:
        return 'Reservation';

      case 2:
        return 'Chat';

      case 3:
        return 'Quotations';

      case 4:
        return 'Activity';

      case 5:
        return 'Profile';

      default:
        return 'Home';
    }
  }

  PreferredSizeWidget _buildDashboardAppBar(String title) {
    return AppBar(
      backgroundColor: AppTheme.navColor,

      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,

      automaticallyImplyLeading: false,

      centerTitle: true,

      title: Text(
        title,
        style: GoogleFonts.lora(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),

      actions: [
        _buildNotificationIcon(),
        IconButton(
          icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
          onPressed: () => setState(() => _selectedIndex = 5),
          tooltip: 'Account',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNotificationIcon() {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notificationsStream,

      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];

        final newestId = notifications.isNotEmpty
            ? notifications.first['id']?.toString()
            : null;

        // Show dot if:

        // 1. There are unread items in the list

        // 2. The newest item's ID is different from what we last "saw" (cleared)

        final hasUnread = notifications.any((n) => !n['is_read']);

        final isTrulyNew = newestId != _lastSeenNotificationId;

        final showDot = hasUnread && isTrulyNew;

        return Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,

                color: Colors.white,
              ),

              onPressed: () {
                if (notifications.isNotEmpty) {
                  final currentNewestId = notifications.first['id']?.toString();

                  setState(() => _lastSeenNotificationId = currentNewestId);
                }

                _showNotificationsDialog(notifications);
              },

              tooltip: 'Notifications',
            ),

            if (showDot)
              Positioned(
                right: 12,

                top: 12,

                child: Container(
                  width: 10,

                  height: 10,

                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,

                    shape: BoxShape.circle,

                    border: Border.all(
                      color: AppTheme.backgroundColor,

                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsDialog(List<Map<String, dynamic>> notifications) {
    if (notifications.isNotEmpty) {
      final unreadIds = notifications
          .where((n) => !n['is_read'])
          .map((n) => n['id'].toString())
          .toList();

      if (unreadIds.isNotEmpty) {
        NotificationService.markVisibleAsRead(unreadIds);
      }
    }

    showDialog(
      context: context,

      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        title: const Row(
          children: [
            Icon(Icons.notifications_rounded, color: AppTheme.primaryColor),

            SizedBox(width: 12),

            Text('Notifications'),
          ],
        ),

        content: SizedBox(
          width: double.maxFinite,

          child: notifications.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    const Divider(),

                    const SizedBox(height: 16),

                    Icon(
                      Icons.notifications_off_outlined,

                      size: 64,

                      color: Colors.grey.shade400,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'No notifications',

                      style: TextStyle(
                        fontWeight: FontWeight.bold,

                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'We\'ll let you know when there\'s activity on your reservations.',

                      textAlign: TextAlign.center,

                      style: TextStyle(color: Colors.grey.shade600),
                    ),

                    const SizedBox(height: 16),
                  ],
                )
              : ListView.separated(
                  shrinkWrap: true,

                  itemCount: notifications.length,

                  separatorBuilder: (context, index) => const Divider(),

                  itemBuilder: (context, index) {
                    final n = notifications[index];

                    final date = DateTime.parse(n['created_at']).toLocal();

                    final timeStr = DateFormat('MMM d, h:mm a').format(date);

                    IconData icon;

                    Color color;

                    switch (n['action_type']) {
                      case 'created':
                        icon = Icons.add_circle_outline;

                        color = AppTheme.infoBlue;

                        break;

                      case 'approved':
                      case 'completed':
                        icon = Icons.check_circle_outline;

                        color = AppTheme.successGreen;

                        break;

                      case 'cancelled':
                      case 'rejected':
                      case 'deleted':
                        icon = Icons.highlight_off;

                        color = AppTheme.errorRed;

                        break;

                      case 'updated':
                        icon = Icons.update;

                        color = AppTheme.warningOrange;

                        break;

                      case 'paid':
                        icon = Icons.payment;

                        color = AppTheme.successGreen;

                        break;

                      default:
                        icon = Icons.notifications_none;

                        color = AppTheme.mediumGrey;
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),

                        child: Icon(icon, color: color, size: 20),
                      ),

                      title: Text(
                        _getNotificationTitle(n),

                        style: const TextStyle(
                          fontWeight: FontWeight.bold,

                          fontSize: 14,
                        ),
                      ),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            _getNotificationSubtitle(n),

                            style: const TextStyle(fontSize: 12),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            timeStr,

                            style: TextStyle(
                              fontSize: 10,

                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),

            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Generate role-specific and context-aware notification subtitle

  String _getNotificationSubtitle(Map<String, dynamic> n) {
    final isForAdmin = n['is_for_admin'] ?? false;

    final eventType = n['event_type'];

    final eventDate = n['event_date'];

    final customerEmail = n['customer_email'];

    final guestCount = n['guest_count'];

    final startTime = n['start_time'];

    // For admin notifications - show customer and reservation details

    if (isForAdmin) {
      String details = "";

      if (customerEmail != null) {
        details += "Customer: $customerEmail";
      }

      if (eventType != null) {
        details += details.isEmpty ? eventType : " • $eventType";
      }

      if (eventDate != null) {
        details += details.isEmpty ? "Date: $eventDate" : " • $eventDate";
      }

      if (guestCount != null) {
        details += " • $guestCount guests";
      }

      return details.isEmpty ? "Reservation activity" : details;
    }

    // For customer notifications - show event and time info

    if (eventType != null && eventDate != null) {
      String details = "$eventType on $eventDate";

      if (startTime != null) {
        details += " at $startTime";
      }

      if (guestCount != null) {
        details += " • $guestCount guests";
      }

      return details;
    }

    return eventType ?? "Activity on your reservation";
  }

  String _getNotificationTitle(Map<String, dynamic> n) {
    final isForAdmin = n['is_for_admin'] ?? false;

    final actorName = n['actor_name'] ?? 'User';

    final actionType = n['action_type'];

    // For admin notifications - include who took the action

    if (isForAdmin) {
      switch (actionType) {
        case 'created':
          return 'New Reservation from $actorName';

        case 'approved':
          return 'Reservation Approved by $actorName';

        case 'cancelled':
          return 'Reservation Cancelled by $actorName';

        case 'deleted':
          return 'Reservation Deleted by $actorName';

        case 'rejected':
          return 'Reservation Rejected by $actorName';

        case 'updated':
          return 'Reservation Updated by $actorName';

        case 'paid':
          return 'Payment Confirmed from $actorName';

        default:
          return 'Activity from $actorName';
      }
    }

    // For customer notifications - focus on the action

    switch (actionType) {
      case 'created':
        return 'Reservation Received';

      case 'approved':
        return 'Your Reservation is Approved';

      case 'cancelled':
        return 'Reservation Cancelled';

      case 'deleted':
        return 'Reservation Deleted';

      case 'rejected':
        return 'Reservation Could Not Be Approved';

      case 'updated':
        return 'Reservation Updated';

      case 'paid':
        return 'Payment Confirmed';

      case 'completed':
        return 'Reservation Completed';

      default:
        return 'Notification';
    }
  }

  // =========================

  // DESKTOP LAYOUT (DARK SIDEBAR)

  // =========================

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Vivid Red Sidebar
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: AppTheme.navColor,
            border: Border(
              right: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
            ),
          ),
          child: Column(
            children: [
              // Logo Section
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/ycplogo.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Yang Chow',
                      style: GoogleFonts.lora(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 16),

              // Navigation Items
              ...List.generate(5, (index) {
                final icons = [
                  Icons.home_rounded,
                  Icons.event_available_rounded,
                  Icons.chat_bubble_rounded,
                  Icons.monetization_on_rounded,
                  Icons.assignment_rounded,
                ];

                final labels = [
                  'Home',
                  'Reservations',
                  'Chat',
                  'Quotations',
                  'Activity',
                ];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _selectedIndex == index
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        icons[index],
                        color: _selectedIndex == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.65),
                      ),
                      title: Text(
                        labels[index],
                        style: TextStyle(
                          color: _selectedIndex == index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.65),
                          fontWeight: _selectedIndex == index
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedIndex = index);
                      },
                      hoverColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                );
              }),

              const Spacer(),
            ],
          ),
        ),

        // Main Content
        Expanded(
          child: Container(
            color: AppTheme.backgroundColor,

            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),

                  color: AppTheme.navColor,

                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Centered Title
                      Text(
                        _getAppBarTitle(),
                        style: GoogleFonts.lora(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      
                      // Actions on right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildNotificationIcon(),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => setState(() => _selectedIndex = 5),
                            icon: const Icon(
                              Icons.person_outline_rounded,
                              color: Colors.white,
                            ),
                            tooltip: 'Account',
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content Area
                Expanded(
                  child: Padding(
                    padding: ResponsiveUtils.getResponsivePadding(context),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: ResponsiveUtils.getMaxContentWidth(),
                        ),
                        child: _buildContent(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MOBILE LAYOUT (BOTTOM NAV)

  // =========================

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Main Content
        Expanded(
          child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: AppTheme.primaryColor,
              child: Padding(
                padding: EdgeInsets.zero,
                child: _buildContent(),
              ),
            ),
        ),

        // Modern Animated Mobile Navigation at Bottom (Floating Icons Design)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: AppTheme.navColor,
          ),
          child: Container(
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMobileNavItem(0, Icons.home_rounded, 'Home'),
                  _buildMobileNavItem(1, Icons.event_available_rounded, 'Reserve'),
                  _buildMobileNavItem(2, Icons.chat_bubble_rounded, 'Chat'),
                  _buildMobileNavItem(3, Icons.monetization_on_rounded, 'Price'),
                  _buildMobileNavItem(4, Icons.assignment_rounded, 'Activity'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                size: 24,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.only(top: 8), // Reduced from 12
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _getSectionWidget(),
        ),
      ),
    );
  }

  Widget _getSectionWidget() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeSection();

      case 1:
        return _buildReservationsSection();

      case 2:
        return CustomerChatPage();

      case 3:
        return _buildQuotationsSection();

      case 4:
        return _buildActivitySection();

      case 5:
        return _buildProfileSection();

      default:
        return _buildHomeSection();
    }
  }

  Widget _buildSubSelectionButton(String label, IconData icon) {
    final isSelected = _advanceOrderType == label;
    return GestureDetector(
      onTap: () => setState(() => _advanceOrderType = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MenuItem> _getTopSellingItems(Map<String, List<MenuItem>> allMenu) {
    final List<MenuItem> flattenedItems = [];
    for (var list in allMenu.values) {
      flattenedItems.addAll(list);
    }
    
    final List<String> topSellingNames = [
      'YangChow 1',
      'YangChow 3',
      'Buttered Chicken',
      'Lechon Macau',
      'Pancit Canton',
      'Yang Chow Fried Rice',
      'Siomai with Shrimp',
      'Sweet and Sour Pork',
      'Broccoli Leaves with Oyster Sauce',
    ];
    
    final List<MenuItem> items = [];
    for (var name in topSellingNames) {
      final found = flattenedItems.where((item) => item.name == name).toList();
      if (found.isNotEmpty) {
        items.add(found.first);
      }
    }
    return items;
  }

  Widget _buildHeroCarousel() {
    final Map<String, List<MenuItem>> allMenu = MenuService.getMenu();
    final List<MenuItem> items = _getTopSellingItems(allMenu);

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: ResponsiveUtils.isDesktop(context) ? 400 : 220,
          child: PageView.builder(
            controller: _heroPageController,
            onPageChanged: (index) => setState(() => _currentHeroPage = index),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return AnimatedBuilder(
                animation: _heroPageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_heroPageController.position.haveDimensions) {
                    value = _heroPageController.page! - index;
                    value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * (ResponsiveUtils.isDesktop(context) ? 400 : 220),
                      width: double.infinity,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildImageWidget(item),
                        // Gradient Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.1),
                                Colors.black.withValues(alpha: 0.8),
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                        // Ad Content
                        Positioned(
                          left: 24,
                          bottom: 24,
                          right: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              const SizedBox(height: 8),
                              Text(
                                item.name,
                                style: GoogleFonts.lora(
                                  color: Colors.white,
                                  fontSize: ResponsiveUtils.isDesktop(context) ? 32 : 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (item.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.description!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: ResponsiveUtils.isDesktop(context) ? 16 : 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: _currentHeroPage == index ? 24 : 6,
              decoration: BoxDecoration(
                color: _currentHeroPage == index ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHomeSection() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Welcome Banner ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: ResponsiveUtils.getResponsivePadding(context),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: ResponsiveUtils.isMobile(context)
                    ? const BorderRadius.vertical(bottom: Radius.circular(20))
                    : BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative circles overlay
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 30,
                    bottom: -30,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  // Banner content
                  Row(
                    children: [
                      Hero(
                        tag: 'user_avatar',
                        child: Container(
                          width: ResponsiveUtils.isMobile(context) ? 60 : 80,
                          height: ResponsiveUtils.isMobile(context) ? 60 : 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                            image: Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'] != null
                                ? DecorationImage(
                                    image: NetworkImage(Supabase.instance.client.auth.currentUser!.userMetadata!['avatar_url']),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'] == null
                              ? Icon(Icons.person_rounded, color: Colors.white, size: ResponsiveUtils.isMobile(context) ? 30 : 40)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, ${_getUserDisplayName()}!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 22, tablet: 26, desktop: 30),
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ready for a premium dining experience?',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Hero Advertising Carousel
          _buildHeroCarousel(),

          const SizedBox(height: 16),

          // ── Products & Pricing menu grid ────────────────────────────────
          _buildIntegratedMenu(),

          // ── Feedback section (conditional) ──────────────────────────────
          if (_isEligibleForReview) ...[
            const SizedBox(height: 16), // Reduced from 24
            _buildFeedbackSection(),
          ],


          const SizedBox(height: 16), // Reduced from 24
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    final hasReview = _customerReview != null;
    final rating = hasReview ? (_customerReview!['rating'] as num?)?.toDouble() ?? 0.0 : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stars_rounded, color: AppTheme.primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasReview ? 'YOUR FEEDBACK' : 'LEAVE A REVIEW',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasReview 
                        ? 'Thank you for sharing your experience!'
                        : 'How was your recent event with us?',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.mediumGrey.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (hasReview) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ...List.generate(5, (index) => Icon(
                        index < rating.floor() ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 20,
                      )),
                      const SizedBox(width: 8),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  if (_customerReview!['review_text'] != null && _customerReview!['review_text'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"${_customerReview!['review_text']}"',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.darkGrey.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CustomerReviewsPage()),
                );
                _loadReviewEligibility(); // Refresh after returning
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: hasReview ? Colors.white : AppTheme.primaryColor,
                foregroundColor: hasReview ? AppTheme.primaryColor : Colors.white,
                side: hasReview ? const BorderSide(color: AppTheme.primaryColor) : null,
                elevation: hasReview ? 0 : 4,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                hasReview ? 'UPDATE YOUR REVIEW' : 'WRITE A REVIEW',
                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Duration _calculateDynamicLeadTime() {
    // Advance orders require at least a 24-hour lead time
    const baseLeadTime = Duration(days: 1);
    
    if (_selectedMenuItems.isEmpty) return baseLeadTime;
    
    int totalItems = _selectedMenuItems.values.fold(0, (sum, qty) => sum + qty);
    int extraMinutes = (totalItems / 5).floor() * 15;
    
    // Add extra time for large orders on top of the 24-hour base
    return baseLeadTime + Duration(minutes: extraMinutes);
  }

  Future<bool> _checkCapacity(DateTime selectedDateTime) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDateTime);
    final timeStr = _startTimeController.text.trim();
    
    try {
      final response = await Supabase.instance.client
          .from('advance_orders')
          .select('id, selected_menu_items')
          .eq('order_date', dateStr)
          .eq('order_time', timeStr)
          .filter('payment_status', 'in', '("paid", "fully_paid")');
          
      final orders = response as List;
      if (orders.length >= 10) return false; // 10 orders per hour limit
      
      int largeOrders = 0;
      for (var order in orders) {
        final items = order['selected_menu_items'] as Map<String, dynamic>? ?? {};
        int count = 0;
        items.values.forEach((qty) => count += (qty as num).toInt());
        if (count > 10) largeOrders++;
      }
      return largeOrders < 3; // 3 large orders per hour limit
    } catch (e) {
      debugPrint('Error checking capacity: $e');
      return true; // Fallback to allow if error
    }
  }

  Future<String?> _validateInventoryStock() async {
    if (_selectedMenuItems.isEmpty) return null;
    try {
      final response = await Supabase.instance.client
          .from('inventory')
          .select('name, quantity');
          
      final inventory = { for (var item in response as List) item['name'].toString() : (item['quantity'] as num?)?.toInt() ?? 0 };
      
      for (var entry in _selectedMenuItems.entries) {
        final itemName = entry.key;
        final requestedQty = entry.value;
        
        if (inventory.containsKey(itemName)) {
          if (inventory[itemName]! < requestedQty) {
            return 'Sorry, we only have ${inventory[itemName]} $itemName in stock.';
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error validating inventory: $e');
      return null; // Fallback to allow if error
    }
  }

  Widget _buildReservationsSection() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24), // Reduced from 24, 32

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ── Section header ──────────────────────────────────────────
            Text(
              _reservationType == 'Event Place' ? 'Reserve Your Space' : 'Advance Order Food',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              _reservationType == 'Event Place' 
                  ? 'Curate your next memorable moment with ease.'
                  : 'Order ahead and have your favorite meals ready for dinein or pickup.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 16), // Reduced from 24

            // Reservation Type Selection
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _reservationType = 'Event Place'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _reservationType == 'Event Place'
                          ? AppTheme.primaryColor
                          : Colors.white,
                      foregroundColor: _reservationType == 'Event Place'
                          ? Colors.white
                          : AppTheme.primaryColor,
                      side: BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                      elevation: _reservationType == 'Event Place' ? 4 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Event Place'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _reservationType = 'Advance Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _reservationType == 'Advance Order'
                          ? AppTheme.primaryColor
                          : Colors.white,
                      foregroundColor: _reservationType == 'Advance Order'
                          ? Colors.white
                          : AppTheme.primaryColor,
                      side: BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                      elevation: _reservationType == 'Advance Order' ? 4 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Advance Order'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16), // Reduced from 24

            // Sub-selection for Advance Order (Dine In / Pick Up)
            if (_reservationType == 'Advance Order') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSubSelectionButton('Dine In', Icons.restaurant_rounded),
                  const SizedBox(width: 16),
                  _buildSubSelectionButton('Pick Up', Icons.shopping_bag_rounded),
                ],
              ),
              const SizedBox(height: 16), // Reduced from 24
            ],

            // Form Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(24),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),

                    blurRadius: 20,

                    offset: const Offset(0, 10),
                  ),
                ],
              ),

              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Red Vertical Line Accent
                    Container(
                      width: 4,

                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,

                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),

                          bottomLeft: Radius.circular(24),
                        ),
                      ),
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),

                        child: Form(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              if (_reservationType == 'Event Place') ...[
                                // Event Type
                                _buildFormLabel('EVENT TYPE'),

                                const SizedBox(height: 8),

                                _buildStyledDropdown<String>(
                                  value: _selectedEventType,

                                  hint: 'Select event type',

                                  icon: Icons.celebration_rounded,

                                  items: _eventTypes,

                                  onChanged: (val) {
                                    setState(() {
                                      _selectedEventType = val;

                                      _eventController.text = val ?? '';
                                    });
                                  },
                                ),

                                const SizedBox(height: 24),
                              ],

                              // Date
                              _buildFormLabel(_reservationType == 'Event Place' ? 'DATE' : (_advanceOrderType == 'Dine In' ? 'DINING DATE' : 'PICKUP DATE')),

                              const SizedBox(height: 8),

                              _buildStyledTextField(
                                controller: _dateController,

                                hint: 'Select a date',

                                icon: Icons.calendar_month_rounded,

                                readOnly: true,

                                onTap: () async {
                                  final minDate = _reservationType == 'Advance Order'
                                      ? DateTime.now().add(const Duration(days: 1))
                                      : DateTime.now().add(const Duration(days: 4));

                                  DateTime? pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: minDate,
                                    firstDate: minDate,
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                  );

                                  if (pickedDate != null) {
                                    setState(() {
                                      _dateController.text =
                                          DateFormat('MMMM d, yyyy').format(pickedDate);
                                    });
                                  }
                                },
                              ),

                              const SizedBox(height: 24),

                              // Start Time
                              _buildFormLabel(_reservationType == 'Event Place' ? 'START TIME' : (_advanceOrderType == 'Dine In' ? 'DINING TIME' : 'PICKUP TIME')),

                              const SizedBox(height: 8),

                              _buildStyledTextField(
                                controller: _startTimeController,

                                hint: '-- : --',

                                icon: Icons.access_time_filled_rounded,

                                readOnly: true,

                                onTap: () async {
                                  final startHour = _reservationType == 'Advance Order' ? 10 : _operatingHoursStart;
                                  final endHour = _reservationType == 'Advance Order' ? 19 : _operatingHoursEnd;

                                  TimeOfDay? pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(hour: startHour, minute: 0),
                                  );

                                  if (pickedTime != null) {
                                    // Validate against operating hours
                                    if (pickedTime.hour < startHour ||
                                        pickedTime.hour > endHour ||
                                        (pickedTime.hour == endHour && pickedTime.minute > 0)) {
                                      _showSnackBar(
                                        'Please select a time between ${startHour.toString().padLeft(2, '0')}:00 and ${endHour.toString().padLeft(2, '0')}:00',
                                        Colors.red,
                                      );
                                      return;
                                    }

                                    // Check dynamic lead time for same-day Advance Orders
                                    if (_reservationType == 'Advance Order') {
                                      final now = DateTime.now();
                                      final selectedDateStr = _dateController.text.trim();
                                      if (selectedDateStr.isNotEmpty) {
                                        try {
                                          final selectedDate = DateFormat('MMMM d, yyyy').parse(selectedDateStr);
                                          final isToday = selectedDate.year == now.year &&
                                              selectedDate.month == now.month &&
                                              selectedDate.day == now.day;

                                          if (isToday) {
                                            final selectedDateTime = DateTime(
                                              now.year,
                                              now.month,
                                              now.day,
                                              pickedTime.hour,
                                              pickedTime.minute,
                                            );
                                            final leadTime = _calculateDynamicLeadTime();
                                            final minSelectableTime = now.add(leadTime);

                                            if (selectedDateTime.isBefore(minSelectableTime)) {
                                              final h = leadTime.inHours;
                                              final m = leadTime.inMinutes % 60;
                                              final leadTimeStr = h > 0 ? '$h hour${h > 1 ? "s" : ""} ${m > 0 ? "and $m min" : ""}' : '$m minutes';
                                              _showSnackBar(
                                                'For this order size, please select a time at least $leadTimeStr from now.',
                                                Colors.red,
                                              );
                                              return;
                                            }
                                          }
                                        } catch (e) {
                                          debugPrint('Error validating lead time: $e');
                                        }
                                      }
                                    }

                                    setState(() {
                                      _startTimeController.text = pickedTime.format(context);
                                    });
                                  }
                                },
                              ),

                              const SizedBox(height: 24),

                              if (_reservationType == 'Event Place') ...[
                                // Duration
                                _buildFormLabel('DURATION'),

                                const SizedBox(height: 8),

                                _buildStyledDropdown<String>(
                                  value: _selectedBaseDuration,

                                  hint: 'Select duration',

                                  icon: Icons.timer_rounded,

                                  items: _baseDurations,

                                  onChanged: (val) {
                                    setState(() {
                                      _selectedBaseDuration = val;

                                      _updateDurationText();
                                    });
                                  },
                                ),

                                const SizedBox(height: 24),
                              ],

                              // Number of Guests
                              if (_reservationType == 'Event Place' || (_reservationType == 'Advance Order' && _advanceOrderType == 'Dine In')) ...[
                                _buildFormLabel('GUESTS'),

                                const SizedBox(height: 8),

                                _buildStyledTextField(
                                  controller: _guestsController,
                                  hint: 'Enter number of guests',
                                  icon: Icons.people_alt_rounded,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  helperText: _reservationType == 'Event Place'
                                      ? '$_minGuestCount–100 guests allowed'
                                      : '1–20 guests allowed',
                                ),

                                const SizedBox(height: 24),
                              ],

                              // Menu Selection
                              _buildFormLabel('MENU SELECTION'),

                              const SizedBox(height: 8),

                              Container(
                                padding: const EdgeInsets.all(16),

                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,

                                  borderRadius: BorderRadius.circular(16),

                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),

                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,

                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedMenuItems.isEmpty
                                                ? 'No menu items selected'
                                                : '${_selectedMenuItems.values.fold(0, (sum, qty) => sum + qty)} items selected',

                                            style: TextStyle(
                                              fontSize: 14,

                                              color: _selectedMenuItems.isEmpty
                                                  ? Colors.grey.shade600
                                                  : Colors.black87,

                                              fontWeight:
                                                  _selectedMenuItems.isEmpty
                                                  ? FontWeight.normal
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                        ),

                                        if (_selectedMenuItems.isNotEmpty)
                                          TextButton(
                                            onPressed: () => setState(() {
                                              _selectedMenuItems.clear();
                                            }),

                                            child: const Text(
                                              'Clear',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),

                                    if (_selectedMenuItems.isNotEmpty) ...[
                                      const SizedBox(height: 12),

                                      Container(
                                        padding: const EdgeInsets.all(12),

                                        decoration: BoxDecoration(
                                          color: Colors.white,

                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),

                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),

                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,

                                          children: [
                                            Text(
                                              'Selected Items:',

                                              style: TextStyle(
                                                fontSize: 12,

                                                fontWeight: FontWeight.w600,

                                                color: Colors.grey.shade700,
                                              ),
                                            ),

                                            const SizedBox(height: 8),

                                            ..._selectedMenuItems.entries.map(
                                              (entry) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 4,
                                                ),

                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,

                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${entry.value}x ${entry.key}',

                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),

                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),

                                                    Text(
                                                      'PHP ${NumberFormat('#,##0.00').format(_menuReservationService.calculateMenuTotalPrice({entry.key: entry.value}))}',

                                                      style: const TextStyle(
                                                        fontSize: 12,

                                                        fontWeight:
                                                            FontWeight.w600,

                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            const Divider(height: 16),

                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,

                                              children: [
                                                const Text(
                                                  'Total Menu Price:',

                                                  style: TextStyle(
                                                    fontSize: 12,

                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),

                                                Text(
                                                  'PHP ${NumberFormat('#,##0.00').format(_menuReservationService.calculateMenuTotalPrice(_selectedMenuItems))}',

                                                  style: const TextStyle(
                                                    fontSize: 12,

                                                    fontWeight: FontWeight.bold,

                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 4),

                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,

                                              children: [
                                                Text(
                                                  _reservationType == 'Advance Order' ? 'Full Payment Required:' : '50% Deposit Required:',

                                                  style: TextStyle(
                                                    fontSize: 12,

                                                    color: Colors.grey,
                                                  ),
                                                ),

                                                Text(
                                                  'PHP ${NumberFormat("#,##0.00").format(_menuReservationService.calculateMenuDepositAmount(_menuReservationService.calculateMenuTotalPrice(_selectedMenuItems), reservationType: _reservationType))}',

                                                  style: const TextStyle(
                                                    fontSize: 12,

                                                    fontWeight: FontWeight.bold,

                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 16),

                                    SizedBox(
                                      width: double.infinity,

                                      child: ElevatedButton.icon(
                                        onPressed: _navigateToMenuSelection,

                                        icon: const Icon(
                                          Icons.restaurant_menu,
                                          size: 18,
                                        ),

                                        label: Text(
                                          _selectedMenuItems.isEmpty
                                              ? 'Select Menu Items'
                                              : 'Change Selection',
                                        ),

                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryColor,

                                          foregroundColor: Colors.white,

                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),

                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Extra Time Toggle
                              if (_reservationType == 'Event Place') 
                                Container(
                                  padding: const EdgeInsets.all(16),

                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,

                                    borderRadius: BorderRadius.circular(16),

                                    border: Border.all(
                                      color: Colors.grey.shade100,
                                    ),
                                  ),

                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),

                                          decoration: BoxDecoration(
                                            color: Colors.white,

                                            shape: BoxShape.circle,

                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),

                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),

                                          child: const Icon(
                                            Icons.history_toggle_off_rounded,

                                            color: AppTheme.primaryColor,

                                            size: 20,
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,

                                            children: [
                                              Text(
                                                'Extra Time',

                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,

                                                  fontSize: 14,

                                                  color: AppTheme.darkGrey,
                                                ),
                                              ),

                                              Text(
                                                'Allow flexibility for the event end',

                                                style: TextStyle(
                                                  fontSize: 11,

                                                  color: AppTheme.mediumGrey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        Switch(
                                          value: _addExtraTime,

                                          activeThumbColor:
                                              AppTheme.primaryColor,

                                          onChanged: (val) {
                                            setState(() {
                                              _addExtraTime = val;

                                              if (!_addExtraTime) {
                                                _selectedExtraTime = null;
                                              }

                                              _updateDurationText();
                                            });
                                          },
                                        ),
                                      ],
                                    ),

                                    if (_addExtraTime) ...[
                                      const SizedBox(height: 16),

                                      _buildStyledDropdown<String>(
                                        value: _selectedExtraTime,

                                        hint: 'Select extra time',

                                        icon: Icons.add_alarm_rounded,

                                        items: _extraTimeOptions,

                                        onChanged: (val) {
                                          setState(() {
                                            _selectedExtraTime = val;

                                            _updateDurationText();
                                          });
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24), // Reduced from 32

                              // Special Requests Field (if enabled)
                              if (_enableSpecialRequests) ...[
                                _buildFormLabel(_reservationType == 'Event Place' ? 'SPECIAL REQUESTS' : 'PREPARATION NOTES'),

                                const SizedBox(height: 8),

                                Container(
                                  padding: const EdgeInsets.all(16),

                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,

                                    borderRadius: BorderRadius.circular(16),

                                    border: Border.all(
                                      color: Colors.grey.shade100,
                                    ),
                                  ),

                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [
                                      TextFormField(
                                        controller: _specialRequestsController,

                                        maxLines: 3,

                                        decoration: InputDecoration(
                                          hintText:
                                              _reservationType == 'Event Place'
                                               ? 'Enter any special requests (dietary restrictions, accessibility needs, celebration requirements, etc.)'
                                               : 'Enter any preparation notes (no spice, utensils needed, allergy warnings, etc.)'
,

                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,

                                            fontSize: 13,
                                          ),

                                          filled: true,

                                          fillColor: Colors.white,

                                          contentPadding: const EdgeInsets.all(
                                            12,
                                          ),

                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),

                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),

                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),

                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),

                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),

                                            borderSide: const BorderSide(
                                              color: AppTheme.primaryColor,

                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      Text(
                                        _reservationType == 'Event Place'
                                            ? 'Examples: Vegetarian guests | Wheelchair access needed | Birthday surprise setup | High chair for baby'
                                            : 'Examples: No spicy food | Separate sauces | Extra napkins | Allergy to peanuts',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24), // Reduced from 32
                              ],

                              // Submit Button
                              SizedBox(
                                width: double.infinity,

                                height: 56,

                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _showConfirmationDialog,

                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,

                                    foregroundColor: Colors.white,

                                    elevation: 2,

                                    shadowColor: AppTheme.primaryColor
                                        .withValues(alpha: 0.3),

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),

                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,

                                          width: 24,

                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,

                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,

                                          children: [
                                            Text(
                                              _reservationType == 'Event Place' ? 'Confirm Reservation' : 'Confirm Advance Order',

                                              style: const TextStyle(
                                                fontSize: 16,

                                                fontWeight: FontWeight.bold,

                                                letterSpacing: 0.5,
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            const Icon(
                                              Icons.arrow_forward_rounded,

                                              size: 20,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24), // Reduced from 32
          ],
        ),
      ),
    );
  }

  // ── Reservation Form Helpers ──────────────────────────────────────


  Widget _buildFormLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppTheme.mediumGrey,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        helperText: helperText,
        helperStyle: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor.withValues(alpha: 0.7), size: 22),
      ),
    );
  }

  Widget _buildStyledDropdown<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value as String?,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.darkGrey),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor.withValues(alpha: 0.7), size: 22),
        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.mediumGrey),
      ),
      icon: const SizedBox.shrink(),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildProfileSection() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final name = _getUserDisplayName();
    final email = currentUser?.email ?? 'Not provided';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Profile Header Container
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration(),
              child: Row(
                children: [
                  Hero(
                    tag: 'profile_avatar_large',
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1), width: 3),
                        image: currentUser?.userMetadata?['avatar_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(currentUser!.userMetadata!['avatar_url']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: currentUser?.userMetadata?['avatar_url'] == null
                          ? Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkGrey,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.mediumGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (currentUser?.userMetadata?['avatar_url'] == null) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage()));
                              if (mounted) setState(() {});
                            },
                            child: const Text(
                              'Add a profile photo →',
                              style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Member Stats Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: AppTheme.cardDecoration(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildProfileStat('${customerReservations.length}', 'Reservations'),
                  _buildProfileDivider(),
                  _buildProfileStat(
                    DateFormat('MMM yyyy').format(DateTime.parse(currentUser?.createdAt ?? DateTime.now().toIso8601String())),
                    'Member Since',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Menu Cards
            _buildAccountMenuCard(
              icon: Icons.person_outline_rounded,
              title: 'Edit Profile',
              subtitle: 'Details about your account',
              onTap: () async {
                await Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => EditProfilePage()));

                if (mounted) {
                  setState(() {});
                }
              },
            ),

            if (currentUser?.appMetadata['provider'] == 'email')
              _buildAccountMenuCard(
                icon: Icons.lock_outline_rounded,
                title: 'Change Password',
                subtitle: 'Update your account security',
                onTap: _showChangePasswordDialog,
              ),

            _buildAccountMenuCard(
              icon: Icons.history_rounded,
              title: 'Transactions',
              subtitle: 'View your previous reservations',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TransactionsPage(initialTransactions: customerReservations),
                  ),
                );
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(height: 1, thickness: 0.5, color: AppTheme.lightGrey),
            ),

            _buildAccountMenuCard(
              icon: Icons.logout_rounded,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              isDestructive: true,
              onTap: _showLogoutDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildProfileDivider() {
    return Container(
      height: 30,
      width: 1,
      color: AppTheme.lightGrey,
    );
  }

  void _showChangePasswordDialog() {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    bool isPasswordVisible = false;
    bool isConfirmVisible = false;
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: !isUpdating,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Change Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            content: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Password',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: !isPasswordVisible,
                        enabled: !isUpdating,
                        decoration: InputDecoration(
                          hintText: 'Enter new password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: () => setDialogState(() => isPasswordVisible = !isPasswordVisible),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter a password';
                          if (value.length < 8) return 'Minimum 8 characters required';
                          if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must contain an uppercase letter';
                          if (!RegExp(r'[a-z]').hasMatch(value)) return 'Must contain a lowercase letter';
                          if (!RegExp(r'[0-9]').hasMatch(value)) return 'Must contain a number';
                          if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) return 'Must contain a special character';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Confirm New Password',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: !isConfirmVisible,
                        enabled: !isUpdating,
                        decoration: InputDecoration(
                          hintText: 'Re-enter new password',
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isConfirmVisible ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: () => setDialogState(() => isConfirmVisible = !isConfirmVisible),
                          ),
                        ),
                        validator: (value) {
                          if (value != newPasswordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      if (isUpdating) ...[
                        const SizedBox(height: 24),
                        const Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryColor),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUpdating ? null : () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                onPressed: isUpdating ? null : () async {
                  if (formKey.currentState!.validate()) {
                    setDialogState(() => isUpdating = true);
                    try {
                      await Supabase.instance.client.auth.updateUser(
                        UserAttributes(password: newPasswordController.text.trim()),
                      );
                      
                      if (context.mounted) {
                        Navigator.pop(context); // Close dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password updated successfully!'),
                            backgroundColor: AppTheme.successGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => isUpdating = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error updating password: $e'),
                            backgroundColor: AppTheme.errorRed,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Update Password'),
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildIntegratedMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), // Reduced from 24
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Featured Dishes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Menu Items Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildMenuCategoryGrid(),
        ),
      ],
    );
  }

  Widget _buildMenuCategoryGrid() {
    final Map<String, List<MenuItem>> allMenu = MenuService.getMenu();
    final List<MenuItem> flattenedItems = [];
    for (var list in allMenu.values) {
      flattenedItems.addAll(list);
    }
    
    // Curated list of top-selling products
    final List<String> topSellingNames = [
      'YangChow 1',
      'YangChow 3',
      'Buttered Chicken',
      'Lechon Macau',
      'Pancit Canton',
      'Yang Chow Fried Rice',
      'Siomai with Shrimp',
      'Sweet and Sour Pork',
      'Broccoli Leaves with Oyster Sauce',
    ];
    
    // Filter and ensure we maintain the order of topSellingNames
    final List<MenuItem> items = [];
    for (var name in topSellingNames) {
      final found = flattenedItems.where((item) => item.name == name).toList();
      if (found.isNotEmpty) {
        items.add(found.first);
      }
    }

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: const Center(
          child: Text(
            'No top-selling items available.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveUtils.isDesktop(context) ? 5 : (ResponsiveUtils.isTablet(context) ? 4 : 3),
        childAspectRatio: ResponsiveUtils.isDesktop(context) ? 0.75 : (ResponsiveUtils.isTablet(context) ? 0.7 : 0.65),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildProductCard(item);
      },
    );
  }

  Widget _buildProductCard(MenuItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  _buildImageWidget(item),
                  // Glassmorphic Price Badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '₱${_fmt.format(item.price)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Info Section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description ?? item.category,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(MenuItem item) {
    final imagePath = item.customImagePath ?? item.fallbackImagePath;
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppTheme.lightGrey,
        child: const Icon(Icons.fastfood, color: Colors.grey, size: 40),
      ),
    );
  }

  Future<void> _proceedToGCashPayment(
    Map<String, dynamic> reservation,
    double depositAmount,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GCashPaymentPage(
          reservationId: reservation['id'],
          depositAmount: depositAmount,
          table: reservation['_db_table'] ?? 'reservations',
          onPaymentSuccess: () {
            _updateReservationPaymentStatus(reservation['id'], depositAmount, reservation['_db_table'] ?? 'reservations');
          },
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,

      builder: (context) => AlertDialog(
        title: const Text('Error'),

        content: Text(message),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),

            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,

      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),

            const SizedBox(width: 12),

            const Text('Success'),
          ],
        ),

        content: Text(message),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),

            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateReservationPaymentStatus(
    String reservationId,
    double depositAmount,
    String table,
  ) async {
    try {
      await _reservationService.updatePaymentStatus(
        id: reservationId,
        paymentStatus: table == 'advance_orders' ? 'paid' : 'deposit_paid',
        table: table,
        paymentAmount: depositAmount,
      );

      _loadCustomerReservations();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _createReservationWithoutPayment(
    dynamic currentUser,

    String eventType,

    String eventDate,

    String startTime,

    double durationHours,

    int numberOfGuests,

    String specialRequests,
  ) async {
    try {
      // Check if menu items are selected for menu-based pricing

      if (_selectedMenuItems.isNotEmpty) {
        final totalMenuPrice = _menuReservationService.calculateMenuTotalPrice(
          _selectedMenuItems,
        );

        final depositAmount = _menuReservationService
            .calculateMenuDepositAmount(totalMenuPrice);

        await _reservationService.createMenuBasedReservation(
          customerEmail: currentUser.email ?? '',

          customerName: currentUser.userMetadata?['full_name'] ?? 'Customer',

          eventType: eventType,

          eventDate: eventDate,

          startTime: startTime,

          durationHours: durationHours,

          numberOfGuests: numberOfGuests,

          specialRequests: specialRequests,

          customerPhone: null,

          customerAddress: null,

          selectedMenuItems: _selectedMenuItems,

          totalMenuPrice: totalMenuPrice,

          depositAmount: depositAmount,
        );
      } else {
        // Use traditional reservation without menu-based pricing

        await _reservationService.createReservation(
          customerEmail: currentUser.email ?? '',

          customerName: currentUser.userMetadata?['full_name'] ?? 'Customer',

          eventType: eventType,

          eventDate: eventDate,

          startTime: startTime,

          durationHours: durationHours,

          numberOfGuests: numberOfGuests,

          specialRequests: specialRequests,

          customerPhone: null,

          customerAddress: null,
        );
      }

      if (!mounted) return;

      // Clear menu selection after successful reservation

      setState(() {
        _selectedMenuItems.clear();
      });

      _loadCustomerReservations();

      setState(() => _selectedIndex = 0);

      // Show success message with pricing details

      if (_selectedMenuItems.isNotEmpty) {
        final totalMenuPrice = _menuReservationService.calculateMenuTotalPrice(
          _selectedMenuItems,
        );

        final depositAmount = _menuReservationService
            .calculateMenuDepositAmount(totalMenuPrice, reservationType: _reservationType);

        _showSuccessDialog(
          'Reservation created successfully!\n\n'
          'Total Menu Price: PHP ${NumberFormat('#,##0.00').format(totalMenuPrice)}\n'
          '${_reservationType == 'Advance Order' ? 'Full Payment Required' : '50% Deposit Required'}: PHP ${NumberFormat('#,##0.00').format(depositAmount)}\n\n'
          'You will receive a price quotation shortly and can proceed with payment.',
        );
      } else {
        _showSuccessDialog(
          'Reservation created successfully! You will receive a price quotation shortly.',
        );
      }
    } catch (e) {
      _showErrorDialog('Failed to create reservation: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getPaymentStatusText(String status, bool isQuoted) {
    if (!isQuoted) return 'AWAITING QUOTATION';

    switch (status) {
      case 'deposit_paid':
        return 'DEPOSIT PAID';

      case 'paid':
      case 'fully_paid':
        return 'PAID';

      case 'unpaid':
        return 'DEPOSIT DUE';

      case 'refunded':
        return 'REFUNDED';

      default:
        return status.toUpperCase();
    }
  }

  Color _getPaymentStatusColor(String status, bool isQuoted) {
    if (!isQuoted) return Colors.orange;

    switch (status) {
      case 'deposit_paid':
        return Colors.green;

      case 'paid':
      case 'fully_paid':
        return Colors.green;

      case 'unpaid':
        return Colors.orange;

      case 'refunded':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  void _showPaymentDialog(Map<String, dynamic> reservation) {
    final pricingInfo = _reservationService.getReservationPricing(reservation);

    final depositAmount = pricingInfo['depositAmount'] as double;

    showDialog(
      context: context,

      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment, color: Colors.green),

            SizedBox(width: 8),

            Text('Pay Deposit'),
          ],
        ),

        content: Column(
          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              reservation['_db_table'] == 'advance_orders'
                  ? 'Complete your order by paying the full amount.'
                  : 'Complete your reservation by paying the 50% deposit.',

              style: TextStyle(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),

                borderRadius: BorderRadius.circular(8),

                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    reservation['_db_table'] == 'advance_orders' 
                        ? 'Total Amount:' 
                        : 'Deposit Amount:',

                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  Text(
                    'PHP ${depositAmount.toStringAsFixed(2)}',

                    style: const TextStyle(
                      fontWeight: FontWeight.bold,

                      color: Colors.green,

                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);

                  _proceedToGCashPayment(reservation, depositAmount);
                },

                icon: const Icon(Icons.qr_code_2_rounded),

                label: const Text('Pay with GCash QR'),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,

                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),

            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatLocalDateTime(dynamic dateTime) {
    if (dateTime == null) return 'N/A';

    try {
      final dt = dateTime is String
          ? DateTime.parse(dateTime).toLocal()
          : (dateTime as DateTime).toLocal();

      return "${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateTime.toString();
    }
  }

  Widget _buildAccountMenuCard({
    required IconData icon,

    required String title,

    required String subtitle,

    required VoidCallback onTap,

    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),

            blurRadius: 10,

            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          onTap: onTap,

          borderRadius: BorderRadius.circular(16),

          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: isDestructive
                        ? Colors.red.shade50
                        : AppTheme.primaryColor.withValues(alpha: 0.07),

                    shape: BoxShape.circle,
                  ),

                  child: Icon(
                    icon,

                    color: isDestructive
                        ? Colors.red.shade600
                        : AppTheme.primaryColor,

                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        title,

                        style: TextStyle(
                          fontSize: 16,

                          fontWeight: FontWeight.bold,

                          color: isDestructive
                              ? Colors.red.shade600
                              : AppTheme.darkGrey,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        subtitle,

                        style: TextStyle(
                          fontSize: 13,

                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios_rounded,

                  size: 16,

                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24), // Reduced from 24, 32
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reservation Activity',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkGrey,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Keep track of your upcoming and past events.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            if (customerReservations.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 60),
                width: double.infinity,
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_rounded,
                        size: 40,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No reservation activity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your booking history will appear here once you make your first reservation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppTheme.mediumGrey),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: customerReservations.length,
                itemBuilder: (context, index) {
                  final reservation = customerReservations[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: AppTheme.cardDecoration(),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: AppTheme.primaryColor.withValues(alpha: 0.03),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    reservation['event_type'] ?? 'Reservation',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkGrey,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    _buildStatusChip(reservation['status'] ?? 'pending'),
                                    const SizedBox(width: 8),
                                    if (reservation['_db_table'] == 'advance_orders' &&
                                        reservation['status'] == 'confirmed' &&
                                        reservation['payment_status'] != 'paid')
                                      IconButton(
                                        onPressed: () => _showPaymentDialog(reservation),
                                        icon: const Icon(Icons.payment_rounded, color: AppTheme.successGreen, size: 22),
                                        tooltip: 'Pay for Order',
                                      ),
                                    if (reservation['payment_status'] == 'paid' || 
                                        reservation['payment_status'] == 'fully_paid')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.successGreen.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'PAID',
                                          style: TextStyle(
                                            color: AppTheme.successGreen,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    if ((reservation['status'] == 'confirmed' ||
                                        reservation['status'] == 'pending') &&
                                        !(reservation['_db_table'] == 'advance_orders' && 
                                          (reservation['payment_status'] == 'paid' || reservation['payment_status'] == 'fully_paid')))
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, color: AppTheme.mediumGrey),
                                        onSelected: (String value) {
                                          if (value == 'cancel') {
                                            _showCancellationDialog(reservation);
                                          } else if (value == 'reschedule') {
                                            _showRescheduleDialog(reservation);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          const PopupMenuItem<String>(
                                            value: 'cancel',
                                            child: Row(
                                              children: [
                                                Icon(Icons.close_rounded, color: AppTheme.errorRed, size: 18),
                                                SizedBox(width: 12),
                                                Text('Cancel Reservation'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem<String>(
                                            value: 'reschedule',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_calendar_rounded, color: AppTheme.infoBlue, size: 18),
                                                SizedBox(width: 12),
                                                Text('Reschedule'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildActivityDetailRow(Icons.calendar_today_rounded, 'Date', reservation['event_date']),
                                const SizedBox(height: 12),
                                _buildActivityDetailRow(Icons.access_time_rounded, 'Time', reservation['start_time']),
                                if (reservation['number_of_guests'] != null) ...[
                                  const SizedBox(height: 12),
                                  _buildActivityDetailRow(Icons.people_alt_rounded, 'Guests', '${reservation['number_of_guests']} guests'),
                                ],
                                if (reservation['_db_table'] == 'reservations') ...[
                                  const SizedBox(height: 12),
                                  _buildActivityDetailRow(Icons.timer_rounded, 'Duration', '${reservation['duration_hours']} hours'),
                                ],
                                const Divider(height: 32),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Booked on: ${_formatLocalDateTime(reservation['created_at'])}',
                                      style: const TextStyle(color: AppTheme.mediumGrey, fontSize: 11),
                                    ),
                                    if (reservation['payment_status'] == 'paid' ||
                                        reservation['payment_status'] == 'fully_paid')
                                      const Icon(Icons.verified_rounded, color: AppTheme.successGreen, size: 16),
                                  ],
                                ),
                                if (reservation['selected_menu_items'] != null && 
                                     (reservation['selected_menu_items'] as Map).isNotEmpty) ...[
                                   const Divider(height: 32),
                                   _buildActivityOrderItems(reservation),
                                 ],
                                if (reservation['_db_table'] == 'advance_orders' && 
                                     (reservation['payment_status'] == 'paid' || reservation['payment_status'] == 'fully_paid')) ...[
                                   const Divider(height: 32),
                                   _buildProgressStepper(reservation['status'] ?? 'pending'),
                                 ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityOrderItems(Map<String, dynamic> reservation) {
    final items = reservation['selected_menu_items'] as Map<String, dynamic>? ?? {};
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ORDERED ITEMS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppTheme.mediumGrey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...items.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'x${entry.value}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProgressStepper(String status) {
    final steps = ['Paid', 'Preparing', 'Ready'];
    int currentStep = 0;
    
    final s = status.toLowerCase();
    if (s == 'preparing') currentStep = 1;
    else if (s == 'ready') currentStep = 2;
    else if (s == 'done' || s == 'completed') currentStep = 2;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORDER PROGRESS',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.mediumGrey, letterSpacing: 1.2),
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(steps.length, (index) {
              final isActive = index <= currentStep;
              final isCompleted = index < currentStep;
              
              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 2.5, 
                            color: index == 0 
                                ? Colors.transparent 
                                : (isActive ? AppTheme.primaryColor : Colors.grey.shade200)
                          )
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.primaryColor : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive ? AppTheme.primaryColor : Colors.grey.shade300, 
                              width: 2.5
                            ),
                            boxShadow: isActive ? [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ] : null,
                          ),
                          child: isCompleted 
                            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                            : (isActive ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))) : null),
                        ),
                        Expanded(
                          child: Container(
                            height: 2.5, 
                            color: index == steps.length - 1 
                                ? Colors.transparent 
                                : (index < currentStep ? AppTheme.primaryColor : Colors.grey.shade200)
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? AppTheme.darkGrey : AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityDetailRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor.withValues(alpha: 0.6)),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.mediumGrey),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value ?? 'N/A',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'pending':
        color = AppTheme.warningOrange;
        icon = Icons.pending_rounded;
        break;
      case 'confirmed':
        color = AppTheme.successGreen;
        icon = Icons.check_circle_rounded;
        break;
      case 'preparing':
        color = AppTheme.infoBlue;
        icon = Icons.local_fire_department_rounded;
        label = 'PREPARING';
        break;
      case 'ready':
        color = AppTheme.successGreen;
        icon = Icons.restaurant_rounded;
        label = 'READY';
        break;
      case 'done':
        color = AppTheme.mediumGrey;
        icon = Icons.check_circle_rounded;
        label = 'COMPLETED';
        break;
      case 'cancelled':
        color = AppTheme.errorRed;
        icon = Icons.cancel_rounded;
        break;
      default:
        color = AppTheme.mediumGrey;
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Show dialog to cancel a confirmed reservation with refund info

  void _showCancellationDialog(Map<String, dynamic> reservation) {
    final eventDate = reservation['event_date'];

    final eventType = reservation['event_type'];

    final refundAmount = _calculateRefundAmount(eventDate);

    void cancelReservation() async {
      if (!mounted) return;

      Navigator.pop(context);

      setState(() => _isLoading = true);

      try {
        final currentUser = Supabase.instance.client.auth.currentUser;

        if (currentUser == null) throw Exception('User not authenticated');

        // Show reason selection dialog

        String? selectedReason;

        await showDialog(
          context: context,

          builder: (context) => AlertDialog(
            title: const Text('Cancellation Reason'),

            content: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                const Text('Please select a reason for cancellation:'),

                const SizedBox(height: 16),

                ...AppConstants.cancellationReasons.map(
                  (reason) => ListTile(
                    title: Text(reason),

                    onTap: () {
                      selectedReason = reason;

                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );

        if (selectedReason == null) {
          setState(() => _isLoading = false);

          return;
        }

        // Cancel the record in the appropriate table
        if (reservation['_db_table'] == 'advance_orders') {
          await _reservationService.cancelAdvanceOrder(
            orderId: reservation['id'],

            customerEmail: currentUser.email!,

            customerName: currentUser.userMetadata?['name'] ?? 'Customer',

            orderType: reservation['order_type'] ?? 'Pick Up',

            orderDate: reservation['order_date'] ?? eventDate,

            cancellationReason: selectedReason!,
          );
        } else {
          await _reservationService.cancelReservation(
            reservationId: reservation['id'],

            customerEmail: currentUser.email!,

            customerName: currentUser.userMetadata?['name'] ?? 'Customer',

            eventType: eventType,

            eventDate: eventDate,

            cancellationReason: selectedReason!,

            isAdminCancel: false,
          );
        }

        // Send in-app notification to customer

        await NotificationService.sendNotification(
          recipientEmail: currentUser.email,

          actorName: 'System',

          actionType: 'cancelled',

          reservationId: reservation['id'],

          eventType: eventType,

          eventDate: eventDate,
        );

        // Send in-app notification to admins

        await NotificationService.sendNotification(
          isForAdmin: true,

          actorName: currentUser.userMetadata?['name'] ?? 'Customer',

          actionType: 'cancelled',

          reservationId: reservation['id'],

          eventType: eventType,

          eventDate: eventDate,

          customerEmail: currentUser.email,
        );

        _showSnackBar(
          'Reservation cancelled successfully. Refund: ₱${refundAmount.toStringAsFixed(2)}',

          Colors.green,
        );

        _loadCustomerReservations();
      } catch (e) {
        _showSnackBar('Error cancelling reservation: $e', Colors.red);
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }

    showDialog(
      context: context,

      barrierDismissible: false,

      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),

            SizedBox(width: 12),

            Text('Cancel Reservation'),
          ],
        ),

        content: Column(
          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text('Event: $eventType on $eventDate'),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),

                borderRadius: BorderRadius.circular(8),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Refund Information:',

                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Text('Expected Refund: ₱${refundAmount.toStringAsFixed(2)}'),

                  const SizedBox(height: 4),

                  Text(
                    refundAmount > 0
                        ? 'Refund will be processed within 5-7 business days'
                        : 'No refund (cancellation within policy window)',

                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),

            child: const Text('Keep Reservation'),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,

              foregroundColor: Colors.white,
            ),

            onPressed: cancelReservation,

            child: const Text('Cancel Reservation'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to reschedule a reservation

  void _showRescheduleDialog(Map<String, dynamic> reservation) {
    final currentDate = reservation['event_date'];

    final currentTime = reservation['start_time'];

    final currentDuration = reservation['duration_hours'];

    final currentGuests = reservation['number_of_guests'];

    String? newDate;

    String? newTime;

    showDialog(
      context: context,

      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),

          title: const Row(
            children: [
              Icon(Icons.edit_calendar, color: Colors.blue),

              SizedBox(width: 12),

              Text('Reschedule Reservation'),
            ],
          ),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Current: $currentDate at $currentTime - ${currentDuration}h with $currentGuests guests',
                ),

                const SizedBox(height: 20),

                const Text(
                  'New Date:',

                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                ElevatedButton.icon(
                  onPressed: () async {
                    final minDate = DateTime.now().add(
                      Duration(days: _appSettings.getMinReservationDaysAhead()),
                    );

                    final maxDate = DateTime.now().add(
                      Duration(days: _appSettings.getMaxReservationDaysAhead()),
                    );

                    final picked = await showDatePicker(
                      context: context,

                      initialDate: minDate,

                      firstDate: minDate,

                      lastDate: maxDate,
                    );

                    if (picked != null) {
                      setState(() {
                        newDate =
                            "${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}";
                      });
                    }
                  },

                  icon: const Icon(Icons.calendar_today),

                  label: Text(newDate ?? 'Select Date'),
                ),

                const SizedBox(height: 12),

                const Text(
                  'New Time:',

                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,

                      initialTime: TimeOfDay(
                        hour: _operatingHoursStart,

                        minute: 0,
                      ),
                    );

                    if (picked != null) {
                      setState(() {
                        newTime = picked.format(context);
                      });
                    }
                  },

                  icon: const Icon(Icons.access_time),

                  label: Text(newTime ?? 'Select Time'),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),

              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: (newDate != null && newTime != null)
                  ? () async {
                      Navigator.pop(context);

                      setState(() => _isLoading = true);

                      try {
                        await _reservationService.rescheduleReservation(
                          reservationId: reservation['id'],

                          newDate: _formatDateForStorage(newDate!),

                          newStartTime: newTime!,

                          newDuration: null,

                          newGuests: null,
                        );

                        _showSnackBar(
                          'Reservation rescheduled successfully',

                          Colors.green,
                        );

                        _loadCustomerReservations();
                      } catch (e) {
                        _showSnackBar('Error rescheduling: $e', Colors.red);
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }
                  : null,

              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper to format date for storage

  String _formatDateForStorage(String dateStr) {
    final parts = dateStr.split('/');

    return "${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}";
  }

  /// Calculate refund amount based on days until event

  double _calculateRefundAmount(String eventDate) {
    try {
      final event = DateTime.parse(eventDate);

      final now = DateTime.now();

      final daysUntilEvent = event.difference(now).inDays;

      final refundPolicyDays = _appSettings.getRefundPolicyDays();

      final refundPercentage = _appSettings.getRefundPercentageWithinWindow();

      if (daysUntilEvent >= refundPolicyDays) {
        return 100.0; // Full refund indicator
      }

      if (daysUntilEvent > 0) {
        return refundPercentage.toDouble();
      }

      return 0.0; // No refund
    } catch (e) {
      return 0.0;
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error_outline,

              color: Colors.white,
            ),

            const SizedBox(width: 12),

            Expanded(child: Text(message)),
          ],
        ),

        backgroundColor: color,

        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Check if customer already has a reservation for the given date

  Future<bool> _hasReservationOnDate(String formattedDate) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;

      if (currentUser == null) return false;

      final response = await Supabase.instance.client
          .from('reservations')
          .select('id')
          .eq('customer_email', currentUser.email!)
          .eq('event_date', formattedDate)
          .neq('status', 'cancelled'); // Exclude cancelled reservations

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking for existing reservations: $e');

      return false;
    }
  }

  void _showConfirmationDialog() {
    String date = _dateController.text.trim();
    String startTime = _startTimeController.text.trim();
    String guests = _guestsController.text.trim();

    // Check if required fields are filled
    bool hasRequiredFields = true;

    if (_reservationType == 'Event Place') {
      if (_selectedEventType == null) hasRequiredFields = false;
      if (date.isEmpty) hasRequiredFields = false;
      if (startTime.isEmpty) hasRequiredFields = false;
      if (_selectedBaseDuration == null) hasRequiredFields = false;
      if (guests.isEmpty) hasRequiredFields = false;
      if (_selectedMenuItems.isEmpty) hasRequiredFields = false;
    } else {
      if (date.isEmpty) hasRequiredFields = false;
      if (startTime.isEmpty) hasRequiredFields = false;
      if (_advanceOrderType == 'Dine In' && guests.isEmpty) hasRequiredFields = false;
      if (_selectedMenuItems.isEmpty) hasRequiredFields = false;
    }

    if (!hasRequiredFields) {
      _showSnackBar('Please fill in all required fields', Colors.red);
      return;
    }

    final String title = _reservationType == 'Event Place'
        ? 'Are you sure you want to Confirm Reservation?'
        : 'Are you sure you want to Confirm Advance Order?';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppTheme.primaryColor,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: const Text('No', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _submitReservation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Yes', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _submitReservation() async {
    String date = _dateController.text.trim();

    String startTime = _startTimeController.text.trim();

    String guests = _guestsController.text.trim();

    // Validation
    if (_reservationType == 'Event Place' && _selectedEventType == null) {
      _showSnackBar('Please select an event type', Colors.red);

      return;
    }

    if (date.isEmpty) {
      _showSnackBar('Please select a date', Colors.red);

      return;
    }

    if (startTime.isEmpty) {
      _showSnackBar('Please select a start time', Colors.red);

      return;
    }

    if (_reservationType == 'Event Place' && _selectedBaseDuration == null) {
      _showSnackBar('Please select a base duration', Colors.red);

      return;
    }

    // Guest Validation
    bool needsGuests = _reservationType == 'Event Place' ||
        (_reservationType == 'Advance Order' && _advanceOrderType == 'Dine In');

    if (needsGuests && guests.isEmpty) {
      _showSnackBar('Please enter the number of guests', Colors.red);

      return;
    }

    int guestCount = needsGuests ? (int.tryParse(guests) ?? 0) : 0;

    if (needsGuests) {
      int min = _reservationType == 'Event Place' ? _minGuestCount : 1;
      int max = _reservationType == 'Event Place' ? 100 : 20;

      if (guestCount < min || guestCount > max) {
        _showSnackBar(
          'Number of guests must be between $min and $max',
          Colors.red,
        );

        return;
      }
    }

    double totalDuration = _reservationType == 'Event Place' 
        ? (double.tryParse(_durationController.text) ?? 0.0)
        : 0.0;

    if (_reservationType == 'Event Place' && totalDuration == 0) {
      _showSnackBar('Invalid duration selected', Colors.red);

      return;
    }

    // Validate menu selection if items are selected

    if (_selectedMenuItems.isNotEmpty) {
      final validation = _menuReservationService.validateMenuSelection(
        _selectedMenuItems,
      );

      if (validation != null) {
        _showSnackBar(validation, Colors.red);

        return;
      }

    }

    String formattedDate;
    try {
      final parsedDate = DateFormat('MMMM d, yyyy').parse(date);
      formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e) {
      _showSnackBar('Invalid date format', Colors.red);
      return;
    }

    // Capacity Check
    if (_reservationType == 'Advance Order') {
      try {
        final parsedDate = DateFormat('MMMM d, yyyy').parse(date);
        // We need a full DateTime to check capacity
        // Parsing the startTime text to get hour/minute
        final timeFmt = DateFormat.jm(); // e.g. "10:00 AM"
        final parsedTime = timeFmt.parse(startTime);
        final selectedDateTime = DateTime(
          parsedDate.year,
          parsedDate.month,
          parsedDate.day,
          parsedTime.hour,
          parsedTime.minute,
        );

        setState(() => _isLoading = true);
        final hasCapacity = await _checkCapacity(selectedDateTime);
        setState(() => _isLoading = false);

        if (!hasCapacity) {
          _showSnackBar(
            'Sorry, this time slot is fully booked. Please choose another time.',
            Colors.orange,
          );
          return;
        }
      } catch (e) {
        debugPrint('Error in capacity check: $e');
      }
    }

    // Inventory Check
    if (_reservationType == 'Advance Order') {
      setState(() => _isLoading = true);
      final inventoryError = await _validateInventoryStock();
      setState(() => _isLoading = false);
      if (inventoryError != null) {
        _showSnackBar(inventoryError, Colors.red);
        return;
      }
    }

    // Check if customer already has a reservation for this date

    bool hasExistingReservation = await _hasReservationOnDate(formattedDate);

    if (hasExistingReservation) {
      _showSnackBar(
        'You already have a reservation for this date. Please choose a different date.',

        Colors.orange,
      );

      return;
    }

    // Get current user info

    final currentUser = Supabase.instance.client.auth.currentUser;

    if (!mounted) return;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),

              SizedBox(width: 12),

              Text('User not authenticated'),
            ],
          ),

          backgroundColor: Colors.red,

          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    setState(() => _isLoading = true);

    try {
      String formattedDate;
      try {
        final parsedDate = DateFormat('MMMM d, yyyy').parse(date);
        formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
      } catch (e) {
        throw Exception('Invalid date format');
      }

      // Create record in the appropriate table
      if (_reservationType == 'Advance Order') {
        final totalMenuPrice = _menuReservationService.calculateMenuTotalPrice(
          _selectedMenuItems,
        );

        // Create the advance order
        final response = await _reservationService.createAdvanceOrder(
          customerEmail: currentUser.email ?? '',
          customerName: currentUser.userMetadata?['name'] ?? 
                        currentUser.userMetadata?['full_name'] ?? 
                        'Customer',
          orderType: _advanceOrderType,
          orderDate: formattedDate,
          orderTime: startTime,
          numberOfGuests: _advanceOrderType == 'Dine In' ? guestCount : null,
          selectedMenuItems: _selectedMenuItems,
          totalPrice: totalMenuPrice,
          preparationNotes: _specialRequestsController.text.trim(),
        );

        final String orderId = response['id'].toString();

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // Redirect immediately to payment page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GCashPaymentPage(
              reservationId: orderId,
              depositAmount: totalMenuPrice,
              table: 'advance_orders',
              onPaymentSuccess: () {
                if (mounted) {
                  setState(() {
                    _selectedMenuItems.clear();
                    _selectedIndex = 0; // Go to home/activity
                  });
                  _loadCustomerReservations();
                  _showSuccessDialog(
                    'Advance Order paid and confirmed successfully!\n\n'
                    'Total Price: PHP ${NumberFormat('#,##0.00').format(totalMenuPrice)}\n\n'
                    'Your order is now being processed by the kitchen.',
                  );
                }
              },
            ),
          ),
        );
      } else {
        String finalEventType = _selectedEventType!;

        await _createReservationWithoutPayment(
          currentUser,

          finalEventType,

          formattedDate,

          startTime,

          totalDuration,

          guestCount,

          _specialRequestsController.text.trim(),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),

              const SizedBox(width: 12),

              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),

          backgroundColor: Colors.red,

          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildQuotationsSection() {
    final quotations = customerReservations.where((reservation) {
      return reservation['price_quotation_sent'] == true &&
          reservation['admin_set_price'] == true &&
          reservation['total_price'] != null &&
          reservation['total_price'] > 0;
    }).toList();

    if (quotations.isEmpty) {
      return Container(
        margin: EdgeInsets.only(bottom: 24),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.mail_outline, color: Colors.orange, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Price Quotations Yet',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    'Admin will send pricing quotations for your reservations',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monetization_on, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text(
                'Price Quotations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${quotations.length} quotation${quotations.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...quotations.map((reservation) => _buildQuotationCard(reservation)),
        ],
      ),
    ),
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> reservation) {
    final totalPrice = reservation['total_price'] as double;

    final depositAmount = reservation['deposit_amount'] as double;

    final paymentStatus = reservation['payment_status'] as String? ?? 'unpaid';

    final needsDepositPayment = _reservationService.needsDepositPayment(
      reservation,
    );

    return Card(
      margin: EdgeInsets.only(bottom: 16),

      elevation: 2,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),

        side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),

      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),

          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.05),

              Colors.white,
            ],

            begin: Alignment.topLeft,

            end: Alignment.bottomRight,
          ),
        ),

        child: Padding(
          padding: EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),

                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(8),
                    ),

                    child: Icon(
                      Icons.receipt_long,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),

                  SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          'Price Quotation',

                          style: TextStyle(
                            fontSize: 14,

                            fontWeight: FontWeight.bold,

                            color: AppTheme.primaryColor,
                          ),
                        ),

                        Text(
                          reservation['event_type'] ?? 'Event',

                          style: TextStyle(
                            fontSize: 12,

                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                    decoration: BoxDecoration(
                      color: _getPaymentStatusColor(
                        paymentStatus,
                        true,
                      ).withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(8),
                    ),

                    child: Text(
                      _getPaymentStatusText(paymentStatus, true),

                      style: TextStyle(
                        fontSize: 10,

                        color: _getPaymentStatusColor(paymentStatus, true),

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Event Details
              Container(
                padding: EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),

                  borderRadius: BorderRadius.circular(8),
                ),

                child: Column(
                  children: [
                    _buildQuotationDetailRow(
                      'Date',
                      reservation['event_date'] ?? 'N/A',
                      Icons.calendar_today,
                    ),

                    _buildQuotationDetailRow(
                      'Time',
                      '${reservation['start_time']} (${reservation['duration_hours']}h)',
                      Icons.access_time,
                    ),

                    _buildQuotationDetailRow(
                      'Guests',
                      '${reservation['number_of_guests']} people',
                      Icons.people,
                    ),
                  ],
                ),
              ),

              // Menu Items (if available)
              if (reservation['selected_menu_items'] != null) ...[
                SizedBox(height: 16),

                Container(
                  padding: EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),

                    borderRadius: BorderRadius.circular(8),

                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            color: AppTheme.primaryColor,
                            size: 16,
                          ),

                          SizedBox(width: 4),

                          Text(
                            'Menu Items',

                            style: TextStyle(
                              fontWeight: FontWeight.bold,

                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8),

                      ..._buildMenuItemsList(
                        reservation['selected_menu_items'],
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 16),

              // Pricing Breakdown
              Container(
                padding: EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.05),

                  borderRadius: BorderRadius.circular(8),

                  border: Border.all(
                    color: AppTheme.successGreen.withValues(alpha: 0.2),
                  ),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.monetization_on,
                          color: AppTheme.successGreen,
                          size: 16,
                        ),

                        SizedBox(width: 4),

                        Text(
                          'Pricing Details',

                          style: TextStyle(
                            fontWeight: FontWeight.bold,

                            color: AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    _buildPricingRow('Total Price', totalPrice, Colors.black),

                    _buildPricingRow(
                      reservation['_db_table'] == 'advance_orders' 
                          ? 'Full Payment' 
                          : 'Deposit (50%)',
                      depositAmount,
                      AppTheme.successGreen,
                    ),

                    _buildPricingRow(
                      'Remaining Balance',
                      totalPrice - depositAmount,
                      Colors.grey,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Action Buttons
              if (needsDepositPayment)
                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton.icon(
                    onPressed: () => _showPaymentDialog(reservation),

                    icon: Icon(Icons.payment, size: 18),

                    label: Text(
                      reservation['_db_table'] == 'advance_orders'
                          ? 'Pay Full Amount (PHP ${depositAmount.toStringAsFixed(2)})'
                          : 'Pay Deposit (PHP ${depositAmount.toStringAsFixed(2)})',
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,

                      foregroundColor: Colors.white,

                      padding: EdgeInsets.symmetric(vertical: 12),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                )
              else if (paymentStatus == 'deposit_paid')
                Container(
                  width: double.infinity,

                  padding: EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),

                    borderRadius: BorderRadius.circular(8),

                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),

                  child: Row(
                    children: [
                      Icon(
                        Icons.pending_actions,
                        color: Colors.orange,
                        size: 20,
                      ),

                      SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          'Deposit paid! Awaiting admin approval.',

                          style: TextStyle(
                            color: Colors.orange,

                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (reservation['status'] == 'pending_admin_approval')
                Container(
                  width: double.infinity,

                  padding: EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),

                    borderRadius: BorderRadius.circular(8),

                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),

                  child: Row(
                    children: [
                      Icon(
                        Icons.pending_actions,
                        color: Colors.orange,
                        size: 20,
                      ),

                      SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          'Payment received! Awaiting admin approval.',

                          style: TextStyle(
                            color: Colors.orange,

                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (reservation['status'] == 'confirmed')
                Container(
                  width: double.infinity,

                  padding: EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),

                    borderRadius: BorderRadius.circular(8),

                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),

                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),

                      SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          'Reservation confirmed!',

                          style: TextStyle(
                            color: Colors.green,

                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotationDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),

          SizedBox(width: 8),

          Expanded(
            child: Text(value, style: TextStyle(color: AppTheme.darkGrey)),
          ),
        ],
      ),
    );
  }

  double? _getMenuItemPrice(String menuName) {
    final menu = MenuService.getMenu();
    for (var category in menu.values) {
      for (var item in category) {
        if (item.name == menuName) {
          return item.price;
        }
      }
    }
    return null;
  }

  List<Widget> _buildMenuItemsList(Map<String, dynamic> selectedMenuItems) {
    if (selectedMenuItems.isEmpty) {
      return [
        Text(
          'No menu items selected',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      ];
    }

    final menuItems = <Widget>[];
    final items = selectedMenuItems;

    items.forEach((menuName, quantity) {
      final qty = quantity is int
          ? quantity
          : int.tryParse(quantity.toString()) ?? 0;
      if (qty > 0) {
        final price = _getMenuItemPrice(menuName);
        final totalPrice = price != null ? price * qty : 0.0;

        menuItems.add(
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menuName,
                  style: TextStyle(
                    color: AppTheme.darkGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (price != null)
                  Text(
                    '₱${price.toStringAsFixed(2)}   x$qty  =  ₱${totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(color: AppTheme.darkGrey, fontSize: 14),
                  ),
              ],
            ),
          ),
        );
      }
    });

    return menuItems;
  }

  Widget _buildPricingRow(String label, double amount, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          Text(
            label,

            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),

          Text(
            'PHP ${amount.toStringAsFixed(2)}',

            style: TextStyle(
              fontSize: 12,

              fontWeight: FontWeight.bold,

              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _updateDurationText() {
    if (_selectedBaseDuration == null) {
      _durationController.text = '';

      return;
    }

    double total = double.parse(_selectedBaseDuration!.split(' ')[0]);

    if (_addExtraTime && _selectedExtraTime != null) {
      if (_selectedExtraTime == '30 minutes') {
        total += 0.5;
      } else {
        total += double.parse(_selectedExtraTime!.split(' ')[0]);
      }
    }

    _durationController.text = total.toString();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,

      barrierDismissible: false,

      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

        title: const Row(
          children: [
            Icon(Icons.logout, color: AppTheme.primaryColor),

            SizedBox(width: 12),

            Text('Logout'),
          ],
        ),

        content: const Text(
          'Are you sure you want to logout?',

          style: TextStyle(fontSize: 16),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),

            child: const Text('Cancel'),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,

              foregroundColor: Colors.white,
            ),

            onPressed: () async {
              Navigator.pop(dialogContext);

              // Sign out from Supabase

              await Supabase.instance.client.auth.signOut();

              // Also sign out from Google to allow account switching

              try {
                await _googleSignIn.signOut();
              } catch (e) {
                debugPrint('Error signing out from Google: $e');
              }

              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',

                  (route) => false,
                );
              }
            },

            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
