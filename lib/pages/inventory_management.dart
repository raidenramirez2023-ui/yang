import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isAdmin = false;
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> categories = [
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
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await _firestore
            .collection('users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
        
        if (userDoc.docs.isNotEmpty) {
          final userRole = userDoc.docs.first.get('role');
          setState(() {
            _isAdmin = userRole == 'Admin';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _addOrEditItem({Map<String, dynamic>? item, String? docId}) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Admin users can add/edit inventory items'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final nameController = TextEditingController(text: item?['name']);
    final categoryController = TextEditingController(text: item?['category']);
    final quantityController = TextEditingController(text: item?['quantity']?.toString());
    final unitController = TextEditingController(text: item?['unit']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text(
          item == null ? 'Add Inventory Item' : 'Edit Inventory Item',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  color: AppTheme.primaryRed.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.primaryRed.withOpacity(0.2)),
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
                      children: categories.where((cat) => cat != 'All').map((category) {
                        return ActionChip(
                          label: Text(
                            category,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            categoryController.text = category;
                          },
                          backgroundColor: AppTheme.primaryRed.withOpacity(0.1),
                          side: BorderSide(color: AppTheme.primaryRed.withOpacity(0.3)),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item name is required')),
                );
                return;
              }

              final user = _auth.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please login to add items')),
                );
                return;
              }

              final newItem = {
                'name': nameController.text.trim(),
                'category': categoryController.text.trim(),
                'quantity': int.tryParse(quantityController.text) ?? 0,
                'unit': unitController.text.trim(),
                'createdBy': user.email,
                'createdAt': FieldValue.serverTimestamp(),
              };

              try {
                if (item == null) {
                  await _firestore.collection('inventory').add(newItem);
                } else {
                  await _firestore.collection('inventory').doc(docId).update(newItem);
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(item == null ? 'Item added successfully!' : 'Item updated successfully!'),
                      backgroundColor: AppTheme.successGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving item: $e'), backgroundColor: AppTheme.errorRed),
                  );
                }
              }
            },
            child: Text(item == null ? 'Add' : 'Update'),
          ),
        ],
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
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      ),
    );
  }

  void _deleteItem(String docId, String itemName) {
    if (!_isAdmin) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "$itemName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              try {
                await _firestore.collection('inventory').doc(docId).delete();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Item deleted successfully!'),
                      backgroundColor: AppTheme.successGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting item: $e'), backgroundColor: AppTheme.errorRed),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
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
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppTheme.lg),
              Text('Loading inventory...', style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              tooltip: 'Add Item',
              onPressed: () => _addOrEditItem(),
              backgroundColor: AppTheme.primaryRed,
              heroTag: "add",
              mini: isMobile,
              child: Icon(
                Icons.add,
                size: isMobile ? 20 : 24,
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                if (isMobile) 
                  Expanded(
                    child: Text(
                      'Inventory',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 20,
                          tablet: 24,
                          desktop: 28,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      'Inventory Management',
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
            ResponsiveUtils.verticalSpace(context, mobile: 8, tablet: 12, desktop: 16),
            Text(
              isMobile ? 'Manage restaurant items' : 'View and manage restaurant inventory items',
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
            ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),

            // Firestore Connection Status
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(
                ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 12,
                  tablet: 16,
                  desktop: 20,
                ),
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.primaryRed.withOpacity(0.3)),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('inventory').limit(1).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Row(
                      children: [
                        Icon(Icons.error, color: AppTheme.errorRed),
                        const SizedBox(width: AppTheme.md),
                        Expanded(
                          child: Text(
                            'Firestore Error: ${snapshot.error}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.errorRed,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Row(
                      children: [
                        const CircularProgressIndicator(strokeWidth: 2),
                        ResponsiveUtils.horizontalSpace(context, mobile: 8, tablet: 12, desktop: 16),
                        Text(
                          'Connecting to Firestore...',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primaryRed,
                          ),
                        ),
                      ],
                    );
                  }
                  
                  return Row(
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.successGreen, size: ResponsiveUtils.getResponsiveIconSize(context)),
                      ResponsiveUtils.horizontalSpace(context, mobile: 8, tablet: 12, desktop: 16),
                      Expanded(
                        child: Text(
                          '✅ Connected to Firestore Database',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),

            // Category Filter
            Container(
              height: isMobile ? 50 : 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 8),
                children: categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 6,
                        tablet: 8,
                        desktop: 8,
                      ),
                    ),
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
                      backgroundColor: AppTheme.lightGrey,
                      selectedColor: AppTheme.primaryRed,
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.white : AppTheme.darkGrey,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),

            // Search Field
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: isMobile ? 'Search...' : 'Search items...',
                prefixIcon: Icon(
                  Icons.search,
                  size: ResponsiveUtils.getResponsiveIconSize(context),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 12,
                    tablet: 16,
                    desktop: 20,
                  ),
                  vertical: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 12,
                    tablet: 14,
                    desktop: 16,
                  ),
                ),
              ),
            ),
            ResponsiveUtils.verticalSpace(context, mobile: 16, tablet: 20, desktop: 24),

            // Inventory List
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('inventory').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppTheme.lg),
                        Text('Loading items...', style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  );
                }

                var items = snapshot.data!.docs;

                // Filter items based on category
                if (_selectedCategory != 'All') {
                  items = items.where((doc) {
                    final category = (doc['category'] ?? '').toString();
                    return category == _selectedCategory;
                  }).toList();
                }

                // Filter items based on search query
                if (_searchQuery.isNotEmpty) {
                  items = items.where((doc) {
                    final name = (doc['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: AppTheme.lightGrey),
                        const SizedBox(height: AppTheme.lg),
                        Text(
                          'No inventory items found',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppTheme.md),
                        if (_isAdmin)
                          Text(
                            'Tap the + button to add items',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.mediumGrey,
                            ),
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
                    final doc = items[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final quantity = data['quantity'] ?? 0;
                    final stockColor = _getStockColor(quantity);
                    final stockLabel = _getStockLabel(quantity);

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      margin: const EdgeInsets.only(bottom: AppTheme.lg),
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
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            color: stockColor.withOpacity(0.1),
                          ),
                          child: Icon(
                            Icons.inventory_2, 
                            color: stockColor, 
                            size: ResponsiveUtils.getResponsiveIconSize(context),
                          ),
                        ),
                        title: Text(
                          data['name'] ?? 'Unknown',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
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
                                Icon(Icons.category, size: 14, color: AppTheme.mediumGrey),
                                const SizedBox(width: AppTheme.md),
                                Text(
                                  data['category'] ?? 'N/A',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.sm),
                            Chip(
                              label: Text('$quantity ${data['unit'] ?? ''} • $stockLabel'),
                              backgroundColor: stockColor.withOpacity(0.15),
                              labelStyle: TextStyle(color: stockColor, fontWeight: FontWeight.bold),
                              avatar: Icon(Icons.production_quantity_limits, size: 14, color: stockColor),
                            ),
                          ],
                        ),
                        trailing: _isAdmin
                            ? PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Text('Edit'),
                                    onTap: () => _addOrEditItem(item: data, docId: doc.id),
                                  ),
                                  PopupMenuItem(
                                    child: const Text('Delete'),
                                    onTap: () => _deleteItem(doc.id, data['name'] ?? 'Item'),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}