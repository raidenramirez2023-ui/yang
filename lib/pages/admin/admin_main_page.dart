import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:yang_chow/utils/app_theme.dart';

import 'package:yang_chow/utils/role_helper.dart';

import 'package:yang_chow/utils/responsive_utils.dart';

import 'package:yang_chow/pages/admin/user_management.dart';

import 'package:yang_chow/pages/admin/sales_report_page.dart';

import 'package:yang_chow/pages/staff/inventory_management.dart';

import 'package:yang_chow/pages/admin/admin_dashboard.dart';

import 'package:yang_chow/pages/admin/admin_reservations_page.dart';

import 'package:yang_chow/pages/admin/admin_announcements_page.dart';

import 'package:yang_chow/pages/admin/admin_chat_page.dart';

import 'package:yang_chow/pages/admin/inventory_forecast_page.dart';

import 'package:yang_chow/widgets/admin_chat_modal.dart';

import 'package:yang_chow/services/notification_service.dart';

import 'package:intl/intl.dart';



class AdminMainPage extends StatefulWidget {

  const AdminMainPage({super.key});



  @override

  State<AdminMainPage> createState() => _AdminMainPageState();

}



class _AdminMainPageState extends State<AdminMainPage> {

  int _selectedIndex = 0;



  @override

  void initState() {

    super.initState();

    _checkUserRole();

  }



  Future<void> _checkUserRole() async {

    final isAdmin = await RoleHelper.isAdmin();



    if (!isAdmin && mounted) {

      Navigator.pushReplacementNamed(context, '/staff-dashboard');

    }

  }



  static const List<String> _pageTitles = [

    'Dashboard',

    'Sales Reports',

    'Inventory',

    'Inventory Forecast',

    'Reservations',

    'User Management',

    'Announcements',

    'Customer Chat',

  ];



  static const List<IconData> _pageIcons = [

    Icons.dashboard,

    Icons.analytics,

    Icons.inventory_2,

    Icons.trending_up,

    Icons.event_available,

    Icons.people,

    Icons.campaign,

    Icons.chat_bubble,

  ];



  late final List<Widget> _pages = [

    const AdminDashboardPage(),

    const SalesReportPage(),

    const InventoryPage(),

    const InventoryForecastPage(),

    const AdminReservationsPage(),

    const UserManagementPage(),

    const AdminAnnouncementsPage(),

    const AdminChatPage(),

  ];



  @override

  Widget build(BuildContext context) {

    final isDesktop = ResponsiveUtils.isDesktop(context);

    final isTablet = ResponsiveUtils.isTablet(context);

    final useDrawer = ResponsiveUtils.shouldUseDrawer(context);



    if (isDesktop || isTablet) {

      return _buildDesktopLayout();

    } else if (useDrawer) {

      return _buildWebMobileLayout();

    } else {

      return _buildMobileLayout();

    }

  }



  Widget _buildDesktopLayout() {

    return Scaffold(

      backgroundColor: const Color(0xFFF1F5F9),

      body: Stack(

        children: [

          Row(

            children: [

              _buildSidebar(),

              Expanded(

                child: Column(

                  children: [

                    _buildModernAppBar(),

                    Expanded(

                      child: Container(

                        padding: const EdgeInsets.all(24),

                        child: _pages[_selectedIndex],

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

          // Chat Modal Overlay

          const AdminChatModal(),

        ],

      ),

    );

  }



  Widget _buildSidebar() {

    return Container(

      width: 260,

      color: Colors.white,

      child: Column(

        children: [

          Padding(

            padding: const EdgeInsets.all(24),

            child: Row(

              children: [

                Container(

                  padding: const EdgeInsets.all(8),

                  decoration: BoxDecoration(

                    color: AppTheme.primaryColor,

                    borderRadius: BorderRadius.circular(12),

                  ),

                  child: const Icon(

                    Icons.restaurant,

                    color: Colors.white,

                    size: 24,

                  ),

                ),

                const SizedBox(width: 12),

                const Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      'AdminPanel',

                      style: TextStyle(

                        fontWeight: FontWeight.bold,

                        fontSize: 18,

                        color: Color(0xFF1E293B),

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ),



          const SizedBox(height: 8),



          Expanded(

            child: ListView.builder(

              padding: const EdgeInsets.symmetric(horizontal: 16),

              itemCount: _pageTitles.length,

              itemBuilder: (context, index) {

                final isSelected = _selectedIndex == index;

                return Padding(

                  padding: const EdgeInsets.only(bottom: 4),

                  child: Material(

                    color: isSelected

                        ? AppTheme.primaryColor

                        : Colors.transparent,

                    borderRadius: BorderRadius.circular(12),

                    child: InkWell(

                      borderRadius: BorderRadius.circular(12),

                      onTap: () => setState(() => _selectedIndex = index),

                      child: Container(

                        padding: const EdgeInsets.symmetric(

                          horizontal: 16,

                          vertical: 12,

                        ),

                        child: Row(

                          children: [

                            Icon(

                              _pageIcons[index],

                              size: 20,

                              color: isSelected

                                  ? Colors.white

                                  : const Color(0xFF64748B),

                            ),

                            const SizedBox(width: 12),

                            Text(

                              _pageTitles[index],

                              style: TextStyle(

                                fontWeight: isSelected

                                    ? FontWeight.w600

                                    : FontWeight.w500,

                                color: isSelected

                                    ? Colors.white

                                    : const Color(0xFF64748B),

                              ),

                            ),

                          ],

                        ),

                      ),

                    ),

                  ),

                );

              },

            ),

          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          ListTile(

            onTap: () => _showLogoutDialog(context),

            leading: const Icon(Icons.logout, color: Colors.redAccent),

            title: const Text(

              'Logout',

              style: TextStyle(

                color: Colors.redAccent,

                fontWeight: FontWeight.w500,

              ),

            ),

          ),

          const SizedBox(height: 12),

        ],

      ),

    );

  }



  Widget _buildModernAppBar() {

    final currentUser = Supabase.instance.client.auth.currentUser;

    return Container(

      height: 70,

      padding: const EdgeInsets.symmetric(horizontal: 24),

      decoration: const BoxDecoration(

        color: Colors.white,

        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),

      ),

      child: Row(

        children: [

          Text(

            _pageTitles[_selectedIndex],

            style: const TextStyle(

              fontSize: 20,

              fontWeight: FontWeight.bold,

              color: Color(0xFF1E293B),

            ),

          ),

          const Spacer(),

          _buildAdminNotificationIcon(),

          const SizedBox(width: 16),

          Row(

            children: [

              Container(height: 32, width: 1, color: const Color(0xFFE2E8F0)),

              const SizedBox(width: 24),

              Column(

                mainAxisAlignment: MainAxisAlignment.center,

                crossAxisAlignment: CrossAxisAlignment.end,

                children: [

                  Text(

                    currentUser?.email?.split('@')[0] ?? 'Admin',

                    style: const TextStyle(

                      fontWeight: FontWeight.w600,

                      color: Color(0xFF1E293B),

                      fontSize: 14,

                    ),

                  ),

                  const Text(

                    'Admin',

                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),

                  ),

                ],

              ),

              const SizedBox(width: 12),

              CircleAvatar(

                radius: 18,

                backgroundColor: const Color(0xFFF1F5F9),

                child: const Icon(Icons.person, color: AppTheme.primaryColor),

              ),

              const SizedBox(width: 8),

              const Icon(

                Icons.keyboard_arrow_down,

                color: Color(0xFF64748B),

                size: 20,

              ),

            ],

          ),

        ],

      ),

    );

  }



  Widget _buildWebMobileLayout() {

    return Scaffold(

      backgroundColor: const Color(0xFFF1F5F9),

      appBar: _buildAppBarWithDrawer(),

      drawer: _buildDrawer(),

      body: Stack(

        children: [

          _pages[_selectedIndex],

          // Chat Modal Overlay

          const AdminChatModal(),

        ],

      ),

    );

  }



  Widget _buildMobileLayout() {

    return Scaffold(

      backgroundColor: const Color(0xFFF1F5F9),

      appBar: _buildAppBarWithDrawer(),

      drawer: _buildDrawer(),

      body: Stack(

        children: [

          _pages[_selectedIndex],

          // Chat Modal Overlay

          const AdminChatModal(),

        ],

      ),

      bottomNavigationBar: _buildBottomNavigationBar(),

    );

  }



  PreferredSizeWidget _buildAppBarWithDrawer() {

    return AppBar(

      backgroundColor: Colors.white,

      elevation: 0,

      centerTitle: true,

      title: Row(

        mainAxisSize: MainAxisSize.min,

        children: [

          Container(

            padding: const EdgeInsets.all(6),

            decoration: BoxDecoration(

              color: AppTheme.primaryColor,

              borderRadius: BorderRadius.circular(8),

            ),

            child: const Icon(Icons.restaurant, size: 16, color: Colors.white),

          ),

          const SizedBox(width: 8),

          const Text(

            'AdminPanel',

            style: TextStyle(

              color: Color(0xFF1E293B),

              fontSize: 16,

              fontWeight: FontWeight.bold,

            ),

          ),

        ],

      ),

      leading: Builder(

        builder: (context) => IconButton(

          icon: const Icon(Icons.menu, color: Color(0xFF64748B)),

          onPressed: () => Scaffold.of(context).openDrawer(),

          tooltip: 'Menu',

        ),

      ),

      actions: [

        IconButton(

          icon: const Icon(Icons.logout, color: Color(0xFF64748B)),

          tooltip: 'Logout',

          onPressed: () => _showLogoutDialog(context),

        ),

      ],

      bottom: PreferredSize(

        preferredSize: const Size.fromHeight(1),

        child: Container(color: const Color(0xFFE2E8F0), height: 1),

      ),

    );

  }



  Widget _buildDrawer() {

    return Drawer(

      backgroundColor: Colors.white,

      child: Column(

        children: [

          DrawerHeader(

            margin: EdgeInsets.zero,

            padding: const EdgeInsets.all(24),

            decoration: const BoxDecoration(

              color: Colors.white,

              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),

            ),

            child: Row(

              children: [

                Container(

                  padding: const EdgeInsets.all(8),

                  decoration: BoxDecoration(

                    color: AppTheme.primaryColor,

                    borderRadius: BorderRadius.circular(12),

                  ),

                  child: const Icon(

                    Icons.restaurant,

                    color: Colors.white,

                    size: 24,

                  ),

                ),

                const SizedBox(width: 12),

                const Column(

                  mainAxisAlignment: MainAxisAlignment.center,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      'AdminPanel',

                      style: TextStyle(

                        fontWeight: FontWeight.bold,

                        fontSize: 18,

                        color: Color(0xFF1E293B),

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ),

          Expanded(

            child: ListView.builder(

              padding: const EdgeInsets.all(16),

              itemCount: _pageTitles.length,

              itemBuilder: (context, index) {

                final isSelected = _selectedIndex == index;

                return Padding(

                  padding: const EdgeInsets.only(bottom: 4),

                  child: Material(

                    color: isSelected

                        ? AppTheme.primaryColor

                        : Colors.transparent,

                    borderRadius: BorderRadius.circular(12),

                    child: InkWell(

                      borderRadius: BorderRadius.circular(12),

                      onTap: () {

                        setState(() => _selectedIndex = index);

                        Navigator.pop(context);

                      },

                      child: Container(

                        padding: const EdgeInsets.symmetric(

                          horizontal: 16,

                          vertical: 12,

                        ),

                        child: Row(

                          children: [

                            Icon(

                              _pageIcons[index],

                              size: 20,

                              color: isSelected

                                  ? Colors.white

                                  : const Color(0xFF64748B),

                            ),

                            const SizedBox(width: 12),

                            Text(

                              _pageTitles[index],

                              style: TextStyle(

                                fontWeight: isSelected

                                    ? FontWeight.w600

                                    : FontWeight.w500,

                                color: isSelected

                                    ? Colors.white

                                    : const Color(0xFF64748B),

                              ),

                            ),

                          ],

                        ),

                      ),

                    ),

                  ),

                );

              },

            ),

          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          ListTile(

            leading: const Icon(Icons.logout, color: Colors.redAccent),

            title: const Text(

              'Logout',

              style: TextStyle(color: Colors.redAccent),

            ),

            onTap: () {

              Navigator.pop(context);

              _showLogoutDialog(context);

            },

          ),

          const SizedBox(height: 16),

        ],

      ),

    );

  }



  Widget _buildBottomNavigationBar() {

    return BottomNavigationBar(

      currentIndex: _selectedIndex,

      onTap: (index) {

        setState(() => _selectedIndex = index);

      },

      type: BottomNavigationBarType.fixed,

      backgroundColor: AppTheme.white,

      selectedItemColor: AppTheme.primaryColor,

      unselectedItemColor: AppTheme.mediumGrey,

      items: _pageTitles.asMap().entries.map((entry) {

        final index = entry.key;

        final title = entry.value;

        return BottomNavigationBarItem(

          icon: Icon(_pageIcons[index]),

          label: title,

        );

      }).toList(),

    );

  }



  void _showLogoutDialog(BuildContext context) {

    final isMobile = ResponsiveUtils.isMobile(context);



    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (context) => AlertDialog(

        shape: RoundedRectangleBorder(

          borderRadius: BorderRadius.circular(AppTheme.radiusLg),

        ),

        contentPadding: EdgeInsets.all(isMobile ? 16 : 24),

        title: Row(

          children: [

            Icon(

              Icons.logout,

              color: AppTheme.primaryColor,

              size: ResponsiveUtils.getResponsiveIconSize(context),

            ),

            SizedBox(width: isMobile ? 8 : 12),

            Expanded(

              child: Text(

                'Logout',

                style: TextStyle(

                  fontSize: ResponsiveUtils.getResponsiveFontSize(

                    context,

                    mobile: 18,

                    tablet: 20,

                    desktop: 22,

                  ),

                  fontWeight: FontWeight.bold,

                ),

              ),

            ),

          ],

        ),

        content: Text(

          'Are you sure you want to logout?',

          style: TextStyle(

            fontSize: ResponsiveUtils.getResponsiveFontSize(

              context,

              mobile: 14,

              tablet: 16,

              desktop: 16,

            ),

          ),

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context),

            child: Text(

              'Cancel',

              style: TextStyle(

                fontSize: ResponsiveUtils.getResponsiveFontSize(

                  context,

                  mobile: 14,

                  tablet: 15,

                  desktop: 16,

                ),

              ),

            ),

          ),

          ElevatedButton(

            style: ElevatedButton.styleFrom(

              backgroundColor: AppTheme.errorRed,

              padding: EdgeInsets.symmetric(

                horizontal: isMobile ? 16 : 24,

                vertical: isMobile ? 8 : 12,

              ),

            ),

            onPressed: () async {

              Navigator.pop(context);

              final navigator = Navigator.of(context);

              await Supabase.instance.client.auth.signOut();

              try {

                await GoogleSignIn().signOut();

              } catch (_) {}



              if (mounted) {

                navigator.pushReplacementNamed('/staff-login');

              }

            },

            child: Text(

              'Logout',

              style: TextStyle(

                fontSize: ResponsiveUtils.getResponsiveFontSize(

                  context,

                  mobile: 14,

                  tablet: 15,

                  desktop: 16,

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildAdminNotificationIcon() {

    return StreamBuilder<List<Map<String, dynamic>>>(

      stream: NotificationService.getAdminNotificationsStream(),

      builder: (context, snapshot) {

        final notifications = snapshot.data ?? [];

        final hasUnread = notifications.any((n) => !n['is_read']);



        return Stack(

          children: [

            IconButton(

              icon: const Icon(

                Icons.notifications_none_rounded,

                color: Color(0xFF64748B),

              ),

              onPressed: () => _showAdminNotificationsDialog(notifications),

              tooltip: 'Notifications',

            ),

            if (hasUnread)

              Positioned(

                right: 8,

                top: 8,

                child: Container(

                  width: 10,

                  height: 10,

                  decoration: BoxDecoration(

                    color: AppTheme.primaryColor,

                    shape: BoxShape.circle,

                    border: Border.all(color: Colors.white, width: 2),

                  ),

                ),

              ),

          ],

        );

      },

    );

  }



  void _showAdminNotificationsDialog(List<Map<String, dynamic>> notifications) {

    NotificationService.markAllAsRead('', forAdmin: true);



    showDialog(

      context: context,

      builder: (context) => AlertDialog(

        title: const Text('Admin Notifications'),

        content: SizedBox(

          width: 400,

          height: 500,

          child: notifications.isEmpty

              ? const Center(child: Text('No new activity'))

              : ListView.separated(

                  itemCount: notifications.length,

                  separatorBuilder: (context, index) => const Divider(),

                  itemBuilder: (context, index) {

                    final n = notifications[index];

                    final date = DateTime.parse(n['created_at']).toLocal();

                    final timeStr = DateFormat('MMM d, h:mm a').format(date);



                    return ListTile(

                      leading: CircleAvatar(

                        backgroundColor: AppTheme.primaryColor.withValues(

                          alpha: 0.1,

                        ),

                        child: Icon(

                          _getIconForAction(n['action_type']),

                          color: AppTheme.primaryColor,

                          size: 20,

                        ),

                      ),

                      title: Text(

                        _getAdminNotificationTitle(n),

                        style: const TextStyle(

                          fontWeight: FontWeight.bold,

                          fontSize: 14,

                        ),

                      ),

                      subtitle: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          Text(

                            '${n['actor_name']} ${n['action_type']} reservation for ${n['event_type']}',

                          ),

                          Text(

                            timeStr,

                            style: const TextStyle(

                              fontSize: 10,

                              color: Colors.grey,

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



  IconData _getIconForAction(String action) {

    switch (action) {

      case 'created':

        return Icons.add_circle;

      case 'cancelled':

      case 'deleted':

        return Icons.cancel;

      case 'paid':

        return Icons.payments;

      case 'updated':

        return Icons.edit;

      default:

        return Icons.notifications;

    }

  }



  String _getAdminNotificationTitle(Map<String, dynamic> n) {

    switch (n['action_type']) {

      case 'created':

        return 'New Reservation';

      case 'cancelled':

        return 'Reservation Cancelled';

      case 'deleted':

        return 'Reservation Deleted';

      case 'paid':

        return 'Payment Received';

      case 'updated':

        return 'Reservation Modified';

      default:

        return 'Activity Alert';

    }

  }

}

