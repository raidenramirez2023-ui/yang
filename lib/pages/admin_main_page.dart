import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:yang_chow/utils/app_theme.dart';

import 'package:yang_chow/utils/role_helper.dart';

import 'package:yang_chow/utils/responsive_utils.dart';

import 'package:yang_chow/pages/user_management.dart';

import 'package:yang_chow/pages/sales_report_page.dart';

import 'package:yang_chow/pages/inventory_management.dart';

import 'package:yang_chow/pages/settings.dart';

import 'package:yang_chow/pages/admin_dashboard.dart';

import 'package:yang_chow/pages/admin_reservations_page.dart';

import 'package:yang_chow/pages/admin_announcements_page.dart';



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



  static const List<Widget> _pages = [

    AdminDashboardPage(),

    SalesReportPage(),

    InventoryPage(),

    AdminReservationsPage(),

    UserManagementPage(),

    AdminAnnouncementsPage(),

    SettingsPage(),

  ];



  static const List<String> _pageTitles = [

    'Dashboard',

    'Sales Reports',

    'Inventory',

    'Reservations',

    'User Management',

    'Announcements',

    'Settings',

  ];



  static const List<IconData> _pageIcons = [

    Icons.dashboard,

    Icons.analytics,

    Icons.inventory_2,

    Icons.event_available,

    Icons.people,

    Icons.campaign,

    Icons.settings,

  ];



  @override

  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final useDrawer = ResponsiveUtils.shouldUseDrawer(context);
    
    // Use navigation rail for tablet/desktop, drawer for web mobile, bottom navigation for mobile app
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBarWithoutDrawer(),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: ResponsiveUtils.isDesktop(context) 
                ? NavigationRailLabelType.all 
                : NavigationRailLabelType.selected,
            leading: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.restaurant,
                    size: ResponsiveUtils.getResponsiveIconSize(context, desktop: 40, tablet: 32, mobile: 28),
                    color: AppTheme.primaryRed,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yang Chow',
                    style: TextStyle(
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16),
                    ),
                  ),
                ],
              ),
            ),
            destinations: _pageTitles.asMap().entries.map((entry) {
              final index = entry.key;
              final title = entry.value;
              return NavigationRailDestination(
                icon: Icon(_pageIcons[index]),
                selectedIcon: Icon(_pageIcons[index]),
                label: Text(title),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildWebMobileLayout() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBarWithDrawer(),
      drawer: _buildDrawer(),
      body: _pages[_selectedIndex],
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBarWithDrawer(),
      drawer: _buildDrawer(),
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBarWithDrawer() {
    return AppBar(
      backgroundColor: AppTheme.primaryRed,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _pageIcons[_selectedIndex],
            size: ResponsiveUtils.getResponsiveIconSize(context),
          ),
          SizedBox(width: ResponsiveUtils.isMobile(context) ? 8 : 12),
          Flexible(
            child: Text(
              _pageTitles[_selectedIndex],
              style: TextStyle(
                color: AppTheme.white,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'Menu',
        ),
      ),
      actions: [
        Container(
          margin: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.isMobile(context) ? 6 : 8,
            horizontal: ResponsiveUtils.isMobile(context) ? 6 : 8,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.isMobile(context) ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: AppTheme.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings, 
                color: AppTheme.white, 
                size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 14, tablet: 16, desktop: 18),
              ),
              if (!ResponsiveUtils.isMobile(context)) const SizedBox(width: 6),
              if (!ResponsiveUtils.isMobile(context))
                Flexible(
                  child: Text(
                    'Administrator',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.logout,
            size: ResponsiveUtils.getResponsiveIconSize(context),
          ),
          tooltip: 'Logout',
          onPressed: () => _showLogoutDialog(context),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBarWithoutDrawer() {
    return AppBar(
      backgroundColor: AppTheme.primaryRed,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _pageIcons[_selectedIndex],
            size: ResponsiveUtils.getResponsiveIconSize(context),
          ),
          SizedBox(width: ResponsiveUtils.isMobile(context) ? 8 : 12),
          Flexible(
            child: Text(
              _pageTitles[_selectedIndex],
              style: TextStyle(
                color: AppTheme.white,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.isMobile(context) ? 6 : 8,
            horizontal: ResponsiveUtils.isMobile(context) ? 6 : 8,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.isMobile(context) ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: AppTheme.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings, 
                color: AppTheme.white, 
                size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 14, tablet: 16, desktop: 18),
              ),
              if (!ResponsiveUtils.isMobile(context)) const SizedBox(width: 6),
              if (!ResponsiveUtils.isMobile(context))
                Flexible(
                  child: Text(
                    'Administrator',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.logout,
            size: ResponsiveUtils.getResponsiveIconSize(context),
          ),
          tooltip: 'Logout',
          onPressed: () => _showLogoutDialog(context),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppTheme.primaryRed,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.restaurant,
                  size: ResponsiveUtils.getResponsiveIconSize(context, desktop: 40, tablet: 32, mobile: 28),
                  color: AppTheme.white,
                ),
                const SizedBox(height: 8),
                Text(
                  'Yang Chow',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16),
                  ),
                ),
              ],
            ),
          ),
          ..._pageTitles.asMap().entries.map((entry) {
            final index = entry.key;
            final title = entry.value;
            return ListTile(
              leading: Icon(_pageIcons[index]),
              title: Text(title),
              onTap: () {
                setState(() => _selectedIndex = index);
                Navigator.pop(context);
              },
            );
          }),
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
      selectedItemColor: AppTheme.primaryRed,
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
              color: AppTheme.primaryRed,
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
                navigator.pushReplacementNamed('/');
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

}