import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:yang_chow/utils/app_theme.dart';

import 'package:yang_chow/utils/app_constants.dart';

import 'package:yang_chow/utils/responsive_utils.dart';

import 'package:yang_chow/pages/login_page.dart';

import 'package:yang_chow/pages/customer/edit_profile_page.dart';
import 'package:yang_chow/pages/customer/customer_chat_page.dart';

import 'package:yang_chow/pages/customer/gcash_payment_page.dart';

import 'package:yang_chow/services/notification_service.dart';
import 'package:yang_chow/services/app_settings_service.dart';
import 'package:yang_chow/services/reservation_service.dart';

import 'package:yang_chow/services/menu_service.dart';

import 'package:intl/intl.dart';

import 'package:flutter/foundation.dart' show kIsWeb;



class CustomerDashboardPage extends StatefulWidget {

  const CustomerDashboardPage({super.key});



  @override

  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();

}



class _CustomerDashboardPageState extends State<CustomerDashboardPage> {

  int _selectedIndex = 0;
  bool _isLoading = false;
  final ReservationService _reservationService = ReservationService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '58922100698-jmttb6okfltmpcco2f2rrh8rmppappk6.apps.googleusercontent.com' // Web Client ID
        : '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com', // Android Client ID
  );

  List<Map<String, dynamic>> customerReservations = [];
  Stream<List<Map<String, dynamic>>>? _notificationsStream;
  String? _lastSeenNotificationId;




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



  // New state variables for form improvements

  String? _selectedEventType;

  String? _selectedBaseDuration;

  bool _addExtraTime = false;

  String? _selectedExtraTime;



  final List<String> _eventTypes = AppConstants.eventTypes;







  @override

  void initState() {

    super.initState();

    _appSettings = AppSettingsService();
    // Initialize configuration from app_settings






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

              ...List.generate(6, (index) {

                final icons = [
                  Icons.home_rounded,
                  Icons.event_available_rounded,
                  Icons.chat_bubble_rounded,

                  Icons.monetization_on_rounded,

                  Icons.assignment_rounded,
                  Icons.person_rounded,
                ];



                final labels = ['Home', 'Reservations', 'Chat', 'Quotations', 'Activity', 'Account'];



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

                    child: _buildMobileNavItem(3, Icons.monetization_on_rounded, 'Quotations'),

                  ),



                  Expanded(

                    child: _buildMobileNavItem(4, Icons.assignment_rounded, 'Activity'),

                  ),
                  Expanded(

                    child: _buildMobileNavItem(5, Icons.person_rounded, 'Account'),

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

  Widget _buildQuickActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isPrimary ? AppTheme.primaryColor : Colors.white,
        border: isPrimary ? null : Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isPrimary ? Colors.white : Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isPrimary ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                        'Welcome to Yang Chow, ${_getUserDisplayName()}!',



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



          _buildHomeMenuSection(),
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
                      child: _buildQuickActionButton(
                        onTap: () => setState(() => _selectedIndex = 1),
                        icon: Icons.add,
                        label: 'Make a New Reservation',
                        isPrimary: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        onTap: () => setState(() => _selectedIndex = 4),
                        icon: Icons.person_outline,
                        label: 'My Account',
                        isPrimary: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

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
    final name = _getUserDisplayName();
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

                  MaterialPageRoute(builder: (_) => EditProfilePage()),

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



  Widget _buildHomeMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Our Menu',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 3),
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: MenuService.categories.length,
            itemBuilder: (context, index) {
              final category = MenuService.categories[index];
              return _buildMenuCategoryCard(category);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCategoryCard(String category) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = 3;
        });
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDAD6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_menu, color: Color(0xFF1D1B1E), size: 20),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                category,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _proceedToGCashPayment(Map<String, dynamic> reservation, double depositAmount) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GCashPaymentPage(
          reservationId: reservation['id'],
          depositAmount: depositAmount,
          onPaymentSuccess: () {
            _updateReservationPaymentStatus(reservation['id'], depositAmount);
          },
        ),
      ),
    );
  }

  Future<void> _proceedToQRPayment(Map<String, dynamic> reservation, double depositAmount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
              // Full screen QR code
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.width * 0.85,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // QR Code takes most of the space
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Image.asset(
                            'assets/images/newgcash.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // Amount and info at bottom
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Column(
                            children: [
                              Text(
                                'Amount: PHP ${depositAmount.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Reference: YANG${DateTime.now().millisecondsSinceEpoch}',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 50,
                right: 20,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
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

  Future<void> _updateReservationPaymentStatus(String reservationId, double depositAmount) async {
    try {
      await _reservationService.updatePaymentStatus(
        reservationId: reservationId,
        paymentStatus: 'deposit_paid',
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
      
      if (!mounted) return;
      _loadCustomerReservations();
      setState(() => _selectedIndex = 0);
    } catch (e) {
      _showErrorDialog('Failed to create reservation: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildHistoryItem(Map<String, dynamic> reservation) {
    final needsDepositPayment = _reservationService.needsDepositPayment(reservation);
    final pricingInfo = _reservationService.getReservationPricing(reservation);
    final totalPrice = pricingInfo['totalPrice'] as double;
    final depositAmount = pricingInfo['depositAmount'] as double;
    final paymentStatus = reservation['payment_status'] as String? ?? 'unpaid';
    final priceQuotationSent = reservation['price_quotation_sent'] == true;

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
                _buildStatusChip(reservation['status'] ?? 'pending'),
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
            
            if (priceQuotationSent && totalPrice > 0) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.monetization_on, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        const Text(
                          'Pricing Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Price:'),
                        Text(
                          'PHP ${totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Deposit (50%):'),
                        Text(
                          'PHP ${depositAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Remaining Balance:'),
                        Text(
                          'PHP ${(totalPrice - depositAmount).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Status',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      _getPaymentStatusText(paymentStatus, priceQuotationSent),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getPaymentStatusColor(paymentStatus, priceQuotationSent),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Booked on ${_formatLocalDateTime(reservation['created_at'])}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            
            if (needsDepositPayment) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentDialog(reservation),
                  icon: const Icon(Icons.payment, size: 18),
                  label: Text('Pay Deposit (PHP ${depositAmount.toStringAsFixed(2)})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else if (paymentStatus == 'deposit_paid') ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Deposit paid! Awaiting admin approval.',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!priceQuotationSent && (reservation['status'] == 'pending' || reservation['status'] == 'pending_quotation')) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Awaiting price quotation from admin.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getPaymentStatusText(String status, bool isQuoted) {
    if (!isQuoted) return 'AWAITING QUOTATION';
    switch (status) {
      case 'deposit_paid': return 'DEPOSIT PAID';
      case 'paid': return 'FULLY PAID';
      case 'unpaid': return 'DEPOSIT DUE';
      case 'refunded': return 'REFUNDED';
      default: return status.toUpperCase();
    }
  }

  Color _getPaymentStatusColor(String status, bool isQuoted) {
    if (!isQuoted) return Colors.orange;
    switch (status) {
      case 'deposit_paid': return Colors.green;
      case 'paid': return Colors.blue;
      case 'unpaid': return Colors.orange;
      case 'refunded': return Colors.red;
      default: return Colors.grey;
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
              'Complete your reservation by paying the 50% deposit.',
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
                  const Text(
                    'Deposit Amount:',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
            const Text(
              'Choose your preferred payment method:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _proceedToGCashPayment(reservation, depositAmount);
                },
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('Pay with GCash'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _proceedToQRPayment(reservation, depositAmount);
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Pay with GCash QR'),
                style: OutlinedButton.styleFrom(
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
      final dt = dateTime is String ? DateTime.parse(dateTime).toLocal() : (dateTime as DateTime).toLocal();
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
                    color: isDestructive ? Colors.red.shade50 : Colors.grey.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive ? Colors.red.shade600 : Colors.grey.shade700,
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
                          color: isDestructive ? Colors.red.shade600 : const Color(0xFF1D1B1E),
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

  Widget _buildQuotationsSection() {
    final quotations = customerReservations.where((reservation) {
      return reservation['price_quotation_sent'] == true && 
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
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> reservation) {
    final totalPrice = reservation['total_price'] as double;
    final depositAmount = reservation['deposit_amount'] as double;
    final paymentStatus = reservation['payment_status'] as String? ?? 'unpaid';
    final needsDepositPayment = _reservationService.needsDepositPayment(reservation);

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
                    child: Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 20),
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
                      color: _getPaymentStatusColor(paymentStatus, true).withValues(alpha: 0.1),
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
                    _buildQuotationDetailRow('Date', reservation['event_date'] ?? 'N/A', Icons.calendar_today),
                    _buildQuotationDetailRow('Time', '${reservation['start_time']} (${reservation['duration_hours']}h)', Icons.access_time),
                    _buildQuotationDetailRow('Guests', '${reservation['number_of_guests']} people', Icons.people),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // Pricing Breakdown
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.monetization_on, color: AppTheme.successGreen, size: 16),
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
                    _buildPricingRow('Deposit (50%)', depositAmount, AppTheme.successGreen),
                    _buildPricingRow('Remaining Balance', totalPrice - depositAmount, Colors.grey),
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
                    label: Text('Pay Deposit (PHP ${depositAmount.toStringAsFixed(2)})'),
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
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions, color: Colors.orange, size: 20),
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
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions, color: Colors.orange, size: 20),
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
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRow(String label, double amount, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
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

