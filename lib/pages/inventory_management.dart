import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool _isAdmin = false;
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static const List<String> categories = [
    'All',
    'Perishable Ingredients',
    'Non-perishable Ingredients',
    'Beverages',
  ];

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final res = await Supabase.instance.client
        .from('users')
        .select('role')
        .eq('email', user.email!)
        .maybeSingle();

    if (!mounted) return;
    final role = (res?['role'] ?? '').toString().toLowerCase();
    setState(() => _isAdmin = role == 'admin' || role == 'adm');
  }

  void _addOrEditItem({Map<String, dynamic>? item}) {
    final nameCtrl = TextEditingController(text: item?['name'] ?? '');
    final catCtrl = TextEditingController(text: item?['category'] ?? '');
    final qtyCtrl = TextEditingController(text: item?['quantity']?.toString() ?? '');
    final unitCtrl = TextEditingController(text: item?['unit'] ?? '');

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.isMobile(context) ? double.infinity : 400,
            maxHeight: ResponsiveUtils.isMobile(context) ? MediaQuery.of(context).size.height * 0.8 : 600,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item == null ? 'Add Item' : 'Edit Item',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _input(nameCtrl, 'Item Name', Icons.inventory_2_outlined),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: catCtrl.text.isEmpty ? null : catCtrl.text,
                        decoration: _decoration('Category', Icons.category_outlined),
                        items: categories.where((cat) => cat != 'All').map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) catCtrl.text = value;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _input(qtyCtrl, 'Quantity', Icons.numbers, isNumber: true),
                      const SizedBox(height: 16),
                      
                      _input(unitCtrl, 'Unit', Icons.straighten),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final qty = int.tryParse(qtyCtrl.text);
                      if (nameCtrl.text.isEmpty ||
                          catCtrl.text.isEmpty ||
                          unitCtrl.text.isEmpty ||
                          qty == null) return;

                      final user = Supabase.instance.client.auth.currentUser;

                      final payload = {
                        'name': nameCtrl.text.trim(),
                        'category': catCtrl.text.trim(),
                        'quantity': qty,
                        'unit': unitCtrl.text.trim(),
                        'created_by': user?.email,
                        'created_at': DateTime.now().toIso8601String(),
                      };

                      if (item == null) {
                        await Supabase.instance.client.from('inventory').insert(payload);
                      } else {
                        await Supabase.instance.client
                            .from('inventory')
                            .update(payload)
                            .eq('id', item['id']);
                      }

                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.primaryRed),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.lightGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.primaryRed),
      ),
      filled: true,
      fillColor: AppTheme.backgroundColor,
    );
  }

  Widget _input(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: _decoration(label, icon),
    );
  }

  Future<void> _deleteItem(String id) async {
    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.from('inventory').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getStockStatus(int quantity) {
    if (quantity == 0) return '0';
    if (quantity < 10) return 'LOW STOCK';
    if (quantity < 50) return 'NORMAL';
    return 'HIGH STOCK';
  }

  Color _getStockStatusColor(int quantity) {
    if (quantity == 0) return AppTheme.errorRed;
    if (quantity < 10) return AppTheme.warningOrange;
    if (quantity < 50) return AppTheme.infoBlue;
    return AppTheme.successGreen;
  }

  IconData _getStockStatusIcon(int quantity) {
    if (quantity == 0) return Icons.remove_circle_rounded;
    if (quantity < 10) return Icons.warning_amber_rounded;
    if (quantity < 50) return Icons.inventory_2_rounded;
    return Icons.check_circle_rounded;
  }

  Widget _buildCompactMonitorCard(String range, String count, Color color) {
    String label;
    switch (range) {
      case '0':
        label = '0';
        break;
      case '1-9':
        label = 'LOW STOCK';
        break;
      case '10-49':
        label = 'NORMAL';
        break;
      case '50+':
        label = 'HIGH STOCK';
        break;
      default:
        label = 'UNKNOWN';
    }
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.white.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: AppTheme.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Real-time Inventory Monitoring Board
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryRed,
                    AppTheme.primaryRedDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryRed.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dashboard_rounded, color: AppTheme.white, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Inventory Monitor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.white,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.refresh_rounded, color: AppTheme.white.withOpacity(0.8), size: 14),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client
                        .from('inventory')
                        .stream(primaryKey: ['id']),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 50,
                          child: Center(
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(color: AppTheme.white, strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final items = snapshot.data!;
                      int outOfStock = 0;
                      int lowStock = 0;
                      int normalStock = 0;
                      int highStock = 0;

                      for (var item in items) {
                        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                        if (quantity == 0) {
                          outOfStock++;
                        } else if (quantity < 10) {
                          lowStock++;
                        } else if (quantity < 50) {
                          normalStock++;
                        } else {
                          highStock++;
                        }
                      }

                      return SizedBox(
                        height: 50,
                        child: Row(
                          children: [
                            Expanded(child: _buildCompactMonitorCard('0', outOfStock.toString(), AppTheme.errorRed)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildCompactMonitorCard('1-9', lowStock.toString(), AppTheme.warningOrange)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildCompactMonitorCard('10-49', normalStock.toString(), AppTheme.successGreen)),
                            const SizedBox(width: 6),
                            Expanded(child: _buildCompactMonitorCard('50+', highStock.toString(), AppTheme.infoBlue)),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Search and Filter Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
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
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryRed),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppTheme.mediumGrey),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.lightGrey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.primaryRed),
                      ),
                      filled: true,
                      fillColor: AppTheme.backgroundColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => _selectedCategory = category);
                            },
                            backgroundColor: AppTheme.white,
                            selectedColor: AppTheme.primaryRed.withOpacity(0.2),
                            checkmarkColor: AppTheme.primaryRed,
                            labelStyle: TextStyle(
                              color: isSelected ? AppTheme.primaryRed : AppTheme.darkGrey,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: isSelected ? AppTheme.primaryRed : AppTheme.lightGrey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            // Inventory Grid
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('inventory')
                    .stream(primaryKey: ['id'])
                    .order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading inventory: ${snapshot.error}',
                        style: const TextStyle(color: AppTheme.errorRed),
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];
                  final filteredItems = items.where((item) {
                    final name = (item['name'] ?? '').toString().toLowerCase();
                    final category = (item['category'] ?? '').toString().toLowerCase();
                    final query = _searchQuery.toLowerCase();
                    final matchesSearch = name.contains(query) || category.contains(query);
                    final matchesCategory = _selectedCategory == 'All' || 
                                         item['category']?.toString() == _selectedCategory;
                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.mediumGrey),
                          const SizedBox(height: 16),
                          Text(
                            'No inventory items found',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.mediumGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: ResponsiveUtils.isMobile(context) ? 4 : ResponsiveUtils.isTablet(context) ? 5 : 6,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                        final stockStatus = _getStockStatus(quantity);
                        final stockColor = _getStockStatusColor(quantity);
                        final stockIcon = _getStockStatusIcon(quantity);

                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.white,
                                AppTheme.lightGrey.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.darkGrey.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: stockColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.darkGrey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_isAdmin)
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _addOrEditItem(item: item);
                                          } else if (value == 'delete') {
                                            _deleteItem(item['id'].toString());
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 16, color: AppTheme.primaryRed),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, size: 16, color: AppTheme.errorRed),
                                                SizedBox(width: 8),
                                                Text('Delete'),
                                              ],
                                            ),
                                          ),
                                        ],
                                        child: const Icon(Icons.more_vert, size: 14, color: AppTheme.mediumGrey),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['category'] ?? 'Uncategorized',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.mediumGrey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: stockColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: stockColor.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(stockIcon, size: 10, color: stockColor),
                                          const SizedBox(width: 2),
                                          Text(
                                            stockStatus,
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                              color: stockColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$quantity ${item['unit'] ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryRed,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _addOrEditItem(),
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: AppTheme.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            )
          : null,
    );
  }
}
