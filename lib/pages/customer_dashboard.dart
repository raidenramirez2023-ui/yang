import 'dart:async';

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:yang_chow/utils/app_theme.dart';

import 'package:yang_chow/utils/responsive_utils.dart';

import 'package:yang_chow/pages/login_page.dart';

import 'package:yang_chow/pages/payment_page.dart';

import 'package:yang_chow/services/paymongo_service.dart';

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



  // Form controllers

  final TextEditingController _eventController = TextEditingController();

  final TextEditingController _dateController = TextEditingController();

  final TextEditingController _startTimeController = TextEditingController();

  final TextEditingController _durationController = TextEditingController();

  final TextEditingController _guestsController = TextEditingController();



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



      setState(() {

        customerReservations = List<Map<String, dynamic>>.from(response);

      });

    } catch (e) {

      debugPrint('Error loading customer reservations: $e');

    }

  }



  @override

  Widget build(BuildContext context) {

    final isDesktop = ResponsiveUtils.isDesktop(context);



    return Scaffold(

      backgroundColor: Colors.white,

      appBar: isDesktop 

          ? AppBar(

              automaticallyImplyLeading: false,

              title: const Text('Customer Dashboard'),

              backgroundColor: AppTheme.primaryRed,

              foregroundColor: Colors.white,

            )

          : null,

      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),

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

            color: const Color(0xFFF5F5F5),

            child: RefreshIndicator(

              onRefresh: _loadCustomerReservations,

              color: AppTheme.primaryRed,

              child: Padding(

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

                  padding: const EdgeInsets.all(20),

                  decoration: BoxDecoration(

                    color: Colors.white.withValues(alpha: 0.2),

                    shape: BoxShape.circle,

                  ),

                  child: const Icon(

                    Icons.waving_hand,

                    color: Colors.white,

                    size: 40,

                  ),

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

                    TextField(

                      controller: _eventController,

                      decoration: InputDecoration(

                        hintText: 'e.g., Birthday Party, Wedding, Meeting',

                        prefixIcon: const Icon(Icons.event),

                        border: OutlineInputBorder(

                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),

                        ),

                      ),

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

                        hintText: 'Select date',

                        prefixIcon: const Icon(Icons.calendar_today),

                        border: OutlineInputBorder(

                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),

                        ),

                      ),

                      onTap: () async {

                        DateTime? pickedDate = await showDatePicker(

                          context: context,

                          initialDate: DateTime.now(),

                          firstDate: DateTime.now(),

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

                    TextField(

                      controller: _startTimeController,

                      readOnly: true,

                      decoration: InputDecoration(

                        hintText: 'Select time',

                        prefixIcon: const Icon(Icons.access_time),

                        border: OutlineInputBorder(

                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),

                        ),

                      ),

                      onTap: () async {

                        TimeOfDay? pickedTime = await showTimePicker(

                          context: context,

                          initialTime: TimeOfDay.now(),

                        );

                        if (pickedTime != null) {

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

                    TextField(

                      controller: _durationController,

                      keyboardType: TextInputType.number,

                      decoration: InputDecoration(

                        hintText: 'e.g., 2, 3, 4',

                        prefixIcon: const Icon(Icons.hourglass_empty),

                        border: OutlineInputBorder(

                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),

                        ),

                      ),

                    ),

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

                      decoration: InputDecoration(

                        hintText: 'e.g., 10, 25, 50',

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

      child: Column(

        children: [

          const SizedBox(height: 24),

          // Profile Avatar

          Stack(

            children: [

              Container(

                width: 100,

                height: 100,

                decoration: BoxDecoration(

                  color: const Color(0xFFF0B38B), // Peach color from image

                  shape: BoxShape.circle,

                  border: Border.all(color: Colors.white, width: 4),

                  boxShadow: [

                    BoxShadow(

                      color: Colors.black.withValues(alpha: 0.1),

                      blurRadius: 8,

                      offset: const Offset(0, 4),

                    ),

                  ],

                ),

                child: Center(

                  child: Text(

                    initial,

                    style: const TextStyle(

                      fontSize: 40,

                      fontWeight: FontWeight.bold,

                      color: Colors.white,

                    ),

                  ),

                ),

              ),

              Positioned(

                bottom: 0,

                right: 0,

                child: Container(

                  padding: const EdgeInsets.all(4),

                  decoration: const BoxDecoration(

                    color: AppTheme.primaryRed,

                    shape: BoxShape.circle,

                  ),

                  child: const Icon(

                    Icons.add,

                    color: Colors.white,

                    size: 20,

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(height: 16),

          // Name and Email

          Text(

            name,

            style: const TextStyle(

              fontSize: 24,

              fontWeight: FontWeight.bold,

              color: Color(0xFF1E1E1E),

            ),

          ),

          const SizedBox(height: 4),

          Text(

            email,

            style: TextStyle(

              fontSize: 14,

              color: Colors.grey.shade600,

            ),

          ),

          const SizedBox(height: 32),

          

          // Menu Cards

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 16),

            child: Column(

              children: [

                _buildAccountMenuCard(

                  icon: Icons.person_outline,

                  title: 'Personal Information',

                  subtitle: 'Name, email, phone',

                  onTap: () {},

                ),

                const SizedBox(height: 12),

                _buildAccountMenuCard(

                  icon: Icons.settings_outlined,

                  title: 'Settings',

                  subtitle: 'Notifications, privacy',

                  onTap: () {},

                ),

                const SizedBox(height: 12),

                _buildAccountMenuCard(

                  icon: Icons.help_outline,

                  title: 'Help & Support',

                  subtitle: 'FAQs, contact us',

                  onTap: () {},

                ),

                const SizedBox(height: 12),

                _buildAccountMenuCard(

                  icon: Icons.logout,

                  title: 'Logout',

                  subtitle: null,

                  isDestructive: true,

                  onTap: _showLogoutDialog,

                ),

                const SizedBox(height: 24),

              ],

            ),

          ),

        ],

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

    final color = isDestructive ? AppTheme.primaryRed : const Color(0xFF1E1E1E);

    final iconBgColor = AppTheme.primaryRed.withValues(alpha: 0.1);



    return InkWell(

      onTap: onTap,

      borderRadius: BorderRadius.circular(16),

      child: Container(

        padding: const EdgeInsets.all(16),

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

        child: Row(

          children: [

            Container(

              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(

                color: iconBgColor,

                borderRadius: BorderRadius.circular(12),

              ),

              child: Icon(

                icon,

                color: isDestructive ? AppTheme.primaryRed : const Color(0xFFC04F4F),

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

                      fontWeight: FontWeight.w600,

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

              Icons.chevron_right,

              color: isDestructive ? AppTheme.primaryRed : Colors.grey.shade400,

              size: 20,

            ),

          ],

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

    String event = _eventController.text.trim();

    String date = _dateController.text.trim();

    String startTime = _startTimeController.text.trim();

    String duration = _durationController.text.trim();

    String guests = _guestsController.text.trim();



    // Validation

    if (event.isEmpty || date.isEmpty || startTime.isEmpty || duration.isEmpty || guests.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: const Row(

            children: [

              Icon(Icons.error_outline, color: Colors.white),

              SizedBox(width: 12),

              Text('Please fill in all fields'),

            ],

          ),

          backgroundColor: Colors.red,

          behavior: SnackBarBehavior.floating,

        ),

      );

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

        event,

        formattedDate,

        startTime,

        int.parse(duration.replaceAll(RegExp(r'[^0-9]'), '')),

        int.parse(guests.replaceAll(RegExp(r'[^0-9]'), '')),

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

    int duration,

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



    if (shouldProceed == true) {

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