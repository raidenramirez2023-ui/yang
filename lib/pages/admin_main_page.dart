import 'package:flutter/material.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/utils/role_helper.dart';
import 'package:yang_chow/pages/user_management.dart';
import 'package:yang_chow/pages/sales_report_page.dart';
import 'package:yang_chow/pages/inventory_management.dart';
import 'package:yang_chow/pages/settings.dart';
import 'package:yang_chow/pages/admin_dashboard.dart';
import 'package:yang_chow/pages/admin_reservations_page.dart';

class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  int _selectedIndex = 0;
  bool _isSidebarOpen = true;

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
    SettingsPage(),
  ];

  static const List<String> _pageTitles = [
    'Dashboard',
    'Sales Reports',
    'Inventory',
    'Reservations',
    'User Management',
    'Settings',
  ];

  static const List<IconData> _pageIcons = [
    Icons.dashboard,
    Icons.analytics,
    Icons.inventory_2,
    Icons.event_available,
    Icons.people,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              icon: Icon(_isSidebarOpen ? Icons.menu_open : Icons.menu),
              tooltip: 'Toggle Sidebar',
              onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
            ),
            const SizedBox(width: AppTheme.md),
            Icon(_pageIcons[_selectedIndex]),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Text(
                _pageTitles[_selectedIndex],
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: AppTheme.md, horizontal: AppTheme.md),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
            decoration: BoxDecoration(
              color: AppTheme.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, color: AppTheme.white, size: 18),
                const SizedBox(width: AppTheme.md),
                Text(
                  'Administrator',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isSidebarOpen ? 280 : 0,
            color: AppTheme.white,
            child: _isSidebarOpen
                ? ListView(
                    padding: EdgeInsets.zero,
                    children: List.generate(
                      _pageTitles.length,
                      (index) => ListTile(
                        leading: Icon(
                          _pageIcons[index],
                          color: _selectedIndex == index ? AppTheme.primaryRed : AppTheme.mediumGrey,
                        ),
                        title: Text(
                          _pageTitles[index],
                          style: TextStyle(
                            color: _selectedIndex == index ? AppTheme.primaryRed : AppTheme.darkGrey,
                            fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          setState(() => _selectedIndex = index);
                        },
                      ),
                    ),
                  )
                : null,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Text(
          'Logout',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
