import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class InventoryRoomPage extends StatefulWidget {
  const InventoryRoomPage({super.key});

  @override
  State<InventoryRoomPage> createState() => _InventoryRoomPageState();
}

class _InventoryRoomPageState extends State<InventoryRoomPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedStorageRoom = 'All';
  String _incomingSearchQuery = '';
  int _incomingCurrentPage = 1;
  int _incomingItemsPerPage = 10;
  
  static const List<String> storageRooms = [
    'All',
    'Freezer',
    'Chiller',
    'Dry Storage',
    'Cleaning Storage',
  ];

  static const List<String> categories = [
    'All',
    'Fresh',
    'Roasting',
    'Davids',
    'Groceries',
    'Sauces',
    'Vegetables',
    'Pre-mix',
    'Drinks',
    'Packaging',
    'Janitorial',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showBulkReplenishDialog() {
    final receiverCtrl = TextEditingController();
    List<Map<String, dynamic>> bulkItems = [];
    List<Map<String, dynamic>> allItems = [];
    List<String> pastReceivers = [];
    bool fetchedReceivers = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!fetchedReceivers) {
            fetchedReceivers = true;
            Supabase.instance.client
                .from('stock_transactions')
                .select('processed_by')
                .then((response) {
              if (response.isNotEmpty) {
                final receivers = response
                    .map((e) => e['processed_by']?.toString() ?? '')
                    .where((e) => e.isNotEmpty)
                    .toSet()
                    .toList();
                if (context.mounted) {
                  setDialogState(() {
                    pastReceivers = receivers;
                  });
                }
              }
            });
            
            receiverCtrl.addListener(() {
              if (context.mounted) setDialogState(() {});
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.isMobile(context)
                    ? double.infinity
                    : 700,
                maxHeight: ResponsiveUtils.isMobile(context)
                    ? MediaQuery.of(context).size.height * 0.9
                    : 800,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.playlist_add,
                          color: AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Bulk Incoming Stock Delivery',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Receiver field (common for all items)
                  _CustomSearchDropdown(
                    controller: receiverCtrl,
                    items: pastReceivers,
                    label: 'Receiver (for all items)',
                    icon: Icons.person_outline,
                    onChanged: (value) {
                      if (context.mounted) setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 16),

                  // Add item button
                  ElevatedButton.icon(
                    onPressed: () {
                      _showAddBulkItemDialog(
                        allItems,
                        (item) {
                          setDialogState(() {
                            bulkItems.add(item);
                          });
                        },
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: AppTheme.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bulk items list
                  Expanded(
                    child: bulkItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: AppTheme.mediumGrey,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No items added yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.mediumGrey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Click "Add Item" to start',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.mediumGrey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: bulkItems.length,
                            itemBuilder: (context, index) {
                              final item = bulkItems[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.lightGrey,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'] ?? 'Unknown',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.darkGrey,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item['category']} • ${item['quantity']} ${item['unit']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.mediumGrey,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Supplier: ${item['supplier']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.mediumGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setDialogState(() {
                                          bulkItems.removeAt(index);
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppTheme.errorRed,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: bulkItems.isEmpty ||
                                receiverCtrl.text.trim().isEmpty
                            ? null
                            : () async {
                                await _processBulkIncomingStock(
                                  bulkItems,
                                  receiverCtrl.text.trim(),
                                );
                                if (context.mounted) Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: AppTheme.white,
                        ),
                        child: Text('Process ${bulkItems.length} Items'),
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
  }

  void _showAddBulkItemDialog(
    List<Map<String, dynamic>> allItems,
    Function(Map<String, dynamic>) onItemAdded,
  ) {
    String selectedCategory = categories[1];
    final itemNameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    List<String> filteredItemNames = [];
    bool initialized = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!initialized) {
            initialized = true;
            itemNameCtrl.addListener(() {
              final value = itemNameCtrl.text;
              try {
                final match = allItems.firstWhere(
                  (item) => item['name']?.toString() == value,
                );
                final dbUnit = match['unit']?.toString().trim();
                final dbSupplier = match['supplier']?.toString().trim();
                
                bool changed = false;
                if (dbUnit != null && dbUnit.isNotEmpty && unitCtrl.text.isEmpty) {
                  unitCtrl.text = dbUnit;
                  changed = true;
                }
                if (dbSupplier != null && dbSupplier.isNotEmpty && supplierCtrl.text.isEmpty) {
                  supplierCtrl.text = dbSupplier;
                  changed = true;
                }
                if (changed && context.mounted) setDialogState(() {});
              } catch (_) {}
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.isMobile(context)
                    ? double.infinity
                    : 500,
                maxHeight: ResponsiveUtils.isMobile(context)
                    ? MediaQuery.of(context).size.height * 0.85
                    : 600,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_circle_outline,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Add Item to Bulk Delivery',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: _buildDecoration(
                              'Category',
                              Icons.category_outlined,
                            ),
                            items: categories
                                .where((cat) => cat != 'All')
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedCategory = value;
                                  filteredItemNames = allItems
                                      .where(
                                        (item) =>
                                            item['category']?.toString() ==
                                            value,
                                      )
                                      .map(
                                        (item) =>
                                            item['name']?.toString() ?? '',
                                      )
                                      .where((name) => name.isNotEmpty)
                                      .toList();
                                  itemNameCtrl.clear();
                                  unitCtrl.clear();
                                  supplierCtrl.clear();
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Item Name Dropdown
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: Supabase.instance.client
                                .from('inventory')
                                .stream(primaryKey: ['id'])
                                .order('name'),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final fresh = snapshot.data!;
                                if (fresh.length != allItems.length) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    setDialogState(() {
                                      allItems = fresh;
                                      filteredItemNames = allItems
                                          .where(
                                            (item) =>
                                                item['category']?.toString() ==
                                                selectedCategory,
                                          )
                                          .map(
                                            (item) =>
                                                item['name']?.toString() ?? '',
                                          )
                                          .where((name) => name.isNotEmpty)
                                          .toList();
                                    });
                                  });
                                }
                              }

                              final items = filteredItemNames;

                              return _CustomSearchDropdown(
                                controller: itemNameCtrl,
                                items: items,
                                label: 'Item Name',
                                hintText: items.isEmpty ? 'No items in this category' : 'Search or enter new item',
                                icon: Icons.inventory_2_outlined,
                                onChanged: (value) {
                                  if (context.mounted) setDialogState(() {});
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Quantity
                          Row(
                            children: [
                              Expanded(
                                child: _buildInput(
                                  qtyCtrl,
                                  'Quantity',
                                  Icons.numbers,
                                  isNumber: true,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                    TextInputFormatter.withFunction((
                                      oldValue,
                                      newValue,
                                    ) {
                                      if (newValue.text.isEmpty) {
                                        return newValue;
                                      }
                                      if (newValue.text.startsWith('0')) {
                                        final stripped = newValue.text
                                            .replaceFirst(RegExp(r'^0+'), '');
                                        return TextEditingValue(
                                          text: stripped,
                                          selection: TextSelection.collapsed(
                                            offset: stripped.length,
                                          ),
                                        );
                                      }
                                      return newValue;
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInput(
                                  unitCtrl,
                                  'Unit',
                                  Icons.straighten,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Supplier
                          _buildInput(
                            supplierCtrl,
                            'Supplier',
                            Icons.business_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final qty = int.tryParse(qtyCtrl.text);
                          final name = itemNameCtrl.text.trim();
                          final unit = unitCtrl.text.trim();
                          final supplier = supplierCtrl.text.trim();

                          if (name.isEmpty ||
                              unit.isEmpty ||
                              supplier.isEmpty ||
                              qty == null ||
                              qty <= 0) {
                            _showErrorSnackBar(
                              'Please fill all fields with valid values',
                            );
                            return;
                          }

                          onItemAdded({
                            'name': name,
                            'category': selectedCategory,
                            'quantity': qty,
                            'unit': unit,
                            'supplier': supplier,
                          });

                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: AppTheme.white,
                        ),
                        child: const Text('Add to List'),
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
  }

  InputDecoration _buildDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.lightGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primaryColor),
      ),
      filled: true,
      fillColor: AppTheme.backgroundColor,
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNumber = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: inputFormatters,
      decoration: _buildDecoration(label, icon),
    );
  }

  Future<void> _processIncomingStock(
    String name,
    String category,
    int quantity,
    String unit,
    String supplier,
    String receiver,
    String? drNumber,
    String? deliveryTimestamp,
  ) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      final existingItems = await Supabase.instance.client
          .from('inventory')
          .select()
          .eq('name', name)
          .limit(1);

      if (existingItems.isNotEmpty) {
        final existingItem = existingItems.first;
        final currentQty = (existingItem['quantity'] as num?)?.toInt() ?? 0;
        await Supabase.instance.client
            .from('inventory')
            .update({'quantity': currentQty + quantity})
            .eq('id', existingItem['id']);
      } else {
        await Supabase.instance.client.from('inventory').insert({
          'name': name,
          'category': category,
          'quantity': quantity,
          'unit': unit,
          'supplier': supplier,
          'created_by': user?.email,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await Supabase.instance.client.from('stock_transactions').insert({
        'item_name': name,
        'transaction_type': 'incoming',
        'quantity': quantity,
        'unit': unit,
        'supplier': supplier,
        'processed_by': receiver,
        'created_at': deliveryTimestamp ?? DateTime.now().toIso8601String(),
        if (drNumber != null) 'purpose': 'DR: $drNumber',
      });

      _showSuccessSnackBar('Stock added successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to add stock: $e');
    }
  }

  Future<void> _processBulkIncomingStock(
    List<Map<String, dynamic>> bulkItems,
    String receiver,
  ) async {
    int successCount = 0;
    int failureCount = 0;
    List<String> failedItems = [];
    
    // Generate a single DR Number (5-digit random) for this bulk delivery
    final drNumber = (10000 + Random().nextInt(90000)).toString();
    final deliveryTimestamp = DateTime.now().toIso8601String();

    for (var item in bulkItems) {
      try {
        await _processIncomingStock(
          item['name'] as String,
          item['category'] as String,
          item['quantity'] as int,
          item['unit'] as String,
          item['supplier'] as String,
          receiver,
          drNumber, // Pass DR Number
          deliveryTimestamp, // Pass delivery timestamp
        );
        successCount++;
      } catch (e) {
        failureCount++;
        failedItems.add(item['name'] as String);
      }
    }

    if (failureCount > 0) {
      _showErrorSnackBar(
        'Processed $successCount items successfully. Failed to process $failureCount items: ${failedItems.join(", ")}',
      );
    } else {
      _showSuccessSnackBar(
        'Successfully processed all $successCount items! DR Number: $drNumber',
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.successGreen),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorRed),
    );
  }

  void _showDeliveryDetailsModal(String drNumber, List<Map<String, dynamic>> transactions) {
    final deliveryDateTime = _formatExactDate(transactions.first['created_at']);
    final receiver = transactions.first['processed_by']?.toString() ?? 'Unknown';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2, color: AppTheme.successGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  Text(
                    'DR Number: $drNumber',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                  Text(
                    'Receiver: $receiver',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                  Text(
                    deliveryDateTime,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.lightGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory, size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            transaction['item_name'] ?? 'Unknown Item',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.format_list_numbered, size: 14, color: AppTheme.successGreen),
                        const SizedBox(width: 8),
                        Text(
                          '${transaction['quantity']} ${transaction['unit']?.toString().trim() ?? 'units'}'.trim(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                    if (transaction['supplier'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.business, size: 14, color: AppTheme.mediumGrey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Supplier: ${transaction['supplier']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.mediumGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.white,
        automaticallyImplyLeading: false,
        title: const Text('Storage Room'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.white,
          labelColor: AppTheme.white,
          unselectedLabelColor: AppTheme.white.withOpacity(0.7),
          labelStyle: ResponsiveUtils.isMobile(context)
              ? const TextStyle(fontSize: 12)
              : const TextStyle(fontSize: 14),
          tabs: [
            Tab(
              icon: Icon(
                Icons.warehouse,
                size: ResponsiveUtils.isMobile(context) ? 20 : 24,
              ),
              text: ResponsiveUtils.isMobile(context)
                  ? 'Storage'
                  : 'Storage Room',
            ),
            Tab(
              icon: Icon(
                Icons.inventory,
                size: ResponsiveUtils.isMobile(context) ? 20 : 24,
              ),
              text: 'Incoming',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStorageRoomTab(),
          _buildIncomingTab(),
        ],
      ),
    );
  }

  Widget _buildStorageRoomTab() {
    return Column(
      children: [
        // Search and Filter
        Container(
          margin: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 8 : 16),
          padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 12 : 16),
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
                  hintText: 'Search items in storage...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.primaryColor,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppTheme.mediumGrey,
                          ),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.lightGrey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                  ),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: storageRooms.map((room) {
                    final isSelected = _selectedStorageRoom == room;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(room),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedStorageRoom = room);
                        },
                        backgroundColor: AppTheme.white,
                        selectedColor: AppTheme.primaryColor.withValues(
                          alpha: 0.2,
                        ),
                        checkmarkColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.darkGrey,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.lightGrey,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Storage Room Grid
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('inventory')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading storage: ${snapshot.error}',
                    style: const TextStyle(color: AppTheme.errorRed),
                  ),
                );
              }

              final items = snapshot.data ?? [];
              final filteredItems = items.where((item) {
                final name = (item['name'] ?? '').toString().toLowerCase();
                final storageRoom = (item['storage_room'] ?? '')
                    .toString()
                    .toLowerCase();
                final query = _searchQuery.toLowerCase();
                final matchesSearch =
                    name.contains(query) || storageRoom.contains(query);
                final matchesStorageRoom =
                    _selectedStorageRoom == 'All' ||
                    item['storage_room']?.toString() == _selectedStorageRoom;
                return matchesSearch && matchesStorageRoom;
              }).toList();

              // Sort filtered items alphabetically by name
              filteredItems.sort((a, b) {
                final nameA = (a['name'] ?? '').toString().toLowerCase();
                final nameB = (b['name'] ?? '').toString().toLowerCase();
                return nameA.compareTo(nameB);
              });

              if (filteredItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warehouse_outlined,
                        size: 64,
                        color: AppTheme.mediumGrey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No items found in storage',
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
                    crossAxisCount: ResponsiveUtils.isMobile(context)
                        ? 2
                        : ResponsiveUtils.isTablet(context)
                        ? 5
                        : 6,
                    crossAxisSpacing: ResponsiveUtils.isMobile(context)
                        ? 10
                        : 8,
                    mainAxisSpacing: ResponsiveUtils.isMobile(context) ? 10 : 8,
                    childAspectRatio: ResponsiveUtils.isMobile(context)
                        ? 1.4
                        : ResponsiveUtils.isTablet(context)
                        ? 1.4
                        : 1.4,
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
                        color: AppTheme.white,
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
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
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
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: stockColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    stockIcon,
                                    color: stockColor,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['storage_room'] ?? 'Unassigned Room',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.mediumGrey,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: stockColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: stockColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    stockStatus,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: stockColor,
                                    ),
                                  ),
                                  Text(
                                    '$quantity ${item['unit']?.toString().trim() ?? 'pcs'}'
                                        .trim(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
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
    );
  }

  Widget _buildIncomingTab() {
    return Column(
      children: [
        // Header with actions
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.successGreen,
                AppTheme.successGreen.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.successGreen.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory, color: AppTheme.white, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incoming Stock',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage incoming stock deliveries',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showBulkReplenishDialog,
                icon: const Icon(Icons.playlist_add),
                label: const Text('New Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.white,
                  foregroundColor: AppTheme.successGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
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
          child: TextField(
            onChanged: (value) {
              setState(() {
                _incomingSearchQuery = value;
                _incomingCurrentPage = 1;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by DR Number or Date...',
              prefixIcon: const Icon(
                Icons.search,
                color: AppTheme.successGreen,
              ),
              suffixIcon: _incomingSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: AppTheme.mediumGrey,
                      ),
                      onPressed: () {
                        setState(() {
                          _incomingSearchQuery = '';
                          _incomingCurrentPage = 1;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.lightGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.successGreen),
              ),
              filled: true,
              fillColor: AppTheme.backgroundColor,
            ),
          ),
        ),

        // Recent Incoming Transactions
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('stock_transactions')
                .stream(primaryKey: ['id'])
                .eq('transaction_type', 'incoming')
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.successGreen,
                  ),
                );
              }

              final transactions = snapshot.data ?? [];

              if (transactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: AppTheme.mediumGrey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No incoming deliveries yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.mediumGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Click "New Delivery" to add stock',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Group transactions by DR Number (stored in purpose column)
              Map<String, List<Map<String, dynamic>>> groupedTransactions = {};
              for (var transaction in transactions) {
                final purpose = transaction['purpose']?.toString() ?? '';
                final drNumber = purpose.startsWith('DR: ') 
                    ? purpose.substring(4) 
                    : transaction['id'].toString();
                if (!groupedTransactions.containsKey(drNumber)) {
                  groupedTransactions[drNumber] = [];
                }
                groupedTransactions[drNumber]!.add(transaction);
              }

              // Filter by search query (DR Number or Date)
              List<String> filteredDrNumbers = [];
              if (_incomingSearchQuery.isEmpty) {
                filteredDrNumbers = groupedTransactions.keys.toList();
              } else {
                final searchLower = _incomingSearchQuery.toLowerCase();
                for (var drNumber in groupedTransactions.keys) {
                  final drTransactions = groupedTransactions[drNumber]!;
                  final firstTransaction = drTransactions.first;
                  final formattedDate = _formatExactDate(firstTransaction['created_at']).toLowerCase();
                  
                  if (drNumber.toLowerCase().contains(searchLower) || 
                      formattedDate.contains(searchLower)) {
                    filteredDrNumbers.add(drNumber);
                  }
                }
              }

              final drNumbers = filteredDrNumbers;

              // Pagination logic
              final totalPages = (drNumbers.length / _incomingItemsPerPage).ceil();
              final startIndex = (_incomingCurrentPage - 1) * _incomingItemsPerPage;
              final endIndex = startIndex + _incomingItemsPerPage;
              final paginatedDrNumbers = drNumbers.sublist(
                startIndex,
                endIndex > drNumbers.length ? drNumbers.length : endIndex,
              );

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(
                        ResponsiveUtils.isMobile(context) ? 8 : 16,
                      ),
                      itemCount: paginatedDrNumbers.length,
                      itemBuilder: (context, index) {
                        final drNumber = paginatedDrNumbers[index];
                        final drTransactions = groupedTransactions[drNumber]!;
                        final firstTransaction = drTransactions.first;
                        final itemCount = drTransactions.length;

                        return _IncomingDeliveryItem(
                          drNumber: drNumber,
                          drTransactions: drTransactions,
                          itemCount: itemCount,
                          firstTransaction: firstTransaction,
                          onTap: () => _showDeliveryDetailsModal(drNumber, drTransactions),
                          formatDate: _formatExactDate,
                        );
                      },
                    ),
                  ),
                  if (totalPages > 1) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.darkGrey.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _incomingCurrentPage > 1
                                ? () {
                                    setState(() {
                                      _incomingCurrentPage--;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            color: AppTheme.successGreen,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Page $_incomingCurrentPage of $totalPages',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: _incomingCurrentPage < totalPages
                                ? () {
                                    setState(() {
                                      _incomingCurrentPage++;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            color: AppTheme.successGreen,
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
    );
  }

  String _getStockStatus(int quantity) {
    if (quantity == 0) return 'OUT OF STOCK';
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

  String _formatExactDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString).toLocal();
      final hour = date.hour == 0
          ? 12
          : (date.hour > 12 ? date.hour - 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      return '${date.month}/${date.day}/${date.year} $hour:$minute $amPm';
    } catch (e) {
      return 'Unknown';
    }
  }
}

class _IncomingDeliveryItem extends StatefulWidget {
  final String drNumber;
  final List<Map<String, dynamic>> drTransactions;
  final int itemCount;
  final Map<String, dynamic> firstTransaction;
  final VoidCallback onTap;
  final String Function(String?) formatDate;

  const _IncomingDeliveryItem({
    required this.drNumber,
    required this.drTransactions,
    required this.itemCount,
    required this.firstTransaction,
    required this.onTap,
    required this.formatDate,
  });

  @override
  State<_IncomingDeliveryItem> createState() => _IncomingDeliveryItemState();
}

class _IncomingDeliveryItemState extends State<_IncomingDeliveryItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered 
                ? AppTheme.successGreen.withOpacity(0.05)
                : AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? AppTheme.successGreen.withOpacity(0.2)
                    : AppTheme.darkGrey.withOpacity(0.1),
                blurRadius: _isHovered ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: _isHovered
                  ? AppTheme.successGreen
                  : AppTheme.successGreen.withOpacity(0.3),
              width: _isHovered ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: AppTheme.successGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DR Number: ${widget.drNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        Text(
                          '${widget.itemCount} item${widget.itemCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    widget.formatDate(widget.firstTransaction['created_at']),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
              if (widget.firstTransaction['processed_by'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: AppTheme.mediumGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Receiver: ${widget.firstTransaction['processed_by']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomSearchDropdown extends StatefulWidget {
  final String label;
  final IconData icon;
  final String? hintText;
  final TextEditingController controller;
  final List<String> items;
  final void Function(String)? onChanged;

  const _CustomSearchDropdown({
    required this.label,
    required this.icon,
    this.hintText,
    required this.controller,
    required this.items,
    this.onChanged,
  });

  @override
  State<_CustomSearchDropdown> createState() => _CustomSearchDropdownState();
}

class _CustomSearchDropdownState extends State<_CustomSearchDropdown> {
  final MenuController _menuController = MenuController();
  final FocusNode _focusNode = FocusNode();
  List<String> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }
  
  @override
  void didUpdateWidget(_CustomSearchDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _filter(widget.controller.text, autoOpen: false);
    }
  }

  void _filter(String query, {bool autoOpen = true}) {
    if (query.isEmpty) {
      _filteredItems = widget.items;
    } else {
      _filteredItems = widget.items
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    setState(() {});
    
    if (autoOpen) {
      if (query.isNotEmpty && _filteredItems.isNotEmpty && !_menuController.isOpen) {
        _menuController.open();
      } else if (_filteredItems.isEmpty && _menuController.isOpen) {
        _menuController.close();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return MenuAnchor(
          controller: _menuController,
          style: MenuStyle(
            maximumSize: WidgetStateProperty.all(const Size(double.infinity, 250)),
            minimumSize: WidgetStateProperty.all(Size(constraints.maxWidth, 50)),
          ),
          builder: (context, controller, child) {
            return TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: (val) {
                _filter(val, autoOpen: true);
                widget.onChanged?.call(val);
              },
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hintText,
                prefixIcon: Icon(widget.icon, color: AppTheme.primaryColor),
                suffixIcon: IconButton(
                  icon: Icon(controller.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      _filter(widget.controller.text, autoOpen: false);
                      controller.open();
                      _focusNode.requestFocus();
                    }
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.lightGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
              ),
            );
          },
          menuChildren: _filteredItems.isEmpty 
              ? [const Padding(padding: EdgeInsets.all(16.0), child: Text('No matches found'))]
              : _filteredItems.map((item) {
            return MenuItemButton(
              onPressed: () {
                widget.controller.text = item;
                widget.onChanged?.call(item);
                _menuController.close();
              },
              child: ConstrainedBox(
                 constraints: BoxConstraints(minWidth: constraints.maxWidth - 32),
                 child: Text(item),
              ),
            );
          }).toList(),
        );
      }
    );
  }
}

