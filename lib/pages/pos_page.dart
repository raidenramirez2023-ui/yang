import 'package:flutter/material.dart';
import 'package:yang_chow/widgets/shared_pos_widget.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/pages/user_management.dart';
import 'package:yang_chow/pages/sales_report_page.dart';
import 'package:yang_chow/pages/inventory_management.dart';
import 'package:yang_chow/pages/settings.dart';

class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  int _selectedIndex = 0;

  // Pages for admin
  final List<Widget> _pages = [
    const InventoryPage(),
    const SalesReportPage(),
    const UserManagementPage(),
    const SettingsPage(),
  ];

  final List<String> _pageTitles = [
    'Inventory',
    'Sales Reports',
    'User Management',
    'Settings',
  ];

  final List<IconData> _pageIcons = [
    Icons.inventory_2,
    Icons.analytics,
    Icons.people,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveUtils.getDeviceType(context);
    final isDesktop = deviceType == DeviceType.desktop;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
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
              color: AppTheme.white.withOpacity(0.2),
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
          if (!isDesktop) const SizedBox(width: AppTheme.md),
        ],
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      bottomNavigationBar: !isDesktop ? _buildBottomNav() : null,
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar Navigation
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          elevation: 2,
          backgroundColor: AppTheme.white,
          indicatorColor: AppTheme.primaryRed.withOpacity(0.2),
          selectedIconTheme: const IconThemeData(
            color: AppTheme.primaryRed,
            size: 28,
          ),
          selectedLabelTextStyle: const TextStyle(
            color: AppTheme.primaryRed,
            fontWeight: FontWeight.bold,
          ),
          unselectedIconTheme: const IconThemeData(
            color: AppTheme.mediumGrey,
            size: 24,
          ),
          unselectedLabelTextStyle: const TextStyle(
            color: AppTheme.mediumGrey,
          ),
          labelType: NavigationRailLabelType.all,
          destinations: List.generate(
            _pageTitles.length,
            (index) => NavigationRailDestination(
              icon: Icon(_pageIcons[index]),
              label: Text(
                _pageTitles[index],
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // Content Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.lg),
            child: _pages[_selectedIndex],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.md),
      child: _pages[_selectedIndex],
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
      backgroundColor: AppTheme.white,
      elevation: 8,
      destinations: List.generate(
        _pageTitles.length,
        (index) => NavigationDestination(
          icon: Icon(_pageIcons[index]),
          label: _pageTitles[index],
        ),
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