import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:yang_chow/utils/app_theme.dart';

import 'package:yang_chow/utils/app_constants.dart';

import 'package:yang_chow/utils/responsive_utils.dart';

import 'package:yang_chow/pages/login_page.dart';

import 'package:yang_chow/pages/customer/payment_page.dart';

import 'package:yang_chow/pages/customer/edit_profile_page.dart';

import 'package:yang_chow/pages/customer/customer_chat_page.dart';

import 'package:yang_chow/services/paymongo_service.dart';

import 'package:yang_chow/services/notification_service.dart';

import 'package:yang_chow/services/app_settings_service.dart';

import 'package:yang_chow/services/reservation_service.dart';

import 'package:yang_chow/services/email_notification_service.dart';

import 'package:intl/intl.dart';

import 'package:flutter/foundation.dart' show kIsWeb;



class CustomerDashboardPage extends StatefulWidget {

  const CustomerDashboardPage({super.key});



  @override

  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();

}



class _CustomerDashboardPageState extends State<CustomerDashboardPage> {

  int _selectedIndex = 0;



  List<Map<String, dynamic>> customerReservations = [];

  bool _isLoading = false;

  Stream<List<Map<String, dynamic>>>? _notificationsStream;



  // Services

  late AppSettingsService _appSettings;

  late ReservationService _reservationService;

  late EmailNotificationService _emailService;



  // Configuration values (will be loaded from app_settings)

  int _minGuestCount = AppConstants.defaultMinGuestCount;

  int _maxGuestCount = AppConstants.defaultMaxGuestCount;

  int _operatingHoursStart = AppConstants.defaultOperatingHoursStart;

  int _operatingHoursEnd = AppConstants.defaultOperatingHoursEnd;

  late List<String> _baseDurations;

  late List<String> _extraTimeOptions;

  bool _enableSpecialRequests = AppConstants.defaultEnableSpecialRequests;

  String? _lastSeenNotificationId;



  // Form controllers



  final TextEditingController _eventController = TextEditingController();



  final TextEditingController _dateController = TextEditingController();



  final TextEditingController _startTimeController = TextEditingController();



  final TextEditingController _durationController = TextEditingController();



  final TextEditingController _guestsController = TextEditingController();



  final TextEditingController _specialRequestsController =

      TextEditingController();



  // New state variables for form improvements

  String? _selectedEventType;

  String? _selectedBaseDuration;

  bool _addExtraTime = false;

  String? _selectedExtraTime;



  final List<String> _eventTypes = AppConstants.eventTypes;



  // Google Sign-In instance



  final GoogleSignIn _googleSignIn = GoogleSignIn(

    clientId: kIsWeb

        ? '58922100698-jmttb6okfltmpcco2f2rrh8rmppappk6.apps.googleusercontent.com' // Web Client ID

        : '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com', // Android Client ID

  );



  @override

  void initState() {

    super.initState();

    _appSettings = AppSettingsService();

    _reservationService = ReservationService();

    _emailService = EmailNotificationService();



    // Initialize configuration from app_settings

    _loadConfigurationSettings();



    _loadCustomerReservations();



    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser != null) {

      _notificationsStream =

          NotificationService.getCustomerAdminNotificationsStream(

            currentUser.email!,

          );

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



      final response = await Supabase.instance.client

          .from('reservations')

          .select('*')

          .eq('customer_email', currentUser.email!)

          .order('created_at', ascending: false);



      final newReservations = List<Map<String, dynamic>>.from(response);



      setState(() {

        customerReservations = newReservations;

      });

    } catch (e) {

      debugPrint('Error loading customer reservations: $e');

    }

  }



  @override

  Widget build(BuildContext context) {

    final isDesktop = ResponsiveUtils.isDesktop(context);



    return Scaffold(

      backgroundColor: isDesktop ? Colors.white : const Color(0xFFF9F9FF),

      appBar: isDesktop

          ? AppBar(

              automaticallyImplyLeading: false,

              title: const Text('Customer Dashboard'),

              backgroundColor: AppTheme.primaryColor,

              foregroundColor: Colors.white,

            )

          : _buildDashboardAppBar(_getAppBarTitle()),

      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),

    );

  }



  String _getAppBarTitle() {

    switch (_selectedIndex) {

      case 0:

        return 'Home';

      case 1:

        return 'Reservation';

      case 2:

        return 'Chat Support';

      case 3:

        return 'Activity';

      case 4:

        return 'Account';

      default:

        return 'Home';

    }

  }



  PreferredSizeWidget _buildDashboardAppBar(String title) {

    return AppBar(

      backgroundColor: const Color(0xFFF9F9FF),

      elevation: 0,

      scrolledUnderElevation: 0,

      automaticallyImplyLeading: false,

      centerTitle: true,

      leading: Builder(

        builder: (context) => IconButton(

          icon: const Icon(

            Icons.menu,

            color: Color(0xFF1D1B1E),

          ),

          onPressed: () => Scaffold.of(context).openDrawer(),

        ),

      ),

      title: Text(

        title,

        style: const TextStyle(

          color: Color(0xFF1D1B1E),

          fontWeight: FontWeight.bold,

        ),

      ),

      actions: [_buildNotificationIcon(), const SizedBox(width: 8)],

    );

  }



  Widget _buildNotificationIcon() {

    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) return const SizedBox.shrink();



    return StreamBuilder<List<Map<String, dynamic>>>(

      stream: _notificationsStream,

      builder: (context, snapshot) {

        final notifications = snapshot.data ?? [];

        final newestId = notifications.isNotEmpty ? notifications.first['id']?.toString() : null;

        

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

                color: Color(0xFF1D1B1E),

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

                      color: const Color(0xFFF9F9FF),

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

        // Dark Sidebar

        Container(

          width: 280,



          color: const Color(0xFF1E1E1E),



          child: Column(

            children: [

              // Logo Section

              Container(

                padding: const EdgeInsets.all(24),



                child: Row(

                  children: [

                    Container(

                      width: 40,



                      height: 40,



                      decoration: BoxDecoration(

                        color: AppTheme.primaryColor,



                        borderRadius: BorderRadius.circular(8),

                      ),



                      child: const Icon(

                        Icons.restaurant,



                        color: Colors.white,



                        size: 24,

                      ),

                    ),



                    const SizedBox(width: 12),



                    const Text(

                      'Yang Chow',



                      style: TextStyle(

                        color: Colors.white,



                        fontSize: 20,



                        fontWeight: FontWeight.bold,

                      ),

                    ),

                  ],

                ),

              ),



              // Navigation Items

              ...List.generate(5, (index) {

                final icons = [

                  Icons.home_rounded,

                  Icons.event_available_rounded,

                  Icons.chat_bubble_rounded,

                  Icons.assignment_rounded,

                  Icons.person_rounded,

                ];



                final labels = ['Home', 'Reservations', 'Chat', 'Activity', 'Account'];



                return Container(

                  margin: const EdgeInsets.symmetric(

                    horizontal: 16,

                    vertical: 4,

                  ),



                  decoration: BoxDecoration(

                    color: _selectedIndex == index

                        ? AppTheme.primaryColor

                        : Colors.transparent,



                    borderRadius: BorderRadius.circular(8),

                  ),



                  child: ListTile(

                    leading: Icon(

                      icons[index],



                      color: _selectedIndex == index

                          ? Colors.white

                          : Colors.grey.shade400,

                    ),



                    title: Text(

                      labels[index],



                      style: TextStyle(

                        color: _selectedIndex == index

                            ? Colors.white

                            : Colors.grey.shade400,



                        fontWeight: _selectedIndex == index

                            ? FontWeight.bold

                            : FontWeight.normal,

                      ),

                    ),



                    onTap: () {

                      setState(() => _selectedIndex = index);

                    },

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

            color: const Color(0xFFF5F5F5),



            child: Column(

              children: [

                // Header

                Container(

                  padding: const EdgeInsets.all(24),



                  color: Colors.white,



                  child: Row(

                    mainAxisAlignment: MainAxisAlignment.spaceBetween,



                    children: [

                      const Text(

                        'Customer Dashboard',



                        style: TextStyle(

                          fontSize: 24,



                          fontWeight: FontWeight.bold,



                          color: Color(0xFF1E1E1E),

                        ),

                      ),



                      Row(

                        children: [

                          _buildNotificationIcon(),

                          const SizedBox(width: 8),

                          IconButton(

                            onPressed: _showLogoutDialog,



                            icon: const Icon(

                              Icons.logout,

                              color: Color(0xFF1E1E1E),

                            ),



                            tooltip: 'Logout',

                          ),

                        ],

                      ),

                    ],

                  ),

                ),



                // Content Area

                Expanded(

                  child: Padding(

                    padding: const EdgeInsets.all(24),



                    child: _buildContent(),

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

          child: Container(

            color: Colors.transparent,

            child: RefreshIndicator(

              onRefresh: _loadCustomerReservations,



              color: AppTheme.primaryColor,



              child: _selectedIndex == 3

                  ? _buildContent()

                  : Padding(

                      padding: const EdgeInsets.all(16.0),

                      child: _buildContent(),

                    ),

            ),

          ),

        ),



        // Modern Animated Mobile Navigation at Bottom

        Container(

          padding: const EdgeInsets.only(

            bottom: 16,

            left: 16,

            right: 16,

            top: 8,

          ),



          decoration: BoxDecoration(

            color: const Color(

              0xFFF5F5F5,

            ), // Match background to blend seamlessly

          ),



          child: Container(

            decoration: BoxDecoration(

              color: Colors.white,



              borderRadius: BorderRadius.circular(30),



              boxShadow: [

                BoxShadow(

                  color: AppTheme.primaryColor.withValues(alpha: 0.15),



                  blurRadius: 20,



                  offset: const Offset(0, 10),

                ),



                BoxShadow(

                  color: Colors.black.withValues(alpha: 0.05),



                  blurRadius: 10,



                  offset: const Offset(0, -2),

                ),

              ],

            ),



            child: Padding(

              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),



              child: Row(

                mainAxisAlignment: MainAxisAlignment.spaceEvenly,



                children: [

                  Expanded(

                    child: _buildMobileNavItem(0, Icons.home_rounded, 'Home'),

                  ),



                  Expanded(

                    child: _buildMobileNavItem(

                      1,

                      Icons.event_available_rounded,

                      'Reserve',

                    ),

                  ),



                  Expanded(

                    child: _buildMobileNavItem(2, Icons.chat_bubble_rounded, 'Chat'),

                  ),



                  Expanded(

                    child: _buildMobileNavItem(3, Icons.assignment_rounded, 'Activity'),

                  ),



                  Expanded(

                    child: _buildMobileNavItem(4, Icons.person_rounded, 'Account'),

                  ),

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

        setState(() {

          _selectedIndex = index;

        });

      },



      behavior: HitTestBehavior.opaque,



      child: AnimatedContainer(

        duration: const Duration(milliseconds: 300),



        curve: Curves.easeOutCubic,



        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),



        decoration: BoxDecoration(

          color: isSelected

              ? AppTheme.primaryColor.withValues(alpha: 0.1)

              : Colors.transparent,



          borderRadius: BorderRadius.circular(20),

        ),



        child: Column(

          mainAxisSize: MainAxisSize.min,



          children: [

            AnimatedScale(

              scale: isSelected ? 1.15 : 1.0,



              duration: const Duration(milliseconds: 300),



              curve: Curves.easeOutBack,



              child: Stack(

                alignment: Alignment.center,



                children: [

                  if (isSelected)

                    Container(

                      width: 32,



                      height: 32,



                      decoration: BoxDecoration(

                        shape: BoxShape.circle,



                        boxShadow: [

                          BoxShadow(

                            color: AppTheme.primaryColor.withValues(alpha: 0.3),



                            blurRadius: 12,



                            spreadRadius: 2,

                          ),

                        ],

                      ),

                    ),



                  Icon(

                    icon,



                    color: isSelected

                        ? AppTheme.primaryColor

                        : Colors.grey.shade700,



                    size: 24,

                  ),

                ],

              ),

            ),



            AnimatedContainer(

              duration: const Duration(milliseconds: 300),



              height: isSelected ? 4 : 0,

            ),



            if (isSelected)

              Text(

                label,



                style: TextStyle(

                  color: AppTheme.primaryColor,



                  fontWeight: FontWeight.w700,



                  fontSize: 12,



                  letterSpacing: 0.2,

                ),

              )

            else

              Text(

                label,



                style: TextStyle(

                  color: Colors.grey.shade500,



                  fontWeight: FontWeight.w500,



                  fontSize: 11,

                ),

              ),

          ],

        ),

      ),

    );

  }



  Widget _buildContent() {

    switch (_selectedIndex) {

      case 0:

        return _buildHomeSection();



      case 1:

        return _buildReservationsSection();



      case 2:

        return const CustomerChatPage();



      case 3:

        return _buildActivitySection();



      case 4:

        return _buildProfileSection();



      default:

        return _buildHomeSection();

    }

  }



  Widget _buildHomeSection() {

    return SingleChildScrollView(

      physics: const AlwaysScrollableScrollPhysics(),



      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,



        children: [

          // Welcome Banner

          Container(

            padding: const EdgeInsets.all(32),



            decoration: BoxDecoration(

              color: AppTheme.primaryColor,



              borderRadius: BorderRadius.circular(16),

            ),



            child: Row(

              children: [

                Container(

                  width: 80,

                  height: 80,

                  decoration: BoxDecoration(

                    color: Colors.white.withValues(alpha: 0.2),

                    shape: BoxShape.circle,

                    image:

                        Supabase

                                .instance

                                .client

                                .auth

                                .currentUser

                                ?.userMetadata?['avatar_url'] !=

                            null

                        ? DecorationImage(

                            image: NetworkImage(

                              Supabase

                                  .instance

                                  .client

                                  .auth

                                  .currentUser!

                                  .userMetadata!['avatar_url'],

                            ),

                            fit: BoxFit.cover,

                          )

                        : null,

                  ),

                  child:

                      Supabase

                              .instance

                              .client

                              .auth

                              .currentUser

                              ?.userMetadata?['avatar_url'] ==

                          null

                      ? const Icon(

                          Icons.waving_hand,

                          color: Colors.white,

                          size: 40,

                        )

                      : null,

                ),



                const SizedBox(width: 24),



                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,



                    children: [

                      Text(

                        'Welcome to Yang Chow, ${Supabase.instance.client.auth.currentUser?.userMetadata?['full_name']?.replaceAll('User', '') ?? Supabase.instance.client.auth.currentUser?.userMetadata?['name']?.replaceAll('User', '') ?? 'User'}!',



                        style: const TextStyle(

                          color: Colors.white,



                          fontSize: 28,



                          fontWeight: FontWeight.bold,

                        ),

                      ),



                      const SizedBox(height: 8),



                      Text(

                        'Your premium dining experience awaits. Ready for your next reservation?',



                        style: TextStyle(

                          color: Colors.white.withValues(alpha: 0.9),



                          fontSize: 16,

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ),



          const SizedBox(height: 32),



          const SizedBox(height: 24),



          // Quick Actions

          Container(

            padding: const EdgeInsets.all(24),



            decoration: BoxDecoration(

              color: Colors.white,



              borderRadius: BorderRadius.circular(12),



              boxShadow: [

                BoxShadow(

                  color: Colors.black.withValues(alpha: 0.1),



                  blurRadius: 4,



                  offset: const Offset(0, 2),

                ),

              ],

            ),



            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,



              children: [

                const Text(

                  'Quick Actions',



                  style: TextStyle(

                    fontSize: 18,



                    fontWeight: FontWeight.bold,



                    color: Color(0xFF1E1E1E),

                  ),

                ),



                const SizedBox(height: 20),



                Row(

                  children: [

                    Expanded(

                      child: Container(

                        height: 48,



                        decoration: BoxDecoration(

                          color: AppTheme.primaryColor,



                          borderRadius: BorderRadius.circular(8),

                        ),



                        child: Material(

                          color: Colors.transparent,



                          child: InkWell(

                            onTap: () {

                              setState(() {

                                _selectedIndex = 1;

                              });

                            },



                            borderRadius: BorderRadius.circular(8),



                            child: const Center(

                              child: Row(

                                mainAxisAlignment: MainAxisAlignment.center,



                                children: [

                                  Icon(

                                    Icons.add,

                                    color: Colors.white,

                                    size: 20,

                                  ),



                                  SizedBox(width: 8),



                                  Flexible(

                                    child: Text(

                                      'Make a New Reservation',



                                      style: TextStyle(

                                        color: Colors.white,



                                        fontWeight: FontWeight.w600,



                                        fontSize: 14,

                                      ),



                                      overflow: TextOverflow.ellipsis,

                                    ),

                                  ),

                                ],

                              ),

                            ),

                          ),

                        ),

                      ),

                    ),



                    const SizedBox(width: 16),



                    Expanded(

                      child: Container(

                        height: 48,



                        decoration: BoxDecoration(

                          color: Colors.white,



                          border: Border.all(color: Colors.grey.shade300),



                          borderRadius: BorderRadius.circular(8),

                        ),



                        child: Material(

                          color: Colors.transparent,



                          child: InkWell(

                            onTap: () {

                              setState(() {

                                _selectedIndex = 3;

                              });

                            },



                            borderRadius: BorderRadius.circular(8),



                            child: Center(

                              child: Row(

                                mainAxisAlignment: MainAxisAlignment.center,



                                children: [

                                  Icon(

                                    Icons.person_outline,



                                    color: Colors.grey.shade600,



                                    size: 20,

                                  ),



                                  const SizedBox(width: 8),



                                  Text(

                                    'My Account',



                                    style: TextStyle(

                                      color: Colors.grey.shade600,



                                      fontWeight: FontWeight.w600,



                                      fontSize: 14,

                                    ),

                                  ),

                                ],

                              ),

                            ),

                          ),

                        ),

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ),



          const SizedBox(height: 24),



          // Recent Activity

          Container(

            padding: const EdgeInsets.all(24),



            decoration: BoxDecoration(

              color: Colors.white,



              borderRadius: BorderRadius.circular(12),



              boxShadow: [

                BoxShadow(

                  color: Colors.black.withValues(alpha: 0.1),



                  blurRadius: 4,



                  offset: const Offset(0, 2),

                ),

              ],

            ),



            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,



              children: [

                Row(

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,



                  children: [

                    const Text(

                      'Recent Activity',



                      style: TextStyle(

                        fontSize: 18,



                        fontWeight: FontWeight.bold,



                        color: Color(0xFF1E1E1E),

                      ),

                    ),



                    TextButton(

                      onPressed: () {

                        setState(() {

                          _selectedIndex = 2;

                        });

                      },



                      child: const Text(

                        'View All Activity',



                        style: TextStyle(

                          color: AppTheme.primaryColor,



                          fontWeight: FontWeight.w600,

                        ),

                      ),

                    ),

                  ],

                ),



                const SizedBox(height: 20),



                customerReservations.isEmpty

                    ? Container(

                        padding: const EdgeInsets.all(32),



                        child: Column(

                          children: [

                            Icon(

                              Icons.folder_outlined,



                              size: 48,



                              color: Colors.grey.shade400,

                            ),



                            const SizedBox(height: 16),



                            Text(

                              'No recent activity found',



                              style: TextStyle(

                                fontSize: 16,



                                fontWeight: FontWeight.w500,



                                color: Colors.grey.shade600,

                              ),

                            ),



                            const SizedBox(height: 8),



                            Text(

                              'Book your first table to start seeing activity here.',



                              style: TextStyle(

                                fontSize: 14,



                                color: Colors.grey.shade500,

                              ),

                            ),

                          ],

                        ),

                      )

                    : ListView.builder(

                        shrinkWrap: true,



                        physics: const NeverScrollableScrollPhysics(),



                        itemCount: customerReservations.take(3).length,



                        itemBuilder: (context, index) {

                          final reservation = customerReservations[index];



                          return Container(

                            margin: const EdgeInsets.only(bottom: 12),



                            padding: const EdgeInsets.all(16),



                            decoration: BoxDecoration(

                              color: Colors.grey.shade50,



                              borderRadius: BorderRadius.circular(8),



                              border: Border.all(color: Colors.grey.shade200),

                            ),



                            child: Row(

                              children: [

                                Container(

                                  padding: const EdgeInsets.all(8),



                                  decoration: BoxDecoration(

                                    color: _getStatusColor(

                                      reservation['status'],

                                    ).withValues(alpha: 0.1),



                                    borderRadius: BorderRadius.circular(6),

                                  ),



                                  child: Icon(

                                    _getStatusIcon(reservation['status']),



                                    color: _getStatusColor(

                                      reservation['status'],

                                    ),



                                    size: 20,

                                  ),

                                ),



                                const SizedBox(width: 12),



                                Expanded(

                                  child: Column(

                                    crossAxisAlignment:

                                        CrossAxisAlignment.start,



                                    children: [

                                      Text(

                                        reservation['event_type'] ??

                                            'Reservation',



                                        style: const TextStyle(

                                          fontWeight: FontWeight.w600,



                                          fontSize: 14,

                                        ),

                                      ),



                                      const SizedBox(height: 4),



                                      Text(

                                        '${reservation['event_date']} at ${reservation['start_time']}',



                                        style: TextStyle(

                                          color: Colors.grey.shade600,



                                          fontSize: 12,

                                        ),

                                      ),

                                    ],

                                  ),

                                ),



                                Container(

                                  padding: const EdgeInsets.symmetric(

                                    horizontal: 8,

                                    vertical: 4,

                                  ),



                                  decoration: BoxDecoration(

                                    color: _getStatusColor(

                                      reservation['status'],

                                    ).withValues(alpha: 0.1),



                                    borderRadius: BorderRadius.circular(12),

                                  ),



                                  child: Text(

                                    reservation['status']?.toUpperCase() ??

                                        'PENDING',



                                    style: TextStyle(

                                      color: _getStatusColor(

                                        reservation['status'],

                                      ),



                                      fontSize: 10,



                                      fontWeight: FontWeight.w600,

                                    ),

                                  ),

                                ),

                              ],

                            ),

                          );

                        },

                      ),

              ],

            ),

          ),



          const SizedBox(height: 24),

        ],

      ),

    );

  }



  Color _getStatusColor(String? status) {

    switch (status) {

      case 'pending':

        return Colors.orange;



      case 'confirmed':

        return Colors.green;



      case 'cancelled':

        return Colors.red;



      default:

        return Colors.grey;

    }

  }



  IconData _getStatusIcon(String? status) {

    switch (status) {

      case 'pending':

        return Icons.pending;



      case 'confirmed':

        return Icons.check_circle;



      case 'cancelled':

        return Icons.cancel;



      default:

        return Icons.help;

    }

  }



  String _formatLocalDateTime(String? dateTimeString) {

    if (dateTimeString == null || dateTimeString.isEmpty) {

      return 'Unknown time';

    }



    try {

      DateTime utcTime = DateTime.parse(dateTimeString);



      DateTime localTime = utcTime.toLocal();



      return '${localTime.year.toString().padLeft(4, '0')}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}:${localTime.second.toString().padLeft(2, '0')}';

    } catch (e) {

      return 'Invalid time';

    }

  }



  Widget _buildReservationsSection() {

    return SingleChildScrollView(

      physics: const AlwaysScrollableScrollPhysics(),

      child: Padding(

        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // Header

            const Text(

              'Reserve Your Space',

              style: TextStyle(

                fontSize: 28,

                fontWeight: FontWeight.bold,

                color: Color(0xFF1D1B1E),

                height: 1.2,

              ),

            ),

            const SizedBox(height: 8),

            Text(

              'Curate your next memorable moment with ease.',

              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),

            ),

            const SizedBox(height: 32),



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



                              // Date

                              _buildFormLabel('DATE'),

                              const SizedBox(height: 8),

                              _buildStyledTextField(

                                controller: _dateController,

                                hint: 'mm/dd/yyyy',

                                icon: Icons.calendar_month_rounded,

                                readOnly: true,

                                onTap: () async {

                                  final minDate = DateTime.now().add(

                                    const Duration(days: 4),

                                  );

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

                                          "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";

                                    });

                                  }

                                },

                              ),

                              const SizedBox(height: 24),



                              // Start Time

                              _buildFormLabel('START TIME'),

                              const SizedBox(height: 8),

                              _buildStyledTextField(

                                controller: _startTimeController,

                                hint: '-- : --',

                                icon: Icons.access_time_filled_rounded,

                                readOnly: true,

                                onTap: () async {

                                  TimeOfDay? pickedTime = await showTimePicker(

                                    context: context,

                                    initialTime: TimeOfDay(

                                      hour: _operatingHoursStart,

                                      minute: 0,

                                    ),

                                  );

                                  if (pickedTime != null) {

                                    // Validate against configurable operating hours

                                    if (pickedTime.hour <

                                            _operatingHoursStart ||

                                        pickedTime.hour > _operatingHoursEnd ||

                                        (pickedTime.hour ==

                                                _operatingHoursEnd &&

                                            pickedTime.minute > 0)) {

                                      if (mounted) {

                                        ScaffoldMessenger.of(

                                          context,

                                        ).showSnackBar(

                                          SnackBar(

                                            content: Text(

                                              'Please select a time between ${_operatingHoursStart.toString().padLeft(2, '0')}:00 and ${_operatingHoursEnd.toString().padLeft(2, '0')}:00',

                                            ),

                                            backgroundColor: Colors.red,

                                          ),

                                        );

                                      }

                                      return;

                                    }

                                    setState(() {

                                      _startTimeController.text = pickedTime

                                          .format(context);

                                    });

                                  }

                                },

                              ),

                              const SizedBox(height: 24),



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



                              // Number of Guests

                              _buildFormLabel('GUESTS'),

                              const SizedBox(height: 8),

                              _buildStyledTextField(

                                controller: _guestsController,

                                hint: '0',

                                icon: Icons.people_alt_rounded,

                                keyboardType: TextInputType.number,

                                inputFormatters: [

                                  FilteringTextInputFormatter.digitsOnly,

                                ],

                              ),

                              const SizedBox(height: 24),



                              // Extra Time Toggle

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

                                                  color: Color(0xFF1D1B1E),

                                                ),

                                              ),

                                              Text(

                                                'Allow flexibility for the event end',

                                                style: TextStyle(

                                                  fontSize: 11,

                                                  color: Color(0xFF6B6B6B),

                                                ),

                                              ),

                                            ],

                                          ),

                                        ),

                                        Switch(

                                          value: _addExtraTime,

                                          activeThumbColor: AppTheme.primaryColor,

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

                              const SizedBox(height: 32),



                              // Special Requests Field (if enabled)

                              if (_enableSpecialRequests) ...[

                                _buildFormLabel('SPECIAL REQUESTS'),

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

                                              'Enter any special requests (dietary restrictions, accessibility needs, celebration requirements, etc.)',

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

                                        'Examples: Vegetarian guests | Wheelchair access needed | Birthday surprise setup | High chair for baby',

                                        style: TextStyle(

                                          fontSize: 11,

                                          color: Colors.grey.shade500,

                                        ),

                                      ),

                                    ],

                                  ),

                                ),

                                const SizedBox(height: 32),

                              ],



                              // Submit Button

                              SizedBox(

                                width: double.infinity,

                                height: 56,

                                child: ElevatedButton(

                                  onPressed: _isLoading

                                      ? null

                                      : _submitReservation,

                                  style: ElevatedButton.styleFrom(

                                    backgroundColor: AppTheme.primaryColor,

                                    foregroundColor: Colors.white,

                                    elevation: 2,

                                    shadowColor: AppTheme.primaryColor.withValues(

                                      alpha: 0.3,

                                    ),

                                    shape: RoundedRectangleBorder(

                                      borderRadius: BorderRadius.circular(30),

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

                                      : const Row(

                                          mainAxisAlignment:

                                              MainAxisAlignment.center,

                                          children: [

                                            Text(

                                              'Confirm Reservation',

                                              style: TextStyle(

                                                fontSize: 16,

                                                fontWeight: FontWeight.bold,

                                                letterSpacing: 0.5,

                                              ),

                                            ),

                                            SizedBox(width: 8),

                                            Icon(

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

            const SizedBox(height: 32),

          ],

        ),

      ),

    );

  }



  Widget _buildFormLabel(String label) {

    return Text(

      label,

      style: const TextStyle(

        fontSize: 11,

        letterSpacing: 1.2,

        fontWeight: FontWeight.w600,

        color: Color(0xFF6B6B6B),

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

  }) {

    return TextFormField(

      controller: controller,

      readOnly: readOnly,

      onTap: onTap,

      keyboardType: keyboardType,

      inputFormatters: inputFormatters,

      decoration: InputDecoration(

        hintText: hint,

        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),

        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),

        filled: true,

        fillColor: Colors.grey.shade100,

        contentPadding: const EdgeInsets.symmetric(

          horizontal: 16,

          vertical: 16,

        ),

        border: OutlineInputBorder(

          borderRadius: BorderRadius.circular(12),

          borderSide: BorderSide.none,

        ),

        enabledBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(12),

          borderSide: BorderSide.none,

        ),

        focusedBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(12),

          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),

        ),

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

      decoration: InputDecoration(

        hintText: hint,

        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),

        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),

        filled: true,

        fillColor: Colors.grey.shade100,

        contentPadding: const EdgeInsets.symmetric(

          horizontal: 16,

          vertical: 16,

        ),

        border: OutlineInputBorder(

          borderRadius: BorderRadius.circular(12),

          borderSide: BorderSide.none,

        ),

        enabledBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(12),

          borderSide: BorderSide.none,

        ),

        focusedBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(12),

          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),

        ),

        suffixIcon: Icon(

          Icons.keyboard_arrow_down_rounded,

          color: Colors.grey.shade600,

        ),

      ),

      icon: const SizedBox.shrink(), // hide default arrow

      items: items

          .map(

            (item) => DropdownMenuItem(

              value: item,

              child: Text(

                item,

                style: const TextStyle(fontSize: 14, color: Color(0xFF1D1B1E)),

              ),

            ),

          )

          .toList(),

      onChanged: onChanged,

    );

  }



  Widget _buildProfileSection() {

    final currentUser = Supabase.instance.client.auth.currentUser;

    final name =

        currentUser?.userMetadata?['full_name']?.replaceAll('User', '') ??

        currentUser?.userMetadata?['name']?.replaceAll('User', '') ??

        'Customer';

    final email = currentUser?.email ?? 'Not provided';

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';



    return SingleChildScrollView(

      physics: const AlwaysScrollableScrollPhysics(),

      child: Padding(

        padding: const EdgeInsets.symmetric(horizontal: 24),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const SizedBox(height: 32),



            // Profile Header Row

            Row(

              children: [

                Container(

                  width: 72,

                  height: 72,

                  decoration: BoxDecoration(

                    color: const Color(0xFFFFB4AB),

                    shape: BoxShape.circle,

                    boxShadow: [

                      BoxShadow(

                        color: Colors.black.withValues(alpha: 0.08),

                        blurRadius: 12,

                        offset: const Offset(0, 4),

                      ),

                    ],

                    image: currentUser?.userMetadata?['avatar_url'] != null

                        ? DecorationImage(

                            image: NetworkImage(

                              currentUser!.userMetadata!['avatar_url'],

                            ),

                            fit: BoxFit.cover,

                          )

                        : null,

                  ),

                  child: currentUser?.userMetadata?['avatar_url'] == null

                      ? Center(

                          child: Text(

                            initial,

                            style: const TextStyle(

                              fontSize: 28,

                              fontWeight: FontWeight.bold,

                              color: Color(0xFF1D1B1E),

                            ),

                          ),

                        )

                      : null,

                ),

                const SizedBox(width: 20),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        name,

                        style: const TextStyle(

                          fontSize: 20,

                          fontWeight: FontWeight.bold,

                          color: Color(0xFF1D1B1E),

                        ),

                      ),

                      const SizedBox(height: 4),

                      Text(

                        email,

                        style: TextStyle(

                          fontSize: 13,

                          color: Colors.grey.shade600,

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),



            const SizedBox(height: 36),



            // Menu Cards

            _buildAccountMenuCard(

              icon: Icons.person_outline_rounded,

              title: 'Edit Profile',

              subtitle: 'Details about your account',

              onTap: () async {

                await Navigator.of(context).push(

                  MaterialPageRoute(builder: (_) => const EditProfilePage()),

                );

                if (mounted) {

                  setState(() {});

                }

              },

            ),

            _buildAccountMenuCard(

              icon: Icons.history_edu_rounded,

              title: 'Activity History',

              subtitle: 'View your past and ongoing activities',

              onTap: _showHistoryPage,

            ),

            _buildAccountMenuCard(

              icon: Icons.logout_rounded,

              title: 'Logout',

              subtitle: 'Securely exit your session',

              isDestructive: true,

              onTap: _showLogoutDialog,

            ),



            const SizedBox(height: 24),

          ],

        ),

      ),

    );

  }



  void _showHistoryPage() {

    Navigator.of(context).push(

      MaterialPageRoute(

        builder: (context) => Scaffold(

          backgroundColor: const Color(0xFFF9F9FF),

          appBar: AppBar(

            backgroundColor: const Color(0xFFF9F9FF),

            elevation: 0,

            scrolledUnderElevation: 0,

            leading: IconButton(

              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1D1B1E)),

              onPressed: () => Navigator.of(context).pop(),

            ),

            title: const Text(

              'Activity History',

              style: TextStyle(

                color: Color(0xFF1D1B1E),

                fontWeight: FontWeight.bold,

                fontSize: 18,

              ),

            ),

          ),

          body: customerReservations.isEmpty

              ? Center(

                  child: Column(

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [

                      Icon(

                        Icons.history_edu_rounded,

                        size: 64,

                        color: Colors.grey.shade300,

                      ),

                      const SizedBox(height: 16),

                      Text(

                        'No activities found',

                        style: TextStyle(

                          fontSize: 16,

                          color: Colors.grey.shade600,

                        ),

                      ),

                    ],

                  ),

                )

              : ListView.builder(

                  padding: const EdgeInsets.all(16),

                  itemCount: customerReservations.length,

                  itemBuilder: (context, index) {

                    final reservation = customerReservations[index];

                    return _buildHistoryItem(reservation);

                  },

                ),

        ),

      ),

    );

  }



  Widget _buildHistoryItem(Map<String, dynamic> reservation) {

    return Card(

      margin: const EdgeInsets.only(bottom: 16),

      shape: RoundedRectangleBorder(

        borderRadius: BorderRadius.circular(12),

        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),

      ),

      elevation: 0,

      child: Padding(

        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                Expanded(

                  child: Text(

                    reservation['event_type'] ?? 'Reservation',

                    style: const TextStyle(

                      fontSize: 18,

                      fontWeight: FontWeight.bold,

                    ),

                  ),

                ),

                _buildStatusChip(reservation['status']),

              ],

            ),

            const SizedBox(height: 12),

            Row(

              children: [

                Icon(

                  Icons.calendar_today_rounded,

                  size: 16,

                  color: Colors.grey.shade600,

                ),

                const SizedBox(width: 8),

                Text(

                  'Date: ${reservation['event_date']}',

                  style: TextStyle(color: Colors.grey.shade700),

                ),

              ],

            ),

            const SizedBox(height: 4),

            Row(

              children: [

                Icon(

                  Icons.access_time_rounded,

                  size: 16,

                  color: Colors.grey.shade600,

                ),

                const SizedBox(width: 8),

                Text(

                  'Time: ${reservation['start_time']} (${reservation['duration_hours']}h)',

                  style: TextStyle(color: Colors.grey.shade700),

                ),

              ],

            ),

            const SizedBox(height: 4),

            Row(

              children: [

                Icon(

                  Icons.people_alt_rounded,

                  size: 16,

                  color: Colors.grey.shade600,

                ),

                const SizedBox(width: 8),

                Text(

                  'Guests: ${reservation['number_of_guests']}',

                  style: TextStyle(color: Colors.grey.shade700),

                ),

              ],

            ),

            const Divider(height: 24),

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      'Transaction Status',

                      style: TextStyle(

                        fontSize: 12,

                        color: Colors.grey.shade500,

                      ),

                    ),

                    Text(

                      reservation['payment_status']?.toUpperCase() ?? 'NONE',

                      style: TextStyle(

                        fontSize: 14,

                        fontWeight: FontWeight.bold,

                        color: reservation['payment_status'] == 'paid'

                            ? Colors.green

                            : Colors.orange,

                      ),

                    ),

                  ],

                ),

                Text(

                  'Booked on ${reservation['created_at']?.toString().split('T')[0] ?? 'N/A'}',

                  style: TextStyle(

                    fontSize: 11,

                    color: Colors.grey.shade400,

                    fontStyle: FontStyle.italic,

                  ),

                ),

              ],

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildAccountMenuCard({

    required IconData icon,

    required String title,

    String? subtitle,

    required VoidCallback onTap,

    bool isDestructive = false,

  }) {

    final color = isDestructive

        ? const Color(0xFFBA1A1A)

        : const Color(0xFF1D1B1E);

    final iconBgColor = isDestructive

        ? const Color(0xFFFFDAD6).withValues(alpha: 0.5)

        : const Color(0xFFFFDAD6);



    return Container(

      margin: const EdgeInsets.only(bottom: 16),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.03),

            blurRadius: 20,

            offset: const Offset(0, 8),

          ),

        ],

      ),

      child: Material(

        color: Colors.transparent,

        child: InkWell(

          onTap: onTap,

          borderRadius: BorderRadius.circular(20),

          child: Padding(

            padding: const EdgeInsets.all(20),

            child: Row(

              children: [

                Container(

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(

                    color: iconBgColor,

                    borderRadius: BorderRadius.circular(16),

                  ),

                  child: Icon(icon, color: color, size: 24),

                ),

                const SizedBox(width: 20),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        title,

                        style: TextStyle(

                          fontSize: 16,

                          fontWeight: FontWeight.bold,

                          color: color,

                        ),

                      ),

                      if (subtitle != null) ...[

                        const SizedBox(height: 4),

                        Text(

                          subtitle,

                          style: TextStyle(

                            fontSize: 13,

                            color: Colors.grey.shade500,

                          ),

                        ),

                      ],

                    ],

                  ),

                ),

                Icon(

                  Icons.chevron_right_rounded,

                  color: Colors.grey.shade400,

                  size: 24,

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



      child: Card(

        child: Padding(

          padding: const EdgeInsets.all(16.0),



          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,



            children: [

              const Text(

                'Reservation Activity',



                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),

              ),



              const SizedBox(height: 20),



              if (customerReservations.isEmpty)

                Container(

                  padding: const EdgeInsets.symmetric(vertical: 40),



                  child: Center(

                    child: Column(

                      mainAxisAlignment: MainAxisAlignment.center,



                      children: [

                        const Icon(

                          Icons.assignment_outlined,

                          size: 64,

                          color: Colors.grey,

                        ),



                        const SizedBox(height: 16),



                        const Text(

                          'No reservation activity',



                          style: TextStyle(fontSize: 16, color: Colors.grey),

                        ),



                        const SizedBox(height: 8),



                        const Text(

                          'Make your first reservation to see your activity here!',



                          style: TextStyle(fontSize: 14),

                        ),

                      ],

                    ),

                  ),

                )

              else

                ListView.builder(

                  shrinkWrap: true,



                  physics: const NeverScrollableScrollPhysics(),



                  itemCount: customerReservations.length,



                  itemBuilder: (context, index) {

                    final reservation = customerReservations[index];



                    return Card(

                      margin: const EdgeInsets.only(bottom: 12),



                      child: Padding(

                        padding: const EdgeInsets.all(16.0),



                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,



                          children: [

                            Row(

                              mainAxisAlignment: MainAxisAlignment.spaceBetween,



                              children: [

                                Expanded(

                                  child: Text(

                                    reservation['event_type'],



                                    style: const TextStyle(

                                      fontSize: 16,



                                      fontWeight: FontWeight.bold,

                                    ),

                                  ),

                                ),



                                Row(

                                  children: [

                                    _buildStatusChip(reservation['status']),

                                    const SizedBox(width: 8),



                                    // Show payment button for confirmed but unpaid reservations

                                    if (reservation['status'] == 'confirmed' &&

                                        reservation['payment_status'] != 'paid')

                                      IconButton(

                                        onPressed: () =>

                                            _showPaymentDialog(reservation),



                                        icon: const Icon(

                                          Icons.payment,

                                          color: Colors.green,

                                          size: 20,

                                        ),



                                        tooltip: 'Pay Reservation Fee',

                                      ),



                                    // Show payment status for paid reservations

                                    if (reservation['payment_status'] == 'paid')

                                      Container(

                                        padding: const EdgeInsets.symmetric(

                                          horizontal: 8,

                                          vertical: 4,

                                        ),



                                        decoration: BoxDecoration(

                                          color: Colors.green.withValues(

                                            alpha: 0.1,

                                          ),



                                          borderRadius: BorderRadius.circular(

                                            12,

                                          ),

                                        ),



                                        child: const Text(

                                          'PAID',



                                          style: TextStyle(

                                            color: Colors.green,



                                            fontSize: 10,



                                            fontWeight: FontWeight.w600,

                                          ),

                                        ),

                                      ),



                                    const SizedBox(width: 8),



                                    // Confirmed: Cancel or Reschedule

                                    if (reservation['status'] == 'confirmed' ||

                                        reservation['status'] == 'pending')

                                      PopupMenuButton<String>(

                                        onSelected: (String value) {

                                          if (value == 'cancel') {

                                            _showCancellationDialog(

                                              reservation,

                                            );

                                          } else if (value == 'reschedule') {

                                            _showRescheduleDialog(reservation);

                                          }

                                        },

                                        itemBuilder: (BuildContext context) => [

                                          const PopupMenuItem<String>(

                                            value: 'cancel',

                                            child: Row(

                                              children: [

                                                Icon(

                                                  Icons.close,

                                                  color: Colors.red,

                                                  size: 18,

                                                ),

                                                SizedBox(width: 8),

                                                Text('Cancel Reservation'),

                                              ],

                                            ),

                                          ),

                                          const PopupMenuItem<String>(

                                            value: 'reschedule',

                                            child: Row(

                                              children: [

                                                Icon(

                                                  Icons.edit_calendar,

                                                  color: Colors.blue,

                                                  size: 18,

                                                ),

                                                SizedBox(width: 8),

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



                            const SizedBox(height: 8),



                            Text('Date: ${reservation['event_date']}'),



                            Text('Time: ${reservation['start_time']}'),



                            Text(

                              'Duration: ${reservation['duration_hours']} hours',

                            ),



                            Text('Guests: ${reservation['number_of_guests']}'),



                            const SizedBox(height: 8),



                            Text(

                              'Booked on: ${_formatLocalDateTime(reservation['created_at'])}',



                              style: TextStyle(

                                color: Colors.grey.shade600,



                                fontSize: 12,

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

      ),

    );

  }



  Widget _buildStatusChip(String status) {

    Color color;



    IconData icon;



    switch (status) {

      case 'pending':

        color = Colors.orange;



        icon = Icons.pending;



        break;



      case 'confirmed':

        color = Colors.green;



        icon = Icons.check_circle;



        break;



      case 'cancelled':

        color = Colors.red;



        icon = Icons.cancel;



        break;



      default:

        color = Colors.grey;



        icon = Icons.help;

    }



    return Chip(

      label: Text(status.toUpperCase()),



      backgroundColor: color.withValues(alpha: 0.1),



      labelStyle: TextStyle(

        color: color,



        fontWeight: FontWeight.bold,



        fontSize: 10,

      ),



      avatar: Icon(icon, size: 14, color: color),

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



        // Cancel the reservation

        await _reservationService.cancelReservation(

          reservationId: reservation['id'],

          customerEmail: currentUser.email!,

          customerName: currentUser.userMetadata?['name'] ?? 'Customer',

          eventType: eventType,

          eventDate: eventDate,

          cancellationReason: selectedReason!,

          isAdminCancel: false,

        );



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

                            "${picked.month}/${picked.day}/${picked.year}";

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



  void _submitReservation() async {

    String date = _dateController.text.trim();

    String startTime = _startTimeController.text.trim();

    String guests = _guestsController.text.trim();



    // Validation

    if (_selectedEventType == null) {

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

    if (_selectedBaseDuration == null) {

      _showSnackBar('Please select a base duration', Colors.red);

      return;

    }

    if (guests.isEmpty) {

      _showSnackBar('Please enter the number of guests', Colors.red);

      return;

    }



    int guestCount = int.tryParse(guests) ?? 0;

    if (guestCount < _minGuestCount || guestCount > _maxGuestCount) {

      _showSnackBar(

        'Number of guests must be between $_minGuestCount and $_maxGuestCount',

        Colors.red,

      );

      return;

    }



    double totalDuration = double.tryParse(_durationController.text) ?? 0.0;

    if (totalDuration == 0) {

      _showSnackBar('Invalid duration selected', Colors.red);

      return;

    }



    // Parse date string to proper format

    List<String> dateParts = date.split('/');

    if (dateParts.length != 3) {

      _showSnackBar('Invalid date format', Colors.red);

      return;

    }

    String formattedDate =

        "${dateParts[2]}-${dateParts[0].padLeft(2, '0')}-${dateParts[1].padLeft(2, '0')}";



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

      // Parse date string to proper format



      List<String> dateParts = date.split('/');



      if (dateParts.length != 3) {

        throw Exception('Invalid date format');

      }



      String formattedDate =

          "${dateParts[2]}-${dateParts[0].padLeft(2, '0')}-${dateParts[1].padLeft(2, '0')}";



      // Create reservation using the new reservation service

      await _createReservationWithoutPayment(

        currentUser,

        _selectedEventType!,

        formattedDate,

        startTime,

        totalDuration,

        guestCount,

        _specialRequestsController.text.trim(),

      );

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



  Future<void> _createReservationWithoutPayment(

    User currentUser,

    String event,

    String formattedDate,

    String startTime,

    num duration,

    int guests,

    String specialRequests,

  ) async {

    try {

      // Save reservation to database with PENDING status

      final result = await Supabase.instance.client

          .from('reservations')

          .insert({

            'customer_email': currentUser.email,



            'customer_name': currentUser.userMetadata?['name'] ?? 'Customer',



            'event_type': event,



            'event_date': formattedDate,



            'start_time': startTime,



            'duration_hours': duration.toInt(),



            'number_of_guests': guests,



            'special_requests': specialRequests.isNotEmpty

                ? specialRequests

                : null,



            'status': 'pending', // Pending admin confirmation



            'payment_status': 'unpaid', // No payment yet



            'created_at': DateTime.now().toIso8601String(),

          })

          .select()

          .single();



      // Send notification to customer using email service

      await _emailService.sendReservationConfirmation(

        customerEmail: currentUser.email!,

        customerName: currentUser.userMetadata?['name'] ?? 'Customer',

        eventType: event,

        eventDate: formattedDate,

        startTime: startTime,

        duration: duration.toDouble(),

        guests: guests,

      );



      // Send notification to customer in-app

      await NotificationService.sendNotification(

        recipientEmail: currentUser.email,

        actorName: 'System',

        actionType: 'created',

        reservationId: result['id'] ?? '',

        eventType: event,

        eventDate: formattedDate,

        startTime: startTime,

        guestCount: guests,

      );



      // Send notification to admins (with customer context)

      await NotificationService.sendNotification(

        isForAdmin: true,

        actorName: currentUser.userMetadata?['name'] ?? 'Customer',

        actionType: 'created',

        reservationId: result['id'] ?? '',

        eventType: event,

        eventDate: formattedDate,

        customerEmail: currentUser.email,

        startTime: startTime,

        guestCount: guests,

      );



      if (!mounted) return;



      // Show success message



      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: const Row(

            children: [

              Icon(Icons.check_circle_outline, color: Colors.white),



              SizedBox(width: 12),



              Expanded(

                child: Text(

                  'Reservation submitted successfully! Waiting for admin confirmation.',

                ),

              ),

            ],

          ),



          backgroundColor: Colors.green,



          behavior: SnackBarBehavior.floating,



          shape: const RoundedRectangleBorder(

            borderRadius: BorderRadius.all(Radius.circular(10)),

          ),



          margin: const EdgeInsets.all(16),



          duration: const Duration(seconds: 4),

        ),

      );



      // Clear form

      _eventController.clear();

      _dateController.clear();

      _startTimeController.clear();

      _durationController.clear();

      _guestsController.clear();



      setState(() {

        _selectedEventType = null;

        _selectedBaseDuration = null;

        _addExtraTime = false;

        _selectedExtraTime = null;

      });



      // Refresh reservations list



      _loadCustomerReservations();



      setState(() => _isLoading = false);

    } catch (e) {

      if (!mounted) return;



      setState(() => _isLoading = false);



      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Row(

            children: [

              const Icon(Icons.error_outline, color: Colors.white),



              const SizedBox(width: 12),



              Expanded(

                child: Text('Error creating reservation: ${e.toString()}'),

              ),

            ],

          ),



          backgroundColor: Colors.red,



          behavior: SnackBarBehavior.floating,

        ),

      );

    }

  }



  // Add payment button for confirmed reservations



  void _showPaymentDialog(Map<String, dynamic> reservation) async {

    // Calculate reservation fee



    double reservationFee =

        500.0 + (50.0 * (reservation['number_of_guests'] ?? 1));



    bool? shouldProceed = await showDialog<bool>(

      context: context,



      builder: (context) => AlertDialog(

        title: const Text('Pay Reservation Fee'),



        content: Column(

          mainAxisSize: MainAxisSize.min,



          crossAxisAlignment: CrossAxisAlignment.start,



          children: [

            Text(

              'Your reservation has been confirmed!',



              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),

            ),



            const SizedBox(height: 12),



            Text(

              'A payment of ₱${reservationFee.toStringAsFixed(2)} is required to complete your booking.',



              style: const TextStyle(fontSize: 14),

            ),



            const SizedBox(height: 8),



            Text(

              'Event: ${reservation['event_type']}',



              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),

            ),



            Text(

              'Date: ${reservation['event_date']} at ${reservation['start_time']}',



              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),

            ),

          ],

        ),



        actions: [

          TextButton(

            onPressed: () => Navigator.of(context).pop(false),



            child: const Text('Cancel'),

          ),



          ElevatedButton(

            onPressed: () => Navigator.of(context).pop(true),



            style: ElevatedButton.styleFrom(

              backgroundColor: AppTheme.primaryColor,



              foregroundColor: Colors.white,

            ),



            child: const Text('Pay Now'),

          ),

        ],

      ),

    );



    if (shouldProceed == true && mounted) {

      // Navigate to payment page

      await Navigator.of(context).push(

        MaterialPageRoute(

          builder: (context) => PaymentPage(

            amount: reservationFee,



            description:

                'Reservation for ${reservation['event_type']} on ${reservation['event_date']}',



            metadata: {

              'reservation_id': reservation['id'],



              'event_type': reservation['event_type'],



              'event_date': reservation['event_date'],



              'start_time': reservation['start_time'],



              'number_of_guests': reservation['number_of_guests'],



              'customer_email': reservation['customer_email'],

            },



            onPaymentComplete: (success, result) {

              if (success) {

                _updateReservationPayment(

                  reservation['id'],

                  result?['payment_method'] ?? 'unknown',

                  reservationFee,

                );

              }

            },

          ),

        ),

      );

    }

  }



  Future<void> _updateReservationPayment(

    String reservationId,

    String paymentMethod,

    double amount,

  ) async {

    try {

      await Supabase.instance.client

          .from('reservations')

          .update({

            'payment_method': paymentMethod,

            'payment_status': 'paid',

            'payment_amount': amount,

            'payment_date': DateTime.now().toIso8601String(),

            'transaction_id': PayMongoService.generateReferenceNumber(),

          })

          .eq('id', reservationId);



      // Send notifications for payment

      final currentUser = Supabase.instance.client.auth.currentUser;

      final reservation = customerReservations.firstWhere(

        (r) => r['id'] == reservationId,

        orElse: () => {},

      );

      if (currentUser != null && reservation.isNotEmpty) {

        await NotificationService.sendNotification(

          recipientEmail: currentUser.email,

          actorName: 'System',

          actionType: 'paid',

          reservationId: reservationId,

          eventType: reservation['event_type'],

          eventDate: reservation['event_date'],

          customerEmail: currentUser.email,

        );

      }



      if (!mounted) return;



      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Row(

            children: [

              Icon(Icons.check_circle_outline, color: Colors.white),



              SizedBox(width: 12),



              Expanded(

                child: Text(

                  'Payment successful! Your reservation is fully confirmed.',

                ),

              ),

            ],

          ),



          backgroundColor: Colors.green,



          behavior: SnackBarBehavior.floating,

        ),

      );



      _loadCustomerReservations();

    } catch (e) {

      if (!mounted) return;



      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Row(

            children: [

              const Icon(Icons.error_outline, color: Colors.white),



              const SizedBox(width: 12),



              Expanded(child: Text('Error updating payment: ${e.toString()}')),

            ],

          ),



          backgroundColor: Colors.red,



          behavior: SnackBarBehavior.floating,

        ),

      );

    }

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

                Navigator.of(context).pushAndRemoveUntil(

                  MaterialPageRoute(builder: (context) => const LoginPage()),



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

