  import 'package:flutter/material.dart';
  import 'package:yang_chow/widgets/shared_pos_widget.dart';
  import 'sales_report_page.dart';
  import 'user_management.dart'; 
  import 'inventory_page.dart'; // ✅ Import real InventoryPage

  class AdminMainPage extends StatefulWidget {
    const AdminMainPage({super.key});

    @override
    State<AdminMainPage> createState() => _AdminMainPageState();
  }

  class _AdminMainPageState extends State<AdminMainPage> {
    int _selectedIndex = 0;

    // Pages for admin
    final List<Widget> _pages = [
      const SharedPOSWidget(userRole: 'Admin'), // POS System
      const InventoryPage(),                     // ✅ REAL Inventory Management
      const SalesReportPage(),                   // Sales Reports
      const UserManagementPage(),                // User Management DataTable
      const SettingsSection(),                   // Settings
    ];

    final List<String> _pageTitles = [
      'POS System',
      'Inventory',
      'Sales Reports',
      'User Management',
      'Settings',
    ];

    final List<IconData> _pageIcons = [
      Icons.point_of_sale,
      Icons.inventory_2,
      Icons.analytics,
      Icons.people,
      Icons.settings,
    ];

    @override
    Widget build(BuildContext context) {
      final size = MediaQuery.of(context).size;
      final isDesktop = size.width > 1200;

      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: Colors.red.shade600,
          elevation: 0,
          title: Row(
            children: [
              Icon(_pageIcons[_selectedIndex], color: Colors.white),
              const SizedBox(width: 12),
              Text(
                _pageTitles[_selectedIndex],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          actions: [
            // Admin badge
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Admin',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
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
              },
              tooltip: 'Logout',
            ),
          ],
        ),
        body: isDesktop
            ? Row(
                children: [
                  // Desktop Sidebar
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: Colors.white,
                    selectedIconTheme: IconThemeData(color: Colors.red.shade600),
                    selectedLabelTextStyle: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                    destinations: List.generate(
                      _pageTitles.length,
                      (index) => NavigationRailDestination(
                        icon: Icon(_pageIcons[index]),
                        label: Text(_pageTitles[index]),
                      ),
                    ),
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  // Content area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: _pages[_selectedIndex],
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(12.0),
                child: _pages[_selectedIndex],
              ),
        bottomNavigationBar: isDesktop
            ? null
            : NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                destinations: List.generate(
                  _pageTitles.length,
                  (index) => NavigationDestination(
                    icon: Icon(
                      _pageIcons[index],
                      color: _selectedIndex == index ? Colors.red.shade600 : null,
                    ),
                    label: _pageTitles[index],
                  ),
                ),
              ),
      );
    }
  }

  // -----------------------------
  // Placeholder Settings Section
  // -----------------------------
  class SettingsSection extends StatelessWidget {
    const SettingsSection({super.key});

    @override
    Widget build(BuildContext context) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon...',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
  }
