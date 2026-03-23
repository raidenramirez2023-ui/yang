import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:yang_chow/utils/app_theme.dart';

import 'package:yang_chow/utils/responsive_utils.dart';

import 'package:yang_chow/pages/login_page.dart';

import 'package:yang_chow/pages/payment_page.dart';

import 'package:yang_chow/pages/edit_profile_page.dart';

import 'package:yang_chow/services/paymongo_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb;



class CustomerDashboardPage extends StatefulWidget {

  const CustomerDashboardPage({super.key});



  @override

  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();

}



class _CustomerDashboardPageState extends State<CustomerDashboardPage> {

  int _selectedIndex = 0;
  bool _hasUnreadNotifications = false; // Off by default

  List<Map<String, dynamic>> customerReservations = [];

  bool _isLoading = false;



  // Form controllers

  final TextEditingController _eventController = TextEditingController();

  final TextEditingController _dateController = TextEditingController();

  final TextEditingController _startTimeController = TextEditingController();

  final TextEditingController _durationController = TextEditingController();

  final TextEditingController _guestsController = TextEditingController();
  
  // New state variables for form improvements
  String? _selectedEventType;
  String? _selectedBaseDuration;
  bool _addExtraTime = false;
  String? _selectedExtraTime;

  final List<String> _eventTypes = ['Birthday Party', 'Wedding', 'Meeting'];
  final List<String> _baseDurations = ['2 hours', '3 hours'];
  final List<String> _extraTimeOptions = [
    '30 minutes',
    '1 hour',
    '1 hour 30 minutes',
    '2 hours'
  ];



  // Google Sign-In instance

  final GoogleSignIn _googleSignIn = GoogleSignIn(

    clientId: kIsWeb 

      ? '58922100698-jmttb6okfltmpcco2f2rrh8rmppappk6.apps.googleusercontent.com' // Web Client ID

      : '58922100698-ajm1bssqvgoo9k0qs15hd3g7nhrqabm4.apps.googleusercontent.com', // Android Client ID

  );



  @override

  void initState() {

    super.initState();

    _loadCustomerReservations();

    // Set up periodic refresh

    Timer.periodic(const Duration(seconds: 10), (timer) {

      if (mounted) {

        _loadCustomerReservations();

      }

    });

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

      // Detection for status changes (e.g. pending -> confirmed)
      bool shouldNotify = false;
      if (customerReservations.isNotEmpty) {
        for (var res in newReservations) {
          final oldRes = customerReservations.firstWhere(
            (o) => o['id'] == res['id'],
            orElse: () => {},
          );
          if (oldRes.isNotEmpty && oldRes['status'] != res['status']) {
            shouldNotify = true;
            break;
          }
        }
      }

      setState(() {
        customerReservations = newReservations;
        if (shouldNotify) _hasUnreadNotifications = true;
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
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
            )
          : _buildDashboardAppBar(_getAppBarTitle()),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),

    );

  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return 'Home';
      case 1: return 'Reservation';
      case 2: return 'History';
      case 3: return 'Account';
      default: return 'Home';
    }
  }

  PreferredSizeWidget _buildDashboardAppBar(String title) {
    return AppBar(
      backgroundColor: const Color(0xFFF9F9FF),
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1D1B1E),
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        _buildNotificationIcon(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1D1B1E)),
          onPressed: _showNotificationsDialog,
          tooltip: 'Notifications',
        ),
        if (_hasUnreadNotifications)
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF9F9FF), width: 2),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationsDialog() {
    setState(() => _hasUnreadNotifications = false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_rounded, color: AppTheme.primaryRed),
            SizedBox(width: 12),
            Text('Notifications'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            const SizedBox(height: 16),
            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No new notifications',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll let you know when the status of your reservation changes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
          ],
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

                        color: AppTheme.primaryRed,

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

              ...List.generate(4, (index) {

                final icons = [

                  Icons.home_rounded,

                  Icons.event_available_rounded,

                  Icons.history_rounded,

                  Icons.person_rounded,

                ];

                final labels = ['Home', 'Reservations', 'History', 'Account'];

                

                return Container(

                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

                  decoration: BoxDecoration(

                    color: _selectedIndex == index ? AppTheme.primaryRed : Colors.transparent,

                    borderRadius: BorderRadius.circular(8),

                  ),

                  child: ListTile(

                    leading: Icon(

                      icons[index],

                      color: _selectedIndex == index ? Colors.white : Colors.grey.shade400,

                    ),

                    title: Text(

                      labels[index],

                      style: TextStyle(

                        color: _selectedIndex == index ? Colors.white : Colors.grey.shade400,

                        fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal,

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

                            icon: const Icon(Icons.logout, color: Color(0xFF1E1E1E)),

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

              color: AppTheme.primaryRed,

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

          padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16, top: 8),

          decoration: BoxDecoration(

            color: const Color(0xFFF5F5F5), // Match background to blend seamlessly

          ),

          child: Container(

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius: BorderRadius.circular(30),

              boxShadow: [

                BoxShadow(

                  color: AppTheme.primaryRed.withValues(alpha: 0.15),

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

                  _buildMobileNavItem(0, Icons.home_rounded, 'Home'),

                  _buildMobileNavItem(1, Icons.event_available_rounded, 'Reserve'),

                  _buildMobileNavItem(2, Icons.history_rounded, 'History'),

                  _buildMobileNavItem(3, Icons.person_rounded, 'Account'),

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

          color: isSelected ? AppTheme.primaryRed.withValues(alpha: 0.1) : Colors.transparent,

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

                            color: AppTheme.primaryRed.withValues(alpha: 0.3),

                            blurRadius: 12,

                            spreadRadius: 2,

                          ),

                        ],

                      ),

                    ),

                  Icon(

                    icon,

                    color: isSelected ? AppTheme.primaryRed : Colors.grey.shade700,

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

                    color: AppTheme.primaryRed,

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

        return _buildHistorySection();

      case 3:

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

              color: AppTheme.primaryRed,

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
                    image: Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'] != null
                        ? DecorationImage(
                            image: NetworkImage(Supabase.instance.client.auth.currentUser!.userMetadata!['avatar_url']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Supabase.instance.client.auth.currentUser?.userMetadata?['avatar_url'] == null
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

          

          // Info Cards

          Row(

            children: [

              Expanded(

                child: Container(

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

                        children: [

                          Icon(

                            Icons.trending_up_rounded,

                            color: Colors.grey.shade600,

                            size: 20,

                          ),

                          const SizedBox(width: 8),

                          Expanded(

                            child: Text(

                              'ACTIVE RESERVATIONS',

                              style: TextStyle(

                                color: Colors.grey.shade600,

                                fontSize: 12,

                                fontWeight: FontWeight.w600,

                              ),

                              overflow: TextOverflow.ellipsis,

                            ),

                          ),

                        ],

                      ),

                      const SizedBox(height: 12),

                      Text(

                        '${customerReservations.where((r) => r['status'] == 'pending' || r['status'] == 'confirmed').length}',

                        style: const TextStyle(

                          fontSize: 32,

                          fontWeight: FontWeight.bold,

                          color: Color(0xFF1E1E1E),

                        ),

                      ),

                    ],

                  ),

                ),

              ),

              const SizedBox(width: 16),

              Expanded(

                child: Container(

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

                        children: [

                          Icon(

                            Icons.insert_chart_rounded,

                            color: Colors.grey.shade600,

                            size: 20,

                          ),

                          const SizedBox(width: 8),

                          Expanded(

                            child: Text(

                              'TOTAL EVENTS',

                              style: TextStyle(

                                color: Colors.grey.shade600,

                                fontSize: 12,

                                fontWeight: FontWeight.w600,

                              ),

                              overflow: TextOverflow.ellipsis,

                            ),

                          ),

                        ],

                      ),

                      const SizedBox(height: 12),

                      Text(

                        '${customerReservations.length}',

                        style: const TextStyle(

                          fontSize: 32,

                          fontWeight: FontWeight.bold,

                          color: Color(0xFF1E1E1E),

                        ),

                      ),

                    ],

                  ),

                ),

              ),

            ],

          ),

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

                          color: AppTheme.primaryRed,

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

                                  Icon(Icons.add, color: Colors.white, size: 20),

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

                          color: AppTheme.primaryRed,

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

                              'Book your first table to start seeing history here.',

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

                                    color: _getStatusColor(reservation['status']).withValues(alpha: 0.1),

                                    borderRadius: BorderRadius.circular(6),

                                  ),

                                  child: Icon(

                                    _getStatusIcon(reservation['status']),

                                    color: _getStatusColor(reservation['status']),

                                    size: 20,

                                  ),

                                ),

                                const SizedBox(width: 12),

                                Expanded(

                                  child: Column(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      Text(

                                        reservation['event_type'] ?? 'Reservation',

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

                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                                  decoration: BoxDecoration(

                                    color: _getStatusColor(reservation['status']).withValues(alpha: 0.1),

                                    borderRadius: BorderRadius.circular(12),

                                  ),

                                  child: Text(

                                    reservation['status']?.toUpperCase() ?? 'PENDING',

                                    style: TextStyle(

                                      color: _getStatusColor(reservation['status']),

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

      child: Card(

        child: Padding(

          padding: const EdgeInsets.all(16.0),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(

                'Event Reservations',

                style: Theme.of(context).textTheme.titleLarge?.copyWith(

                  color: AppTheme.primaryRed,

                  fontWeight: FontWeight.bold,

                ),

              ),

              const SizedBox(height: 20),

              

              // Reservation Form

              Form(

                child: Column(

                  children: [

                    // Event Name

                    Text(

                      'Event Type',

                      style: Theme.of(context).textTheme.titleSmall,

                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedEventType,
                      decoration: InputDecoration(
                        hintText: 'Select event type',
                        prefixIcon: const Icon(Icons.event),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      items: _eventTypes.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedEventType = value;
                          _eventController.text = value ?? '';
                        });
                      },
                    ),

                    const SizedBox(height: 16),



                    // Date

                    Text(

                      'Date',

                      style: Theme.of(context).textTheme.titleSmall,

                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Select date (at least 4 days advance)',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      onTap: () async {
                        final minDate = DateTime.now().add(const Duration(days: 4));
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: minDate,
                          firstDate: minDate,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _dateController.text = "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),



                    // Start Time

                    Text(

                      'Start Time',

                      style: Theme.of(context).textTheme.titleSmall,

                    ),

                    const SizedBox(height: 8),

                    TextField( // Reverted to TextField to match other fields
                      controller: _startTimeController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Select time (10 AM - 4 PM)',
                        prefixIcon: const Icon(Icons.access_time),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      onTap: () async {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (pickedTime != null) {
                          // Validation: 10:00 AM to 4:00 PM (16:00)
                          if (pickedTime.hour < 10 || pickedTime.hour > 16 || (pickedTime.hour == 16 && pickedTime.minute > 0)) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a time between 10:00 AM and 4:00 PM'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }
                          setState(() {
                            _startTimeController.text = pickedTime.format(context);
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),



                    // Duration

                    Text(

                      'Duration (hours)',

                      style: Theme.of(context).textTheme.titleSmall,

                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedBaseDuration,
                      decoration: InputDecoration(
                        hintText: 'Select base duration',
                        prefixIcon: const Icon(Icons.hourglass_empty),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      items: _baseDurations.map((duration) => DropdownMenuItem(
                        value: duration,
                        child: Text(duration),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBaseDuration = value;
                          _updateDurationText();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Add extra time?', style: TextStyle(fontSize: 14)),
                      value: _addExtraTime,
                      activeColor: AppTheme.primaryRed,
                      onChanged: (value) {
                        setState(() {
                          _addExtraTime = value ?? false;
                          if (!_addExtraTime) _selectedExtraTime = null;
                          _updateDurationText();
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_addExtraTime) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedExtraTime,
                        decoration: InputDecoration(
                          hintText: 'Select extra time',
                          prefixIcon: const Icon(Icons.add_alarm),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        items: _extraTimeOptions.map((extra) => DropdownMenuItem(
                          value: extra,
                          child: Text(extra),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedExtraTime = value;
                            _updateDurationText();
                          });
                        },
                      ),
                    ],

                    const SizedBox(height: 16),



                    // Number of Guests

                    Text(

                      'Number of Guests',

                      style: Theme.of(context).textTheme.titleSmall,

                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _guestsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: 'Enter number of guests (10-500)',
                        prefixIcon: const Icon(Icons.people),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),



                    // Submit Button

                    SizedBox(

                      width: double.infinity,

                      child: ElevatedButton(

                        onPressed: _isLoading ? null : _submitReservation,

                        style: ElevatedButton.styleFrom(

                          backgroundColor: AppTheme.primaryRed,

                          foregroundColor: Colors.white,

                          padding: const EdgeInsets.symmetric(vertical: 16),

                        ),

                        child: _isLoading

                          ? const SizedBox(

                              height: 20,

                              width: 20,

                              child: CircularProgressIndicator(

                                strokeWidth: 2,

                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),

                              ),

                            )

                          : const Text('Submit Reservation'),

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



  Widget _buildProfileSection() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final name = currentUser?.userMetadata?['full_name']?.replaceAll('User', '') ??
                 currentUser?.userMetadata?['name']?.replaceAll('User', '') ?? 'Customer';
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
                  MaterialPageRoute(
                    builder: (_) => const EditProfilePage(),
                  ),
                );
                if (mounted) {
                  setState(() {});
                }
              },
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




  Widget _buildAccountMenuCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? const Color(0xFFBA1A1A) : const Color(0xFF1D1B1E);
    final iconBgColor = isDestructive ? const Color(0xFFFFDAD6).withValues(alpha: 0.5) : const Color(0xFFFFDAD6);

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
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
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



  Widget _buildHistorySection() {

    return SingleChildScrollView(

      physics: const AlwaysScrollableScrollPhysics(),

      child: Card(

        child: Padding(

          padding: const EdgeInsets.all(16.0),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              const Text(

                'Reservation History',

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

                          Icons.history_outlined,

                          size: 64,

                          color: Colors.grey,

                        ),

                        const SizedBox(height: 16),

                        const Text(

                          'No reservation history',

                          style: TextStyle(fontSize: 16, color: Colors.grey),

                        ),

                        const SizedBox(height: 8),

                        const Text(

                          'Make your first reservation to see your history here!',

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

                                        if (reservation['status'] == 'confirmed' && reservation['payment_status'] != 'paid')

                                          IconButton(

                                            onPressed: () => _showPaymentDialog(reservation),

                                            icon: const Icon(Icons.payment, color: Colors.green, size: 20),

                                            tooltip: 'Pay Reservation Fee',

                                          ),

                                        // Show payment status for paid reservations

                                        if (reservation['payment_status'] == 'paid')

                                          Container(

                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                                            decoration: BoxDecoration(

                                              color: Colors.green.withValues(alpha: 0.1),

                                              borderRadius: BorderRadius.circular(12),

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

                                        if (reservation['status'] == 'pending')

                                          IconButton(

                                            onPressed: () {

                                              _showDeleteConfirmationDialog(reservation['id'], reservation['event_type']);

                                            },

                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),

                                            tooltip: 'Delete Reservation',

                                          ),

                                      ],

                                    ),

                                  ],

                                ),

                                const SizedBox(height: 8),

                                Text('Date: ${reservation['event_date']}'),

                                Text('Time: ${reservation['start_time']}'),

                                Text('Duration: ${reservation['duration_hours']} hours'),

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



  void _showDeleteConfirmationDialog(String reservationId, String eventType) {

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (context) => AlertDialog(

        shape: RoundedRectangleBorder(

          borderRadius: BorderRadius.circular(12),

        ),

        title: const Row(

          children: [

            Icon(Icons.warning, color: Colors.orange),

            SizedBox(width: 12),

            Text('Delete Reservation'),

          ],

        ),

        content: Column(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(

              'Are you sure you want to delete your "$eventType" reservation?',

              style: const TextStyle(fontSize: 16),

            ),

            const SizedBox(height: 12),

            const Text(

              'This action cannot be undone.',

              style: TextStyle(

                color: Colors.red,

                fontSize: 14,

                fontWeight: FontWeight.w500,

              ),

            ),

          ],

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context),

            child: const Text('Cancel'),

          ),

          ElevatedButton(

            style: ElevatedButton.styleFrom(

              backgroundColor: Colors.red,

              foregroundColor: Colors.white,

            ),

            onPressed: () {

              Navigator.pop(context);

              _deleteReservation(reservationId);

            },

            child: const Text('Delete'),

          ),

        ],

      ),

    );

  }



  Future<void> _deleteReservation(String reservationId) async {

    try {

      await Supabase.instance.client

          .from('reservations')

          .delete()

          .eq('id', reservationId);



      _showSnackBar('Reservation deleted successfully', Colors.green);

      _loadCustomerReservations();

    } catch (e) {

      _showSnackBar('Error deleting reservation: $e', Colors.red);

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
    if (guestCount < 10 || guestCount > 500) {
      _showSnackBar('Number of guests must be between 10 and 500', Colors.red);
      return;
    }

    double totalDuration = double.tryParse(_durationController.text) ?? 0.0;
    if (totalDuration == 0) {
      _showSnackBar('Invalid duration selected', Colors.red);
      return;
    }



    // Get current user info

    final currentUser = Supabase.instance.client.auth.currentUser;

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

      String formattedDate = "${dateParts[2]}-${dateParts[0].padLeft(2, '0')}-${dateParts[1].padLeft(2, '0')}";



      // Create reservation WITHOUT payment first (pending confirmation)
      await _createReservationWithoutPayment(
        currentUser,
        _selectedEventType!,
        formattedDate,
        startTime,
        totalDuration,
        guestCount,
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
  ) async {

    try {

      // Save reservation to database with PENDING status

      await Supabase.instance.client.from('reservations').insert({

        'customer_email': currentUser.email,

        'customer_name': currentUser.userMetadata?['name'] ?? 'Customer',

        'event_type': event,

        'event_date': formattedDate,

        'start_time': startTime,

        'duration_hours': duration,

        'number_of_guests': guests,

        'status': 'pending', // Pending admin confirmation

        'payment_status': 'unpaid', // No payment yet

        'created_at': DateTime.now().toIso8601String(),

      });



      if (!mounted) return;



      // Show success message

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: const Row(

            children: [

              Icon(Icons.check_circle_outline, color: Colors.white),

              SizedBox(width: 12),

              Expanded(child: Text('Reservation submitted successfully! Waiting for admin confirmation.')),

            ],

          ),

          backgroundColor: Colors.green,

          behavior: SnackBarBehavior.floating,

          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),

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

              Expanded(child: Text('Error creating reservation: ${e.toString()}')),

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

    double reservationFee = 500.0 + (50.0 * (reservation['number_of_guests'] ?? 1));



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

              backgroundColor: AppTheme.primaryRed,

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

            description: 'Reservation for ${reservation['event_type']} on ${reservation['event_date']}',

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

                _updateReservationPayment(reservation['id'], result?['payment_method'] ?? 'unknown', reservationFee);

              }

            },

          ),

        ),

      );

    }

  }



  Future<void> _updateReservationPayment(String reservationId, String paymentMethod, double amount) async {

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



      if (!mounted) return;



      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Row(

            children: [

              Icon(Icons.check_circle_outline, color: Colors.white),

              SizedBox(width: 12),

              Expanded(child: Text('Payment successful! Your reservation is fully confirmed.')),

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

        shape: RoundedRectangleBorder(

          borderRadius: BorderRadius.circular(12),

        ),

        title: const Row(

          children: [

            Icon(Icons.logout, color: AppTheme.primaryRed),

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

              backgroundColor: AppTheme.primaryRed,

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

                  MaterialPageRoute(

                    builder: (context) => const LoginPage(),

                  ),

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