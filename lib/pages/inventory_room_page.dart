import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  String _selectedCategory = 'All';

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
    'Miscellaneous',
  ];

  static const List<String> unitOptions = [
    'kilo',
    'gram',
    'pcs',
    'pack',
    'order',
    'bot',
    'can',
    'box',
  ];

  static const List<String> supplierOptions = [
    'FreshMart',
    'Roasting Mart',
    'Davids Company',
    'Grocery Mart',
    'Packaging Mart',
    'Janitorial Mart',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showReplenishDialog() {
    String selectedCategory = categories[1];
    String? selectedItemName;
    String? selectedUnit;
    String? selectedSupplier;
    final qtyCtrl = TextEditingController();

    // Will hold items filtered by category from the DB
    List<Map<String, dynamic>> allItems = [];
    List<String> filteredItemNames = [];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                    : 700,
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
                          Icons.inventory_2,
                          color: AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Incoming Stock Delivery',
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

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── 1. Category Dropdown (unchanged behaviour) ──
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
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
                                  // Filter items to match the new category
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
                                  // Reset item selection when category changes
                                  selectedItemName = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── 2. Item Name Dropdown (filtered by category) ──
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: Supabase.instance.client
                                .from('inventory')
                                .stream(primaryKey: ['id'])
                                .order('name'),
                            builder: (context, snapshot) {
                              // Keep allItems in sync whenever stream updates
                              if (snapshot.hasData) {
                                final fresh = snapshot.data!;
                                if (fresh.length != allItems.length) {
                                  // Update list and re-filter without calling setState
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

                              return DropdownButtonFormField<String>(
                                value: selectedItemName,
                                decoration: _buildDecoration(
                                  'Item Name',
                                  Icons.inventory_2_outlined,
                                ),
                                hint: Text(
                                  items.isEmpty
                                      ? 'No items in this category'
                                      : 'Select item',
                                  style: const TextStyle(
                                    color: AppTheme.mediumGrey,
                                  ),
                                ),
                                items: items
                                    .map(
                                      (name) => DropdownMenuItem(
                                        value: name,
                                        child: Text(name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: items.isEmpty
                                    ? null
                                    : (value) {
                                        setDialogState(() {
                                          selectedItemName = value;
                                          // Auto-fill unit from the selected item's DB record
                                          final match = allItems.firstWhere(
                                            (item) =>
                                                item['name']?.toString() ==
                                                value,
                                            orElse: () => {},
                                          );
                                          final dbUnit = match['unit']
                                              ?.toString()
                                              .trim();
                                          if (dbUnit != null &&
                                              dbUnit.isNotEmpty) {
                                            // Use the DB unit directly (may not be in unitOptions list)
                                            selectedUnit = dbUnit;
                                          } else {
                                            selectedUnit = null;
                                          }
                                        });
                                      },
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── 3. Quantity ──
                          Row(
                            children: [
                              Expanded(
                                child: _buildInput(
                                  qtyCtrl,
                                  'Quantity',
                                  Icons.numbers,
                                  isNumber: true,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // ── 4. Unit — auto-filled from DB, read-only ──
                              Expanded(
                                child: InputDecorator(
                                  decoration: _buildDecoration(
                                    'Unit',
                                    Icons.straighten,
                                  ),
                                  child: Text(
                                    selectedUnit ?? '—',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: selectedUnit != null
                                          ? AppTheme.darkGrey
                                          : AppTheme.mediumGrey,
                                      fontWeight: selectedUnit != null
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── 5. Supplier Dropdown ──
                          DropdownButtonFormField<String>(
                            value: selectedSupplier,
                            decoration: _buildDecoration(
                              'Supplier',
                              Icons.business_outlined,
                            ),
                            hint: const Text(
                              'Select supplier',
                              style: TextStyle(color: AppTheme.mediumGrey),
                            ),
                            items: supplierOptions
                                .map(
                                  (supplier) => DropdownMenuItem(
                                    value: supplier,
                                    child: Text(supplier),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedSupplier = value;
                              });
                            },
                          ),
                          const SizedBox(height: 20),

                          // Info banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.infoBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.infoBlue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: AppTheme.infoBlue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Stock will be added to existing inventory or create new item if not exists',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.infoBlue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                        onPressed: () async {
                          final qty = int.tryParse(qtyCtrl.text);
                          if (selectedItemName == null ||
                              selectedItemName!.isEmpty ||
                              selectedUnit == null ||
                              selectedSupplier == null ||
                              qty == null ||
                              qty <= 0) {
                            _showErrorSnackBar(
                              'Please fill all fields with valid values',
                            );
                            return;
                          }

                          await _processIncomingStock(
                            selectedItemName!,
                            selectedCategory,
                            qty,
                            selectedUnit!,
                            selectedSupplier!,
                          );

                          if (mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: AppTheme.white,
                        ),
                        child: const Text('Add Stock'),
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

  void _showOutgoingDialog() {
    String selectedCategory = categories[1];
    String? selectedItemName;
    String? selectedUnit;
    final qtyCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    final requestedByCtrl = TextEditingController();

    List<Map<String, dynamic>> allItems = [];
    List<String> filteredItemNames = [];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                    : 680,
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
                          color: AppTheme.warningOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.outbox,
                          color: AppTheme.warningOrange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Outgoing Stock',
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

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── 1. Category Dropdown ──
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
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
                                  selectedItemName = null;
                                  selectedUnit = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── 2. Item Name Dropdown (filtered by category) ──
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

                              return DropdownButtonFormField<String>(
                                value: selectedItemName,
                                decoration: _buildDecoration(
                                  'Item Name',
                                  Icons.inventory_2_outlined,
                                ),
                                hint: Text(
                                  items.isEmpty
                                      ? 'No items in this category'
                                      : 'Select item',
                                  style: const TextStyle(
                                    color: AppTheme.mediumGrey,
                                  ),
                                ),
                                items: items
                                    .map(
                                      (name) => DropdownMenuItem(
                                        value: name,
                                        child: Text(name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: items.isEmpty
                                    ? null
                                    : (value) {
                                        setDialogState(() {
                                          selectedItemName = value;
                                          // Auto-fill unit from the selected item's DB record
                                          final match = allItems.firstWhere(
                                            (item) =>
                                                item['name']?.toString() ==
                                                value,
                                            orElse: () => {},
                                          );
                                          final dbUnit = match['unit']
                                              ?.toString()
                                              .trim();
                                          selectedUnit =
                                              (dbUnit != null &&
                                                  dbUnit.isNotEmpty)
                                              ? dbUnit
                                              : null;
                                        });
                                      },
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── Unit — auto-filled read-only, shown in same row as Quantity ──
                          Row(
                            children: [
                              Expanded(
                                child: _buildInput(
                                  qtyCtrl,
                                  'Quantity',
                                  Icons.numbers,
                                  isNumber: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InputDecorator(
                                  decoration: _buildDecoration(
                                    'Unit',
                                    Icons.straighten,
                                  ),
                                  child: Text(
                                    selectedUnit ?? '—',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: selectedUnit != null
                                          ? AppTheme.darkGrey
                                          : AppTheme.mediumGrey,
                                      fontWeight: selectedUnit != null
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── 3. Purpose ──
                          _buildInput(
                            purposeCtrl,
                            'Purpose (e.g., Cooking, Prep)',
                            Icons.restaurant_outlined,
                          ),
                          const SizedBox(height: 16),

                          // ── 5. Requested By ──
                          _buildInput(
                            requestedByCtrl,
                            'Requested By (e.g., Cook Name)',
                            Icons.person_outline,
                          ),
                          const SizedBox(height: 20),

                          // Warning banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.warningOrange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber,
                                  color: AppTheme.warningOrange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Stock will be deducted from inventory. Ensure sufficient stock is available.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.warningOrange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                        onPressed: () async {
                          final qty = int.tryParse(qtyCtrl.text);
                          if (selectedItemName == null ||
                              selectedItemName!.isEmpty ||
                              purposeCtrl.text.isEmpty ||
                              requestedByCtrl.text.isEmpty ||
                              qty == null ||
                              qty <= 0) {
                            _showErrorSnackBar(
                              'Please fill all fields with valid values',
                            );
                            return;
                          }

                          await _processOutgoingStock(
                            selectedItemName!,
                            qty,
                            purposeCtrl.text.trim(),
                            requestedByCtrl.text.trim(),
                          );

                          if (mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.warningOrange,
                          foregroundColor: AppTheme.white,
                        ),
                        child: const Text('Release Stock'),
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

  Widget _buildInput(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: _buildDecoration(label, icon),
    );
  }

  Future<void> _processIncomingStock(
    String name,
    String category,
    int quantity,
    String unit,
    String supplier,
  ) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      // Check if item exists
      final existingItems = await Supabase.instance.client
          .from('inventory')
          .select()
          .eq('name', name)
          .limit(1);

      if (existingItems.isNotEmpty) {
        // Update existing item quantity
        final existingItem = existingItems.first;
        final currentQty = (existingItem['quantity'] as num?)?.toInt() ?? 0;
        await Supabase.instance.client
            .from('inventory')
            .update({'quantity': currentQty + quantity})
            .eq('id', existingItem['id']);
      } else {
        // Create new item
        await Supabase.instance.client.from('inventory').insert({
          'name': name,
          'category': category,
          'quantity': quantity,
          'unit': unit,
          'created_by': user?.email,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Log the transaction
      await Supabase.instance.client.from('stock_transactions').insert({
        'item_name': name,
        'transaction_type': 'incoming',
        'quantity': quantity,
        'unit': unit,
        'supplier': supplier,
        'processed_by': user?.email,
        'created_at': DateTime.now().toIso8601String(),
      });

      _showSuccessSnackBar('Stock added successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to add stock: $e');
    }
  }

  Future<void> _processOutgoingStock(
    String itemName,
    int quantity,
    String purpose,
    String requestedBy,
  ) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      // Check if item exists and get current quantity
      final existingItems = await Supabase.instance.client
          .from('inventory')
          .select()
          .eq('name', itemName)
          .limit(1);

      if (existingItems.isEmpty) {
        _showErrorSnackBar('Item not found in inventory');
        return;
      }

      final existingItem = existingItems.first;

      final currentQty = (existingItem['quantity'] as num?)?.toInt() ?? 0;
      if (currentQty < quantity) {
        _showErrorSnackBar(
          'Insufficient stock. Available: $currentQty, Requested: $quantity',
        );
        return;
      }

      // Update inventory quantity
      await Supabase.instance.client
          .from('inventory')
          .update({'quantity': currentQty - quantity})
          .eq('id', existingItem['id']);

      // Log the transaction
      await Supabase.instance.client.from('stock_transactions').insert({
        'item_name': itemName,
        'transaction_type': 'outgoing',
        'quantity': quantity,
        'unit': existingItem['unit'],
        'purpose': purpose,
        'requested_by': requestedBy,
        'processed_by': user?.email,
        'created_at': DateTime.now().toIso8601String(),
      });

      _showSuccessSnackBar('Stock released successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to release stock: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: AppTheme.white,
        title: ResponsiveUtils.isMobile(context)
            ? const Text('Inventory Room')
            : const Text('Inventory Room Management'),
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
            Tab(
              icon: Icon(
                Icons.outbox,
                size: ResponsiveUtils.isMobile(context) ? 20 : 24,
              ),
              text: 'Outgoing',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStorageRoomTab(),
          _buildIncomingTab(),
          _buildOutgoingTab(),
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
            children: [
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search items in storage...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.primaryRed,
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
                          color: isSelected
                              ? AppTheme.primaryRed
                              : AppTheme.darkGrey,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.primaryRed
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
                  child: CircularProgressIndicator(color: AppTheme.primaryRed),
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
                final category = (item['category'] ?? '')
                    .toString()
                    .toLowerCase();
                final query = _searchQuery.toLowerCase();
                final matchesSearch =
                    name.contains(query) || category.contains(query);
                final matchesCategory =
                    _selectedCategory == 'All' ||
                    item['category']?.toString() == _selectedCategory;
                return matchesSearch && matchesCategory;
              }).toList();

              if (filteredItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warehouse_outlined,
                        size: 64,
                        color: AppTheme.mediumGrey,
                      ),
                      const SizedBox(height: 16),
                      Text(
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
                        ? 3
                        : 4,
                    crossAxisSpacing: ResponsiveUtils.isMobile(context)
                        ? 8
                        : 12,
                    mainAxisSpacing: ResponsiveUtils.isMobile(context) ? 8 : 12,
                    childAspectRatio: ResponsiveUtils.isMobile(context)
                        ? 1.0
                        : 1.2,
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
                        padding: const EdgeInsets.all(12),
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
                                      fontSize: 14,
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
                              item['category'] ?? 'Uncategorized',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.mediumGrey,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(8),
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
                                      color: AppTheme.primaryRed,
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
                onPressed: _showReplenishDialog,
                icon: const Icon(Icons.add),
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
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: AppTheme.mediumGrey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No incoming deliveries yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.mediumGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
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

              return ListView.builder(
                padding: EdgeInsets.all(
                  ResponsiveUtils.isMobile(context) ? 8 : 16,
                ),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                      border: Border.all(
                        color: AppTheme.successGreen.withOpacity(0.3),
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
                                Icons.add_shopping_cart,
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
                                    transaction['item_name'] ?? 'Unknown Item',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkGrey,
                                    ),
                                  ),
                                  Text(
                                    '${transaction['quantity']} ${transaction['unit']?.toString().trim() ?? 'units'}'
                                        .trim(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.successGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatDate(transaction['created_at']),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.mediumGrey,
                              ),
                            ),
                          ],
                        ),
                        if (transaction['supplier'] != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.business,
                                size: 16,
                                color: AppTheme.mediumGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Supplier: ${transaction['supplier']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (transaction['processed_by'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: 16,
                                color: AppTheme.mediumGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Processed by: ${transaction['processed_by']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOutgoingTab() {
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
                AppTheme.warningOrange,
                AppTheme.warningOrange.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.warningOrange.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.outbox, color: AppTheme.white, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outgoing Stock',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage stock distribution for cooking and operations',
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
                onPressed: _showOutgoingDialog,
                icon: const Icon(Icons.remove),
                label: const Text('Release Stock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.white,
                  foregroundColor: AppTheme.warningOrange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Recent Outgoing Transactions
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('stock_transactions')
                .stream(primaryKey: ['id'])
                .eq('transaction_type', 'outgoing')
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.warningOrange,
                  ),
                );
              }

              final transactions = snapshot.data ?? [];

              if (transactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.outbox_outlined,
                        size: 64,
                        color: AppTheme.mediumGrey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No outgoing stock yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.mediumGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click "Release Stock" to distribute items',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(
                  ResponsiveUtils.isMobile(context) ? 8 : 16,
                ),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                      border: Border.all(
                        color: AppTheme.warningOrange.withOpacity(0.3),
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
                                color: AppTheme.warningOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.restaurant,
                                color: AppTheme.warningOrange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    transaction['item_name'] ?? 'Unknown Item',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkGrey,
                                    ),
                                  ),
                                  Text(
                                    '${transaction['quantity']} ${transaction['unit']?.toString().trim() ?? 'units'}'
                                        .trim(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.warningOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatDate(transaction['created_at']),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.mediumGrey,
                              ),
                            ),
                          ],
                        ),
                        if (transaction['purpose'] != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.info,
                                size: 16,
                                color: AppTheme.mediumGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Purpose: ${transaction['purpose']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (transaction['requested_by'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: 16,
                                color: AppTheme.mediumGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Requested by: ${transaction['requested_by']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (transaction['processed_by'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.admin_panel_settings,
                                size: 16,
                                color: AppTheme.mediumGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Processed by: ${transaction['processed_by']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
