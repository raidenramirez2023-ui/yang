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
      debugPrint('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.logout, color: AppTheme.primaryColor, size: 24),
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
              child: const Text(
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
                backgroundColor: AppTheme.primaryColor,
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
      _buildKitchenRequestsPage(),
      _buildOutgoingPage(),
      const InventoryPage(),
      const InventoryForecastPage(),
      const InventoryRoomPage(),
    ];
  }

  Widget _buildDashboardPage() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simple Stats Cards
            Row(
              children: [
                Expanded(child: _buildSimpleStatCard('Total Items', _totalInventoryItems.toString(), AppTheme.primaryColor)),
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
                    title: 'Kitchen Requests',
                    icon: Icons.shopping_cart,
                    color: AppTheme.primaryColor,
                    onTap: () => _onItemTapped(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSimpleActionCard(
                    title: 'Manage Inventory',
                    icon: Icons.inventory,
                    color: AppTheme.infoBlue,
                    onTap: () => _onItemTapped(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSimpleActionCard(
                    title: 'View Forecast',
                    icon: Icons.trending_up,
                    color: AppTheme.warningOrange,
                    onTap: () => _onItemTapped(4),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkGrey.withValues(alpha: 0.05),
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

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status']?.toString() ?? 'Pending';
    final priority = request['priority']?.toString() ?? 'Normal';
    final itemName = request['item_name']?.toString() ?? 'Unknown';
    final quantity = request['quantity_needed']?.toString() ?? '0';
    final unit = request['unit']?.toString() ?? 'pcs';
    final requestedBy = request['requested_by']?.toString() ?? 'Unknown';
    final createdAt = request['created_at']?.toString();
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'Approved':
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = AppTheme.errorRed;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppTheme.warningOrange;
        statusIcon = Icons.pending;
    }
    
    Color priorityColor;
    switch (priority) {
      case 'Urgent':
        priorityColor = AppTheme.errorRed;
        break;
      case 'High':
        priorityColor = AppTheme.warningOrange;
        break;
      case 'Low':
        priorityColor = AppTheme.infoBlue;
        break;
      default:
        priorityColor = AppTheme.primaryColor;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$quantity $unit',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Priority: $priority',
                style: TextStyle(
                  fontSize: 12,
                  color: priorityColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Requested by: $requestedBy',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.mediumGrey,
            ),
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Time: ${DateTime.parse(createdAt).toString().substring(0, 16)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.mediumGrey,
              ),
            ),
          ],
          if (status == 'Pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleRequestAction(request['id'], 'Approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 32),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleRequestAction(request['id'], 'Rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      minimumSize: const Size(0, 32),
                      side: const BorderSide(color: AppTheme.errorRed),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleRequestAction(String requestId, String newStatus) async {
    try {
      // First, get the request details to know what item to update
      final request = await _supabase
          .from('kitchen_requests')
          .select()
          .eq('id', requestId)
          .single();
      
      // Update the request status
      await _supabase
          .from('kitchen_requests')
          .update({'status': newStatus})
          .eq('id', requestId);
      
      if (newStatus == 'Approved') {
        // Find the inventory item and reduce its quantity
        final itemName = request['item_name']?.toString();
        final quantityNeeded = (request['quantity_needed'] as num?)?.toInt() ?? 0;
        
        if (itemName != null && quantityNeeded > 0) {
          // Find the inventory item by name
          final inventoryItems = await _supabase
              .from('inventory')
              .select('id, quantity')
              .ilike('name', '%$itemName%')
              .limit(1);
          
          if (inventoryItems.isNotEmpty) {
            final inventoryItem = inventoryItems.first;
            final currentQuantity = (inventoryItem['quantity'] as num?)?.toInt() ?? 0;
            final newQuantity = currentQuantity - quantityNeeded;
            
            // Update the inventory quantity
            await _supabase
                .from('inventory')
                .update({'quantity': newQuantity})
                .eq('id', inventoryItem['id']);
            
            // Create stock transaction record for forecasting
            await _supabase
                .from('stock_transactions')
                .insert({
                  'item_name': itemName,
                  'quantity': quantityNeeded,
                  'transaction_type': 'outgoing',
                  'purpose': 'Kitchen request approved',
                  'requested_by': request['requested_by'],
                  'processed_by': _supabase.auth.currentUser?.email,
                  'created_at': DateTime.now().toIso8601String(),
                });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Request approved! $quantityNeeded $itemName removed from inventory.'),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Request approved but item not found in inventory.'),
                  backgroundColor: AppTheme.warningOrange,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Request approved but invalid item data.'),
                backgroundColor: AppTheme.warningOrange,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request rejected.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
      
      // Refresh dashboard data
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

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
              color: AppTheme.primaryColor,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.darkGrey.withValues(alpha: 0.1),
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
                          color: AppTheme.white.withValues(alpha: 0.2),
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
                        icon: Icons.shopping_cart,
                        title: 'Kitchen Requests',
                        index: 1,
                      ),
                      _buildCompactSidebarItem(
                        icon: Icons.outbox,
                        title: 'Outgoing',
                        index: 2,
                      ),
                      _buildCompactSidebarItem(
                        icon: Icons.inventory,
                        title: 'Inventory',
                        index: 3,
                      ),
                      _buildCompactSidebarItem(
                        icon: Icons.trending_up,
                        title: 'Forecast',
                        index: 4,
                      ),
                      _buildCompactSidebarItem(
                        icon: Icons.room,
                        title: 'Rooms',
                        index: 5,
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
                        color: AppTheme.darkGrey.withValues(alpha: 0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedIndex == 0 ? Icons.dashboard :
                        _selectedIndex == 1 ? Icons.shopping_cart :
                        _selectedIndex == 2 ? Icons.outbox :
                        _selectedIndex == 3 ? Icons.inventory :
                        _selectedIndex == 4 ? Icons.trending_up : Icons.room,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedIndex == 0 ? 'Dashboard' :
                        _selectedIndex == 1 ? 'Kitchen Stock Requests' :
                        _selectedIndex == 2 ? 'Outgoing Items' :
                        _selectedIndex == 3 ? 'Manage Inventory' :
                        _selectedIndex == 4 ? 'Inventory Forecast' : 'Room Inventory',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedIndex == 0)
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppTheme.primaryColor, size: 20),
                          onPressed: _loadDashboardData,
                        ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: _isLoading && _selectedIndex == 0
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
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
        backgroundColor: AppTheme.primaryColor,
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
                AppTheme.primaryColor,
                AppTheme.primaryDark,
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
                        color: AppTheme.white.withValues(alpha: 0.2),
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
                    icon: Icons.shopping_cart,
                    title: 'Kitchen Requests',
                    index: 1,
                  ),
                  _buildSidebarItem(
                    icon: Icons.outbox,
                    title: 'Outgoing',
                    index: 2,
                  ),
                  _buildSidebarItem(
                    icon: Icons.inventory,
                    title: 'Manage Inventory',
                    index: 3,
                  ),
                  _buildSidebarItem(
                    icon: Icons.trending_up,
                    title: 'Inventory Forecast',
                    index: 4,
                  ),
                  _buildSidebarItem(
                    icon: Icons.room,
                    title: 'Room Inventory',
                    index: 5,
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
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
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
          color: isSelected ? AppTheme.white : AppTheme.white.withValues(alpha: 0.7),
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppTheme.white : AppTheme.white.withValues(alpha: 0.7),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
        onTap: () => _onItemTapped(index),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: isSelected ? AppTheme.white.withValues(alpha: 0.2) : Colors.transparent,
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
          color: isSelected ? AppTheme.white : AppTheme.white.withValues(alpha: 0.7),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppTheme.white : AppTheme.white.withValues(alpha: 0.7),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        onTap: () => _onItemTapped(index),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: isSelected ? AppTheme.white.withValues(alpha: 0.2) : Colors.transparent,
      ),
    );
  }

  Widget _buildKitchenRequestsPage() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Kitchen Stock Requests',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage stock requests from the kitchen team',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mediumGrey,
              ),
            ),
            const SizedBox(height: 24),

            // All Requests Container
            Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.lightGrey),
              ),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabase
                    .from('kitchen_requests')
                    .stream(primaryKey: ['id'])
                    .order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                    );
                  }
                  
                  final requests = snapshot.data ?? [];
                  if (requests.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 60, color: AppTheme.mediumGrey),
                          const SizedBox(height: 16),
                          Text(
                            'No stock requests',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.mediumGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kitchen team hasn\'t requested any items yet',
                            style: TextStyle(color: AppTheme.mediumGrey),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return Column(
                    children: requests.map((request) => _buildRequestCard(request)).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutgoingPage() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Outgoing Items',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Items that have been approved and given to the kitchen',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mediumGrey,
              ),
            ),
            const SizedBox(height: 24),

            // Outgoing Items Container
            Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.lightGrey),
              ),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabase
                    .from('kitchen_requests')
                    .stream(primaryKey: ['id'])
                    .eq('status', 'Approved')
                    .order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                    );
                  }
                  
                  final approvedRequests = snapshot.data ?? [];
                  if (approvedRequests.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.outbox_outlined, size: 60, color: AppTheme.mediumGrey),
                          const SizedBox(height: 16),
                          Text(
                            'No outgoing items',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.mediumGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No items have been approved and given to the kitchen yet',
                            style: TextStyle(color: AppTheme.mediumGrey),
                          ),
                        ],
                      ),
                    );
                  }

                  // Calculate totals
                  int totalItems = 0;
                  final Map<String, int> itemTotals = {};
                  final Map<String, String> itemUnits = {};
                  
                  for (final request in approvedRequests) {
                    final itemName = request['item_name']?.toString() ?? '';
                    final quantity = (request['quantity_needed'] as num?)?.toInt() ?? 0;
                    final unit = request['unit']?.toString() ?? 'pcs';
                    
                    totalItems += quantity;
                    itemTotals[itemName] = (itemTotals[itemName] ?? 0) + quantity;
                    itemUnits[itemName] = unit;
                  }

                  return Column(
                    children: [
                      // Summary Card
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.outbox, color: AppTheme.successGreen, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Items Given Out',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.successGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '$totalItems items across ${itemTotals.keys.length} different products',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.darkGrey,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Item Summary List
                      ...itemTotals.entries.map((entry) {
                        final itemName = entry.key;
                        final totalQuantity = entry.value;
                        final unit = itemUnits[itemName] ?? 'pcs';
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.lightGrey),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.darkGrey,
                                      ),
                                    ),
                                    Text(
                                      'Total given: $totalQuantity $unit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.mediumGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$totalQuantity $unit',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Detailed Request List
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Detailed Request History',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGrey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...approvedRequests.map((request) => _buildOutgoingCard(request)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutgoingCard(Map<String, dynamic> request) {
    final itemName = request['item_name']?.toString() ?? '';
    final quantity = (request['quantity_needed'] as num?)?.toInt() ?? 0;
    final unit = request['unit']?.toString() ?? 'pcs';
    final requestedBy = request['requested_by']?.toString() ?? 'Unknown';
    final createdAt = request['created_at']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
              Icon(Icons.check_circle, color: AppTheme.successGreen, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.darkGrey,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Approved',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quantity: $quantity $unit',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkGrey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Given to: $requestedBy',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.mediumGrey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Date: ${DateTime.parse(createdAt).toString().substring(0, 10)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.mediumGrey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
