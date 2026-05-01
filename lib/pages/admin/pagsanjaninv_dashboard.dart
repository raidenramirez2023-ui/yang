import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:yang_chow/utils/app_theme.dart';

import 'package:yang_chow/utils/responsive_utils.dart';

import 'package:yang_chow/pages/staff/inventory_management.dart';

import 'package:yang_chow/pages/staff/inventory_room_page.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:intl/intl.dart';



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

  int _currentPage = 1;

  int _itemsPerPage = 15;



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

          Navigator.of(context).pushReplacementNamed('/staff-login');

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

      const InventoryPage(),

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

                    onTap: () => _onItemTapped(2),

                  ),

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: _buildSimpleActionCard(

                    title: 'View Storage Room',

                    icon: Icons.warehouse,

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
    return _HoverableActionCard(
      title: title,
      icon: icon,
      color: color,
      onTap: onTap,
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

        border: Border.all(color: statusColor.withOpacity(0.3)),

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

                  color: statusColor.withOpacity(0.1),

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
      if (newStatus == 'Approved') {
        final request = await _supabase
            .from('kitchen_requests')
            .select()
            .eq('id', requestId)
            .single();

        // Check stock availability before approving
        final itemName = request['item_name']?.toString();
        final quantityNeeded = (request['quantity_needed'] as num?)?.toInt() ?? 0;

        if (itemName != null) {
          if (quantityNeeded == 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot approve: Requested quantity is 0.'),
                  backgroundColor: AppTheme.errorRed,
                ),
              );
            }
            return; // Don't proceed with approval if quantity is 0
          }

          final inventoryItems = await _supabase
              .from('inventory')
              .select('id, quantity')
              .ilike('name', '%$itemName%')
              .limit(1);

          if (inventoryItems.isNotEmpty) {
            final inventoryItem = inventoryItems.first;
            final currentQuantity = (inventoryItem['quantity'] as num?)?.toInt() ?? 0;
            
            if (currentQuantity >= quantityNeeded) {
              // Sufficient stock - proceed with approval
              await _approveRequestCore(request);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request approved and stock transferred to kitchen!'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            } else {
              // Insufficient stock - show warning and keep request pending
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cannot approve: Insufficient stock. Only $currentQuantity available, $quantityNeeded needed.'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
              return; // Don't proceed with approval
            }
          } else {
            // Item not found in inventory
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot approve: Item not found in inventory.'),
                  backgroundColor: AppTheme.errorRed,
                ),
              );
            }
            return; // Don't proceed with approval
          }
        }
      } else {
        await _supabase
            .from('kitchen_requests')
            .update({'status': newStatus})
            .eq('id', requestId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request rejected.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
      
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  Future<void> _approveRequestCore(Map<String, dynamic> request) async {
    final itemName = request['item_name']?.toString();
    final quantityNeeded = (request['quantity_needed'] as num?)?.toInt() ?? 0;

    if (itemName != null && quantityNeeded > 0) {
      final inventoryItems = await _supabase
          .from('inventory')
          .select('id, quantity')
          .ilike('name', '%$itemName%')
          .limit(1);

      if (inventoryItems.isNotEmpty) {
        final inventoryItem = inventoryItems.first;
        final currentQuantity = (inventoryItem['quantity'] as num?)?.toInt() ?? 0;
        
        // Safety: Only transfer what is actually available in main inventory
        final transferQty = quantityNeeded > currentQuantity ? currentQuantity : quantityNeeded;
        final newQuantity = currentQuantity - transferQty;

        await _supabase
            .from('inventory')
            .update({'quantity': newQuantity})
            .eq('id', inventoryItem['id']);

        final fullInventoryItem = await _supabase
            .from('inventory')
            .select('name, category, unit')
            .eq('id', inventoryItem['id'])
            .single();

        final kitchenItem = await _supabase
            .from('kitchen_inventory')
            .select()
            .eq('name', fullInventoryItem['name'])
            .maybeSingle();

        if (kitchenItem != null) {
          final currentKitchenQty = (kitchenItem['quantity'] as num?)?.toInt() ?? 0;
          await _supabase
              .from('kitchen_inventory')
              .update({'quantity': currentKitchenQty + transferQty})
              .eq('id', kitchenItem['id']);
        } else {
          await _supabase.from('kitchen_inventory').insert({

            'name': fullInventoryItem['name'],

            'category': fullInventoryItem['category'],

            'unit': fullInventoryItem['unit'],

            'quantity': transferQty,

          });

        }



        await _supabase.from('stock_transactions').insert({

          'item_name': itemName,

          'quantity': transferQty,

          'transaction_type': 'outgoing',

          'purpose': 'Kitchen request approved (Amount served: $transferQty)',

          'requested_by': request['requested_by'],

          'processed_by': _supabase.auth.currentUser?.email,

          'created_at': DateTime.now().toIso8601String(),

        });



        await _supabase

            .from('kitchen_requests')

            .update({'status': 'Approved'})

            .eq('id', request['id']);

      }

    }

  }



  Future<void> _approveAllRequests() async {

    setState(() => _isLoading = true);

    try {

      final pendingRequests = await _supabase

          .from('kitchen_requests')

          .select()

          .eq('status', 'Pending');

      

      if (pendingRequests.isEmpty) {

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(content: Text('No pending requests to approve.')),

          );

        }

        setState(() => _isLoading = false);

        return;

      }



      int approvedCount = 0;

      int outOfStockCount = 0;



      for (var request in pendingRequests) {

        final itemName = request['item_name']?.toString();

        final quantityNeeded = (request['quantity_needed'] as num?)?.toInt() ?? 0;



        if (itemName != null) {
          if (quantityNeeded == 0) {
            // Count zero quantity requests as out of stock
            outOfStockCount++;
            continue;
          }

          // Check stock availability in pagsanjaninv inventory

          final inventoryItems = await _supabase

              .from('inventory')

              .select('id, quantity')

              .ilike('name', '%$itemName%')

              .limit(1);



          if (inventoryItems.isNotEmpty) {

            final inventoryItem = inventoryItems.first;

            final currentQuantity = (inventoryItem['quantity'] as num?)?.toInt() ?? 0;



            // Only approve if there's sufficient stock

            if (currentQuantity >= quantityNeeded) {

              await _approveRequestCore(request);

              approvedCount++;

            } else {

              // Keep request in pending state if out of stock

              outOfStockCount++;

            }

          } else {

            // Keep request in pending state if item not found in inventory

            outOfStockCount++;

          }

        }

      }



      if (mounted) {

        String message;

        Color backgroundColor;



        if (approvedCount > 0 && outOfStockCount > 0) {

          message = 'Approved $approvedCount requests successfully! $outOfStockCount requests remain pending due to insufficient stock.';

          backgroundColor = AppTheme.warningOrange;

        } else if (approvedCount > 0) {

          message = 'Approved $approvedCount requests successfully!';

          backgroundColor = AppTheme.successGreen;

        } else {

          message = 'No requests approved. All $outOfStockCount requests remain pending due to insufficient stock.';

          backgroundColor = AppTheme.errorRed;

        }



        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(message),

            backgroundColor: backgroundColor,

          ),

        );

      }



      _loadDashboardData();

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Bulk Error: $e'), backgroundColor: AppTheme.errorRed),

        );

      }

    } finally {

      if (mounted) setState(() => _isLoading = false);

    }

  }



  Future<void> _rejectAllRequests() async {

    setState(() => _isLoading = true);
    
    try {
      final pendingRequests = await _supabase
          .from('kitchen_requests')
          .select('id, item_name')
          .eq('status', 'Pending');
      
      if (pendingRequests.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pending requests to reject.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Reject all pending requests
      for (var request in pendingRequests) {
        await _supabase
            .from('kitchen_requests')
            .update({'status': 'Rejected'})
            .eq('id', request['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected ${pendingRequests.length} requests successfully!'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk Error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

                        icon: Icons.shopping_cart,

                        title: 'Kitchen Requests',

                        index: 1,

                      ),

                      _buildCompactSidebarItem(

                        icon: Icons.inventory,

                        title: 'Inventory',

                        index: 2,

                      ),

                      _buildCompactSidebarItem(

                        icon: Icons.warehouse,

                        title: 'Storage Room',

                        index: 3,

                      ),

                      _buildCompactSidebarLogoutItem(),

                      
                    ],

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

                        _selectedIndex == 1 ? Icons.shopping_cart :

                        _selectedIndex == 2 ? Icons.inventory :

                        Icons.warehouse,

                        color: AppTheme.primaryColor,

                        size: 20,

                      ),

                      const SizedBox(width: 8),

                      Text(

                        _selectedIndex == 0 ? 'Dashboard' :

                        _selectedIndex == 1 ? 'Kitchen Stock Requests' :

                        _selectedIndex == 2 ? 'Manage Inventory' :

                        'Storage Room',

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

                      _buildNotificationIcon(AppTheme.primaryColor),

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
        title: Row(
          children: [
            const Icon(Icons.dashboard_rounded),
            const SizedBox(width: 8),
            const Text('Inventory Dashboard'),
          ],
        ),
        actions: [
          _buildNotificationIcon(Colors.white),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
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
                    icon: Icons.shopping_cart,
                    title: 'Kitchen Requests',
                    index: 1,
                  ),
                  _buildSidebarItem(
                    icon: Icons.inventory,
                    title: 'Manage Inventory',
                    index: 2,
                  ),
                  _buildSidebarItem(
                    icon: Icons.warehouse,
                    title: 'Storage Room',
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



  Widget _buildCompactSidebarLogoutItem() {

    return Container(

      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

      child: ListTile(

        leading: const Icon(

          Icons.logout,

          color: AppTheme.white,

          size: 20,

        ),

        title: const Text(

          'Logout',

          style: TextStyle(

            color: AppTheme.white,

            fontWeight: FontWeight.w600,

            fontSize: 13,

          ),

        ),

        onTap: _signOut,

        shape: RoundedRectangleBorder(

          borderRadius: BorderRadius.circular(8),

        ),

        tileColor: Colors.transparent,

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



  Widget _buildKitchenRequestsPage() {

    return RefreshIndicator(

      onRefresh: _loadDashboardData,

      color: AppTheme.primaryColor,

      child: SingleChildScrollView(

        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

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

                  ],

                ),

                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _approveAllRequests,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Approve All', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _rejectAllRequests,
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Reject All', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),

              ],

            ),

            const SizedBox(height: 24),

            // Request Counter
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('kitchen_requests')
                  .stream(primaryKey: ['id'])
                  .eq('status', 'Pending'),
              builder: (context, snapshot) {
                final pendingCount = snapshot.data?.length ?? 0;
                return Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Total Pending Requests: $pendingCount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      if (pendingCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.warningOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

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

                  // Sort requests: Pending first, then Approved, then Rejected
                  requests.sort((a, b) {
                    final statusA = a['status']?.toString() ?? 'Pending';
                    final statusB = b['status']?.toString() ?? 'Pending';
                    
                    // Priority order: Pending (1), Approved (2), Rejected (3)
                    final priorityA = statusA == 'Pending' ? 1 : statusA == 'Approved' ? 2 : 3;
                    final priorityB = statusB == 'Pending' ? 1 : statusB == 'Approved' ? 2 : 3;
                    
                    if (priorityA != priorityB) {
                      return priorityA.compareTo(priorityB);
                    }
                    
                    // Within same status, sort by created_at descending (newest first)
                    final createdAtA = DateTime.parse(a['created_at']?.toString() ?? DateTime.now().toIso8601String());
                    final createdAtB = DateTime.parse(b['created_at']?.toString() ?? DateTime.now().toIso8601String());
                    return createdAtB.compareTo(createdAtA);
                  });

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

                  

                  final totalPages = (requests.length / _itemsPerPage).ceil();

                  final startIndex = (_currentPage - 1) * _itemsPerPage;
                  final endIndex = startIndex + _itemsPerPage;
                  final paginatedRequests = requests.sublist(
                    startIndex,
                    endIndex > requests.length ? requests.length : endIndex,
                  );

                  return Column(

                    children: [

                      ...paginatedRequests.map((request) => _buildRequestCard(request)).toList(),
                      
                      if (totalPages > 1) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: _currentPage > 1
                                    ? () {
                                        setState(() {
                                          _currentPage--;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.chevron_left),
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 50,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primaryColor),
                                ),
                                child: TextField(
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkGrey,
                                  ),
                                  controller: TextEditingController(text: _currentPage.toString()),
                                  onSubmitted: (value) {
                                    final page = int.tryParse(value);
                                    if (page != null && page >= 1 && page <= totalPages) {
                                      setState(() {
                                        _currentPage = page;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'of $totalPages',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkGrey,
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: _currentPage < totalPages
                                    ? () {
                                        setState(() {
                                          _currentPage++;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.chevron_right),
                                color: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ],
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



  Widget _buildNotificationIcon(Color iconColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService.getAdminNotificationsStream(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n['is_read']).length;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0 ? Icons.notifications_active : Icons.notifications,
                color: iconColor,
              ),
              onPressed: () => _showNotificationsDialog(notifications),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsDialog(List<Map<String, dynamic>> notifications) {
    NotificationService.markAllAsRead('', forAdmin: true);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inventory Notifications'),
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
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Icon(
                          _getIconForAction(n['action_type']),
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
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
                          Text(_getNotificationSubtitle(n)),
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
      case 'stock_request':
        return Icons.inventory_2;
      case 'pos_order':
        return Icons.shopping_cart;
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

  String _getNotificationTitle(Map<String, dynamic> n) {
    if (n['action_type'] == 'stock_request') {
      return 'Stock Request';
    }
    if (n['action_type'] == 'pos_order') {
      return 'New Order';
    }
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

  String _getNotificationSubtitle(Map<String, dynamic> n) {
    if (n['action_type'] == 'stock_request') {
      return 'Kitchen has requested stock: ${n['event_type']}';
    }
    if (n['action_type'] == 'pos_order') {
      return 'POS staff have order please process';
    }
    return '${n['actor_name'] ?? 'System'} ${n['action_type']} reservation for ${n['event_type'] ?? 'Event'}';
  }
}

class _HoverableActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HoverableActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HoverableActionCard> createState() => _HoverableActionCardState();
}

class _HoverableActionCardState extends State<_HoverableActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered ? widget.color.withOpacity(0.1) : AppTheme.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered ? widget.color : widget.color.withOpacity(0.3),
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered 
                    ? widget.color.withOpacity(0.2)
                    : AppTheme.darkGrey.withOpacity(0.05),
                blurRadius: _isHovered ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(_isHovered ? 4 : 0),
                decoration: BoxDecoration(
                  color: _isHovered ? widget.color.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon, 
                  color: widget.color, 
                  size: _isHovered ? 28 : 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}




