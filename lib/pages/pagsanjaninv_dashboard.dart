import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/pages/inventory_management.dart';
import 'package:yang_chow/pages/inventory_forecast_page.dart';
import 'package:yang_chow/pages/inventory_room_page.dart';

class PagsanjaninvDashboardPage extends StatefulWidget {
  const PagsanjaninvDashboardPage({super.key});

  @override
  State<PagsanjaninvDashboardPage> createState() => _PagsanjaninvDashboardPageState();
}

class _PagsanjaninvDashboardPageState extends State<PagsanjaninvDashboardPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _userName = 'Admin';
  int _totalInventoryItems = 0;
  int _lowStockItems = 0;
  int _outOfStockItems = 0;
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        setState(() {
          _userName = user.email?.split('@')[0] ?? 'Admin';
        });
      }

      // Get inventory statistics
      final inventoryResponse = await _supabase
          .from('inventory')
          .select('quantity');

      if (inventoryResponse.isNotEmpty) {
        int total = 0;
        int lowStock = 0;
        int outOfStock = 0;

        for (var item in inventoryResponse) {
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          total++;
          if (quantity == 0) {
            outOfStock++;
          } else if (quantity < 10) {
            lowStock++;
          }
        }

        setState(() {
          _totalInventoryItems = total;
          _lowStockItems = lowStock;
          _outOfStockItems = outOfStock;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    // Show confirmation dialog
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout, color: AppTheme.primaryRed, size: 24),
              const SizedBox(width: 12),
              const Text('Confirm Logout'),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout from the Inventory Management System?',
            style: TextStyle(fontSize: 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.mediumGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    // Only logout if user confirmed
    if (shouldLogout == true) {
      try {
        await Supabase.instance.client.auth.signOut();
        try {
          await GoogleSignIn().signOut();
        } catch (_) {}
        
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> _getPages() {
    return [
      _buildDashboardPage(),
      const InventoryPage(),
      const InventoryForecastPage(),
      const InventoryRoomPage(),
    ];
  }

  Widget _buildDashboardPage() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppTheme.primaryRed,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simple Stats Cards
            Row(
              children: [
                Expanded(child: _buildSimpleStatCard('Total Items', _totalInventoryItems.toString(), AppTheme.primaryRed)),
                const SizedBox(width: 12),
                Expanded(child: _buildSimpleStatCard('Low Stock', _lowStockItems.toString(), AppTheme.warningOrange)),
                const SizedBox(width: 12),
                Expanded(child: _buildSimpleStatCard('Out of Stock', _outOfStockItems.toString(), AppTheme.errorRed)),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildSimpleActionCard(
                    title: 'Manage Inventory',
                    icon: Icons.inventory,
                    color: AppTheme.primaryRed,
                    onTap: () => _onItemTapped(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSimpleActionCard(
                    title: 'View Forecast',
                    icon: Icons.trending_up,
                    color: AppTheme.infoBlue,
                    onTap: () => _onItemTapped(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSimpleActionCard(
                    title: 'Room Inventory',
                    icon: Icons.room,
                    color: AppTheme.warningOrange,
                    onTap: () => _onItemTapped(3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkGrey.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mediumGrey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.white,
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkGrey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.mediumGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    
    if (isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Row(
        children: [
          // Compact Sidebar
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.darkGrey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Compact Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.inventory_2,
                          color: AppTheme.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Inventory',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.white,
                        ),
                      ),
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(color: AppTheme.white, height: 1),
                
                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildCompactSidebarItem(
                        icon: Icons.dashboard,
                        title: 'Dashboard',
                        index: 0,
                      ),
                      _buildCompactSidebarItem(
                        icon: Icons.inventory,
                        title: 'Inventory',
                        index: 1,
                      ),
                      _buildCompactSidebarItem(
                        icon: Icons.trending_up,
                        title: 'Forecast',
                        index: 2,
                      ),
                      _buildCompactSidebarItem(
                        icon: Icons.room,
                        title: 'Rooms',
                        index: 3,
                      ),
                    ],
                  ),
                ),
                
                // Logout Button
                Container(
                  padding: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: AppTheme.white, size: 20),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    onTap: _signOut,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.darkGrey.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedIndex == 0 ? Icons.dashboard :
                        _selectedIndex == 1 ? Icons.inventory :
                        _selectedIndex == 2 ? Icons.trending_up : Icons.room,
                        color: AppTheme.primaryRed,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedIndex == 0 ? 'Dashboard' :
                        _selectedIndex == 1 ? 'Manage Inventory' :
                        _selectedIndex == 2 ? 'Inventory Forecast' : 'Room Inventory',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedIndex == 0)
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppTheme.primaryRed, size: 20),
                          onPressed: _loadDashboardData,
                        ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: _isLoading && _selectedIndex == 0
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
                      : _getPages()[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: AppTheme.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.dashboard_rounded),
            const SizedBox(width: 8),
            Text(_selectedIndex == 0 ? 'Inventory Dashboard' : 
                 _selectedIndex == 1 ? 'Manage Inventory' :
                 _selectedIndex == 2 ? 'Inventory Forecast' : 'Room Inventory'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryRed,
                AppTheme.primaryRedDark,
              ],
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.inventory_2,
                        color: AppTheme.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Inventory Staff',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: AppTheme.white, height: 1),
              
              // Navigation Items
              ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shrinkWrap: true,
                children: [
                  _buildSidebarItem(
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    index: 0,
                  ),
                  _buildSidebarItem(
                    icon: Icons.inventory,
                    title: 'Manage Inventory',
                    index: 1,
                  ),
                  _buildSidebarItem(
                    icon: Icons.trending_up,
                    title: 'Inventory Forecast',
                    index: 2,
                  ),
                  _buildSidebarItem(
                    icon: Icons.room,
                    title: 'Room Inventory',
                    index: 3,
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Logout Button
              Container(
                padding: const EdgeInsets.all(16),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: AppTheme.white),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: _signOut,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading && _selectedIndex == 0
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : _getPages()[_selectedIndex],
    );
  }

  Widget _buildCompactSidebarItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.white : AppTheme.white.withOpacity(0.7),
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppTheme.white : AppTheme.white.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
        onTap: () => _onItemTapped(index),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: isSelected ? AppTheme.white.withOpacity(0.2) : Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.white : AppTheme.white.withOpacity(0.7),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppTheme.white : AppTheme.white.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        onTap: () => _onItemTapped(index),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: isSelected ? AppTheme.white.withOpacity(0.2) : Colors.transparent,
      ),
    );
  }
}
