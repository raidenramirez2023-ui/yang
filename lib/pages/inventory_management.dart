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

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final userResponse = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('email', user.email!)
            .maybeSingle();

        if (userResponse != null && mounted) {
          final userRole = userResponse['role']?.toString() ?? '';
          setState(() {
            _isAdmin = userRole.toLowerCase() == 'admin' || userRole.toLowerCase() == 'adm';
          });
        }
      } catch (e) {
        if (mounted) setState(() {});
      }
    }
  }

  void _addOrEditItem({Map<String, dynamic>? item}) {
    final nameController = TextEditingController(text: item?['name']);
    final categoryController = TextEditingController(text: item?['category']);
    final quantityController =
        TextEditingController(text: item?['quantity']?.toString());
    final unitController = TextEditingController(text: item?['unit']);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.isMobile(context) ? double.infinity : 500,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: AppTheme.primaryRed,
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Text(
                        item == null ? 'Add Inventory Item' : 'Edit Inventory Item',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.lg),
                _buildDialogTextField(
                  label: 'Item Name',
                  controller: nameController,
                  icon: Icons.inventory_2,
                ),
                const SizedBox(height: AppTheme.lg),
                _buildDialogTextField(
                  label: 'Category',
                  controller: categoryController,
                  icon: Icons.category,
                  readOnly: true,
                  hintText: 'Select from categories below',
                ),
                const SizedBox(height: AppTheme.lg),
                Container(
                  padding: const EdgeInsets.all(AppTheme.md),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                        color: AppTheme.primaryRed.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Categories:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryRed,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: categories
                            .where((cat) => cat != 'All')
                            .map((category) {
                          return ActionChip(
                            label: Text(
                              category,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              categoryController.text = category;
                            },
                            backgroundColor:
                                AppTheme.primaryRed.withValues(alpha: 0.1),
                            side: BorderSide(
                                color:
                                    AppTheme.primaryRed.withValues(alpha: 0.3)),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.lg),
                _buildDialogTextField(
                  label: 'Quantity',
                  controller: quantityController,
                  icon: Icons.numbers,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppTheme.lg),
                _buildDialogTextField(
                  label: 'Unit (kg, pcs, etc.)',
                  controller: unitController,
                  icon: Icons.straighten,
                ),
                const SizedBox(height: AppTheme.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.lg,
                          vertical: AppTheme.md,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppTheme.md),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Item name is required')),
                          );
                          return;
                        }

                        final user = Supabase.instance.client.auth.currentUser;
                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please login to add items')),
                          );
                          return;
                        }

                        final newItem = {
                          'name': nameController.text.trim(),
                          'category': categoryController.text.trim(),
                          'quantity': int.tryParse(quantityController.text) ?? 0,
                          'unit': unitController.text.trim(),
                          'createdBy': user.email,
                          'createdAt': DateTime.now().toIso8601String(),
                        };

                        // Capture navigator and messenger before async gap
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);

                        try {
                          if (item == null) {
                            await Supabase.instance.client.from('inventory').insert(newItem);
                          } else {
                            await Supabase.instance.client
                                .from('inventory')
                                .update(newItem)
                                .eq('id', item['id']);
                          }

                          nav.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(item == null
                                  ? 'Item added successfully!'
                                  : 'Item updated successfully!'),
                              backgroundColor: AppTheme.successGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          nav.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error saving item: $e'),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.lg,
                          vertical: AppTheme.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: Text(item == null ? 'Add Item' : 'Update Item'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppTheme.primaryRed,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.white,
          contentPadding: const EdgeInsets.all(AppTheme.md),
        ),
      ),
    );
  }

  void _deleteItem(dynamic docId, String itemName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: AppTheme.errorRed,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppTheme.lg),
              Text(
                'Delete Item',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.md),
              Text(
                'Are you sure you want to delete "$itemName"?',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.mediumGrey,
                ),
              ),
              const SizedBox(height: AppTheme.lg),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      onPressed: () async {
                        // Capture navigator and messenger before async gap
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);

                        try {
                          await Supabase.instance.client.from('inventory').delete().eq('id', docId);
                          nav.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Item deleted successfully!'),
                              backgroundColor: AppTheme.successGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          nav.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error deleting item: $e'),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                        }
                      },
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStockColor(int qty) {
    if (qty == 0) return AppTheme.errorRed;
    if (qty <= 5) return AppTheme.warningOrange;
    return AppTheme.successGreen;
  }

  String _getStockLabel(int qty) {
    if (qty == 0) return 'Out of Stock';
    if (qty <= 5) return 'Low Stock';
    return 'In Stock';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                Icons.inventory_2,
                color: AppTheme.primaryRed,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.md),
            Text(
              isMobile ? 'Inventory' : 'Inventory Management',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
          ],
        ),
        actions: [
          if (!isMobile)
            Container(
              margin: const EdgeInsets.only(right: AppTheme.md),
              child: ElevatedButton.icon(
                onPressed: () => _addOrEditItem(),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: AppTheme.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Add Item',
        onPressed: () => _addOrEditItem(),
        backgroundColor: AppTheme.primaryRed,
        heroTag: "add",
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          // Stats Cards
          Container(
            width: double.infinity,
            padding: ResponsiveUtils.getResponsivePadding(context),
            decoration: BoxDecoration(
              color: AppTheme.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('inventory')
                  .stream(primaryKey: ['id']),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 80);
                }

                final items = snapshot.data!;
                final totalItems = items.length;
                final outOfStock = items.where((doc) => (doc['quantity'] ?? 0) == 0).length;
                final lowStock = items.where((doc) {
                  final qty = doc['quantity'] ?? 0;
                  return qty > 0 && qty <= 5;
                }).length;

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Total Items',
                        totalItems.toString(),
                        Icons.inventory_2,
                        AppTheme.primaryRed,
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Low Stock',
                          lowStock.toString(),
                          Icons.warning,
                          AppTheme.warningOrange,
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Out of Stock',
                          outOfStock.toString(),
                          Icons.error,
                          AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: ResponsiveUtils.getResponsivePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isMobile ? 'Inventory' : 'Inventory Management',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 20,
                              tablet: 24,
                              desktop: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ResponsiveUtils.verticalSpace(context,
                      mobile: 8, tablet: 12, desktop: 16),
                  Text(
                    isMobile
                        ? 'Manage restaurant items'
                        : 'View and manage restaurant inventory items',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.mediumGrey,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 14,
                            tablet: 15,
                            desktop: 16,
                          ),
                        ),
                  ),
                  ResponsiveUtils.verticalSpace(context,
                      mobile: 16, tablet: 20, desktop: 24),

                  // Search and Filter Section
                  Container(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search & Filter',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppTheme.md),
                        TextField(
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                          decoration: InputDecoration(
                            hintText: isMobile ? 'Search items...' : 'Search by item name...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppTheme.primaryRed,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: AppTheme.lightGrey.withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.all(AppTheme.md),
                          ),
                        ),
                        const SizedBox(height: AppTheme.md),
                        Text(
                          'Categories',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppTheme.sm),
                        SizedBox(
                          height: isMobile ? 50 : 60,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: categories.map((category) {
                              final isSelected = _selectedCategory == category;
                              return Padding(
                                padding: const EdgeInsets.only(right: AppTheme.sm),
                                child: FilterChip(
                                  label: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                                        context,
                                        mobile: 12,
                                        tablet: 13,
                                        desktop: 14,
                                      ),
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedCategory = category;
                                    });
                                  },
                                  backgroundColor: AppTheme.lightGrey.withValues(alpha: 0.3),
                                  selectedColor: AppTheme.primaryRed,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppTheme.white : AppTheme.darkGrey,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ResponsiveUtils.verticalSpace(context,
                      mobile: 16, tablet: 20, desktop: 24),

                  // Inventory List
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client
                        .from('inventory')
                        .stream(primaryKey: ['id']),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: AppTheme.lg),
                              Text('Loading items...',
                                  style: Theme.of(context).textTheme.bodyLarge),
                            ],
                          ),
                        );
                      }

                      var items = snapshot.data!;

                      if (_selectedCategory != 'All') {
                        items = items.where((doc) {
                          final category =
                              (doc['category'] ?? '').toString();
                          return category == _selectedCategory;
                        }).toList();
                      }

                      if (_searchQuery.isNotEmpty) {
                        items = items.where((doc) {
                          final name =
                              (doc['name'] ?? '').toString().toLowerCase();
                          return name
                              .contains(_searchQuery.toLowerCase());
                        }).toList();
                      }

                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox,
                                  size: 64, color: AppTheme.lightGrey),
                              const SizedBox(height: AppTheme.lg),
                              Text(
                                'No inventory items found',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: AppTheme.md),
                              if (_isAdmin)
                                Text(
                                  'Tap the + button to add items',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: AppTheme.mediumGrey),
                                ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final data = items[index];
                          final quantity = data['quantity'] ?? 0;
                          final stockColor = _getStockColor(quantity);
                          final stockLabel = _getStockLabel(quantity);

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd)),
                            margin:
                                const EdgeInsets.only(bottom: AppTheme.lg),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(
                                ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: 12,
                                  tablet: 16,
                                  desktop: 20,
                                ),
                              ),
                              leading: Container(
                                padding: EdgeInsets.all(
                                  ResponsiveUtils.getResponsiveFontSize(
                                    context,
                                    mobile: 8,
                                    tablet: 12,
                                    desktop: 16,
                                  ),
                                ),
                                decoration: BoxDecoration(
                                  color: stockColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMd),
                                ),
                                child: Icon(
                                  Icons.inventory_2,
                                  color: stockColor,
                                  size: ResponsiveUtils.getResponsiveIconSize(
                                      context),
                                ),
                              ),
                              title: Text(
                                data['name'] ?? 'Unknown',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontSize:
                                          ResponsiveUtils.getResponsiveFontSize(
                                        context,
                                        mobile: 14,
                                        tablet: 15,
                                        desktop: 16,
                                      ),
                                    ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppTheme.md),
                                  Row(
                                    children: [
                                      Icon(Icons.category,
                                          size: 14,
                                          color: AppTheme.mediumGrey),
                                      const SizedBox(width: AppTheme.md),
                                      Text(
                                        data['category'] ?? 'N/A',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.sm),
                                  Chip(
                                    label: Text(
                                        '$quantity ${data['unit'] ?? ''} • $stockLabel'),
                                    backgroundColor:
                                        stockColor.withValues(alpha: 0.15),
                                    labelStyle: TextStyle(
                                        color: stockColor,
                                        fontWeight: FontWeight.bold),
                                    avatar: Icon(
                                        Icons.production_quantity_limits,
                                        size: 14,
                                        color: stockColor),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                ),
                                child: PopupMenuButton(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: AppTheme.primaryRed,
                                  ),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, color: AppTheme.primaryRed, size: 16),
                                          const SizedBox(width: 8),
                                          const Text('Edit'),
                                        ],
                                      ),
                                      onTap: () => _addOrEditItem(
                                          item: data),
                                    ),
                                    PopupMenuItem(
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: AppTheme.errorRed, size: 16),
                                          const SizedBox(width: 8),
                                          const Text('Delete'),
                                        ],
                                      ),
                                      onTap: () => _deleteItem(
                                          data['id'],
                                          data['name'] ?? 'Item'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.all(
        isMobile ? AppTheme.md : AppTheme.lg,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              icon,
              color: color,
              size: isMobile ? 16 : 20,
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.mediumGrey,
                    fontSize: isMobile ? 10 : 12,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 16 : 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}