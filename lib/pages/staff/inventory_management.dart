import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class InventoryPage extends StatefulWidget {
  final bool isViewOnly;
  const InventoryPage({super.key, this.isViewOnly = false});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool _isAdmin = false;
  bool get _canEdit => _isAdmin && !widget.isViewOnly;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String? _selectedStockStatus;

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

  static const List<String> unitOptions = [
    'kilo',
    'gram',
    'pcs',
    'pack',
    'order',
    'bot',
    'can',
    'box',
    'roll',
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

    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('email', user.email!)
          .maybeSingle();

      if (!mounted) return;
      final role = (res?['role'] ?? '').toString().toLowerCase();
      final userEmail = user.email?.toLowerCase() ?? '';

      if (userEmail == 'pagsanjaninv@gmail.com' ||
          role == 'inventory staff' ||
          role == 'admin') {
        setState(() => _isAdmin = true);
      } else {
        setState(() => _isAdmin = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isAdmin = true);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase().trim()) {
      case 'all':
        return Icons.grid_view_rounded;
      case 'fresh':
        return Icons.set_meal_rounded;
      case 'roasting':
        return Icons.local_fire_department_rounded;
      case 'davids':
        return Icons.bakery_dining_rounded;
      case 'groceries':
        return Icons.shopping_basket_rounded;
      case 'sauces':
        return Icons.liquor_rounded;
      case 'vegetables':
        return Icons.eco_rounded;
      case 'pre-mix':
        return Icons.blender_rounded;
      case 'drinks':
        return Icons.local_cafe_rounded;
      case 'packaging':
        return Icons.inventory_2_rounded;
      case 'janitorial':
        return Icons.cleaning_services_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase().trim()) {
      case 'fresh':
        return const Color(0xFFE11D48); // Rose
      case 'roasting':
        return const Color(0xFFEA580C); // Warm Fire
      case 'davids':
        return const Color(0xFFD97706); // Golden Amber
      case 'groceries':
        return const Color(0xFF0D9488); // Teal Green
      case 'sauces':
        return const Color(0xFF9333EA); // Purple
      case 'vegetables':
        return const Color(0xFF16A34A); // Emerald Green
      case 'pre-mix':
        return const Color(0xFF4F46E5); // Indigo
      case 'drinks':
        return const Color(0xFF0284C7); // Sky Blue
      case 'packaging':
        return const Color(0xFF64748B); // Slate
      case 'janitorial':
        return const Color(0xFF0891B2); // Cyan
      default:
        return const Color(0xFF14332E);
    }
  }

  String _getStockStatus(int quantity) {
    if (quantity == 0) return 'OUT OF STOCK';
    if (quantity < 10) return 'LOW STOCK';
    if (quantity < 50) return 'NORMAL';
    return 'HIGH STOCK';
  }

  Color _getStockStatusColor(int quantity) {
    if (quantity == 0) return const Color(0xFFEF4444);
    if (quantity < 10) return const Color(0xFFF59E0B);
    if (quantity < 50) return const Color(0xFF3B82F6);
    return const Color(0xFF10B981);
  }

  IconData _getStockStatusIcon(int quantity) {
    if (quantity == 0) return Icons.cancel_rounded;
    if (quantity < 10) return Icons.warning_rounded;
    if (quantity < 50) return Icons.check_circle_rounded;
    return Icons.verified_rounded;
  }

  double _getStockProgress(int quantity) {
    if (quantity <= 0) return 0.0;
    if (quantity < 10) return (quantity / 10.0) * 0.3;
    if (quantity < 50) return 0.3 + ((quantity - 10) / 40.0) * 0.4;
    return (0.7 + ((quantity - 50) / 100.0) * 0.3).clamp(0.0, 1.0);
  }



  void _addOrEditItem({Map<String, dynamic>? item}) {
    final nameCtrl = TextEditingController(text: item?['name'] ?? '');
    final qtyCtrl = TextEditingController(
      text: item?['quantity']?.toString() ?? '',
    );
    final supplierCtrl = TextEditingController(text: item?['supplier'] ?? '');

    String? selectedCategory = (item?['category'] ?? '').toString().isEmpty
        ? null
        : item?['category']?.toString();
    String? selectedUnit = (item?['unit'] ?? '').toString().isEmpty
        ? null
        : item?['unit']?.toString();

    String? selectedStorageRoom =
        (item?['storage_room'] ?? '').toString().isEmpty
            ? null
            : item?['storage_room']?.toString();

    final filteredCategories = categories.where((cat) => cat != 'All').toList();

    final categoryList =
        selectedCategory != null &&
                !filteredCategories.contains(selectedCategory)
            ? [selectedCategory, ...filteredCategories]
            : filteredCategories;

    final unitList = selectedUnit != null && !unitOptions.contains(selectedUnit)
        ? [selectedUnit, ...unitOptions]
        : unitOptions;

    final storageRoomOptions = [
      'Freezer',
      'Chiller',
      'Dry Storage',
      'Cleaning Storage',
    ];

    final storageRoomList =
        selectedStorageRoom != null &&
                !storageRoomOptions.contains(selectedStorageRoom)
            ? [selectedStorageRoom, ...storageRoomOptions]
            : storageRoomOptions;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 16,
            backgroundColor: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.isMobile(context) ? double.infinity : 440,
                maxHeight: ResponsiveUtils.isMobile(context)
                    ? MediaQuery.of(context).size.height * 0.85
                    : 620,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14332E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item == null
                              ? Icons.add_box_rounded
                              : Icons.edit_note_rounded,
                          color: const Color(0xFF14332E),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item == null ? 'Add New Item' : 'Edit Inventory Item',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            item == null
                                ? 'Fill details to add to inventory'
                                : 'Update item quantity or specifications',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: _decoration('Category', Icons.category_rounded),
                            hint: const Text(
                              'Select category',
                              style: TextStyle(color: AppTheme.mediumGrey, fontSize: 13),
                            ),
                            items: categoryList
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getCategoryIcon(category),
                                          size: 16,
                                          color: _getCategoryColor(category),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(category, style: const TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedCategory = value);
                              }
                            },
                          ),
                          const SizedBox(height: 14),

                          // Item Name
                          _input(
                            nameCtrl,
                            'Item Name',
                            Icons.inventory_2_rounded,
                            inputFormatters: [LengthLimitingTextInputFormatter(50)],
                          ),
                          const SizedBox(height: 14),

                          if (item != null) ...[
                            // Quantity
                            _input(
                              qtyCtrl,
                              'Quantity',
                              Icons.pin_rounded,
                              isNumber: true,
                              readOnly: true,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Unit Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: selectedUnit,
                            decoration: _decoration('Measurement Unit', Icons.straighten_rounded),
                            hint: const Text(
                              'Select unit',
                              style: TextStyle(color: AppTheme.mediumGrey, fontSize: 13),
                            ),
                            items: unitList
                                .map(
                                  (unit) => DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit, style: const TextStyle(fontSize: 13)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedUnit = value);
                              }
                            },
                          ),
                          const SizedBox(height: 14),

                          // Storage Room Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: selectedStorageRoom,
                            decoration: _decoration('Storage Room', Icons.kitchen_rounded),
                            hint: const Text(
                              'Select storage room',
                              style: TextStyle(color: AppTheme.mediumGrey, fontSize: 13),
                            ),
                            items: storageRoomList
                                .map(
                                  (room) => DropdownMenuItem(
                                    value: room,
                                    child: Text(room, style: const TextStyle(fontSize: 13)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedStorageRoom = value);
                              }
                            },
                          ),
                          const SizedBox(height: 14),

                          // Supplier Input
                          _input(
                            supplierCtrl,
                            'Supplier Name',
                            Icons.business_rounded,
                            inputFormatters: [LengthLimitingTextInputFormatter(50)],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          foregroundColor: const Color(0xFF64748B),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14332E),
                          foregroundColor: const Color(0xFFE6C374),
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          final qty = item == null ? 0 : int.tryParse(qtyCtrl.text);
                          if (nameCtrl.text.trim().isEmpty ||
                              selectedCategory == null ||
                              selectedUnit == null ||
                              selectedStorageRoom == null ||
                              (item == null && supplierCtrl.text.trim().isEmpty) ||
                              qty == null ||
                              qty < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill all required fields correctly'),
                                backgroundColor: AppTheme.warningOrange,
                              ),
                            );
                            return;
                          }

                          final user = Supabase.instance.client.auth.currentUser;

                          final payload = {
                            'name': nameCtrl.text.trim(),
                            'category': selectedCategory,
                            'quantity': qty,
                            'unit': selectedUnit,
                            'storage_room': selectedStorageRoom,
                            if (supplierCtrl.text.trim().isNotEmpty)
                              'supplier': supplierCtrl.text.trim(),
                            'created_by': user?.email,
                            'created_at': DateTime.now().toUtc().toIso8601String(),
                          };

                          if (item == null) {
                            final itemExists = await _checkItemExists(nameCtrl.text.trim());
                            if (itemExists) {
                              final existingCategory =
                                  await _getItemExistingCategory(nameCtrl.text.trim());
                              _showDuplicateItemDialog(existingCategory ?? 'Inventory');
                              return;
                            }

                            await Supabase.instance.client.from('inventory').insert(payload);
                          } else {
                            final itemExists = await _checkItemExists(
                              nameCtrl.text.trim(),
                              excludeId: item['id'].toString(),
                            );
                            if (itemExists) {
                              final existingCategory =
                                  await _getItemExistingCategory(
                                    nameCtrl.text.trim(),
                                    excludeId: item['id'].toString(),
                                  );
                              _showDuplicateItemDialog(existingCategory ?? 'Inventory');
                              return;
                            }

                            await Supabase.instance.client
                                .from('inventory')
                                .update(payload)
                                .eq('id', item['id']);
                          }

                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        child: Text(
                          item == null ? 'Create Item' : 'Save Changes',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
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

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF14332E), size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNumber = false,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
      decoration: _decoration(label, icon),
    );
  }

  Future<void> _deleteItem(String id) async {
    try {
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
    }
  }

  Future<bool> _checkItemExists(String itemName, {String? excludeId}) async {
    try {
      final result = await Supabase.instance.client
          .from('inventory')
          .select('id, name, category');

      if (result.isEmpty) return false;

      final normalizedNewItem = _normalizeItemName(itemName.trim());

      for (var item in result) {
        if (excludeId != null && item['id'].toString() == excludeId) {
          continue;
        }

        final existingName = item['name']?.toString().trim() ?? '';
        final normalizedExistingName = _normalizeItemName(existingName);

        if (normalizedExistingName == normalizedNewItem) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _getItemExistingCategory(
    String itemName, {
    String? excludeId,
  }) async {
    try {
      final result = await Supabase.instance.client
          .from('inventory')
          .select('id, name, category');

      if (result.isEmpty) return null;

      final normalizedNewItem = _normalizeItemName(itemName.trim());

      for (var item in result) {
        if (excludeId != null && item['id'].toString() == excludeId) {
          continue;
        }

        final existingName = item['name']?.toString().trim() ?? '';
        final normalizedExistingName = _normalizeItemName(existingName);

        if (normalizedExistingName == normalizedNewItem) {
          return item['category']?.toString().trim() ?? '';
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  String _normalizeItemName(String itemName) {
    return itemName
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^\w]'), '');
  }

  void _showDuplicateItemDialog(String existingCategory) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange),
            SizedBox(width: 8),
            Text(
              'Duplicate Item',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'This item is already listed in $existingCategory.',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14332E),
              foregroundColor: const Color(0xFFE6C374),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  Widget _buildRealisticStatCard({
    required String label,
    required String count,
    required String statusKey,
    required Color accentColor,
    required IconData icon,
    required String subtitle,
  }) {
    final isSelected = _selectedStockStatus == statusKey;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedCategory = 'All';
              if (_selectedStockStatus == statusKey) {
                _selectedStockStatus = null;
              } else {
                _selectedStockStatus = statusKey;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSelected
                    ? [
                        accentColor.withValues(alpha: 0.28),
                        accentColor.withValues(alpha: 0.12),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.03),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? accentColor
                    : Colors.white.withValues(alpha: 0.12),
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isSelected ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            count,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFFC7D6D3),
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
    final stockStatus = _getStockStatus(quantity);
    final stockColor = _getStockStatusColor(quantity);
    final progress = _getStockProgress(quantity);
    final category = item['category']?.toString() ?? 'Uncategorized';
    final categoryColor = _getCategoryColor(category);
    final categoryIcon = _getCategoryIcon(category);
    final unit = (item['unit']?.toString() ?? 'pcs').trim();
    final storageRoom = item['storage_room']?.toString();
    final supplier = item['supplier']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stockColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: stockColor.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Category Pill + Status Pill + Menu
            Row(
              children: [
                // Category Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: categoryColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(categoryIcon, size: 11, color: categoryColor),
                      const SizedBox(width: 4),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: categoryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: stockColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStockStatusIcon(quantity),
                        size: 10,
                        color: stockColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stockStatus,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: stockColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_canEdit) ...[
                  const SizedBox(width: 2),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _addOrEditItem(item: item);
                      } else if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Colors.white,
                            title: const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppTheme.errorRed,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Delete Item',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              'Are you sure you want to delete "${item['name']}"?',
                              style: const TextStyle(color: Color(0xFF475569)),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.errorRed,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteItem(item['id'].toString());
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 16, color: Color(0xFF14332E)),
                            SizedBox(width: 8),
                            Text('Edit Item', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.errorRed),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(fontSize: 13, color: AppTheme.errorRed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: 6),

            // Middle: Avatar + Title & Location
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        categoryColor.withValues(alpha: 0.18),
                        categoryColor.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: categoryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    categoryIcon,
                    size: 20,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (storageRoom != null && storageRoom.isNotEmpty) ...[
                            const Icon(
                              Icons.location_on_outlined,
                              size: 11,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                storageRoom,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else if (supplier != null && supplier.isNotEmpty) ...[
                            const Icon(
                              Icons.business_outlined,
                              size: 11,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                supplier,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'Standard Inventory',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Stock Visual Progress Meter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Stock Capacity',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: stockColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(
                        height: 5,
                        width: double.infinity,
                        color: const Color(0xFFF1F5F9),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0.02, 1.0),
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                stockColor.withValues(alpha: 0.7),
                                stockColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Bottom: Quantity Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$quantity ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextSpan(
                      text: unit.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top: Real-time Command Center / Inventory Monitoring Banner
            Container(
              margin: EdgeInsets.all(
                ResponsiveUtils.isMobile(context) ? 12 : 16,
              ),
              padding: EdgeInsets.all(
                ResponsiveUtils.isMobile(context) ? 12 : 16,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F2C27),
                    Color(0xFF14332E),
                    Color(0xFF1D4A41),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF28564D),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F2C27).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Banner Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6C374).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: Color(0xFFE6C374),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live Inventory Monitor',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Real-time automated stock health & threshold overview',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFB0C8C3),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_selectedStockStatus != null) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _selectedStockStatus = null);
                          },
                          icon: const Icon(
                            Icons.filter_alt_off_rounded,
                            size: 14,
                            color: Color(0xFFE6C374),
                          ),
                          label: const Text(
                            'Reset Filter',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFE6C374),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Real-time Stream of metrics
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client
                        .from('inventory')
                        .stream(primaryKey: ['id']),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 56,
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Color(0xFFE6C374),
                                strokeWidth: 2,
                              ),
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

                      if (ResponsiveUtils.isMobile(context)) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                _buildRealisticStatCard(
                                  label: 'OUT OF STOCK',
                                  count: outOfStock.toString(),
                                  statusKey: 'OUT OF STOCK',
                                  accentColor: const Color(0xFFEF4444),
                                  icon: Icons.cancel_rounded,
                                  subtitle: 'Immediate action',
                                ),
                                const SizedBox(width: 8),
                                _buildRealisticStatCard(
                                  label: 'LOW STOCK',
                                  count: lowStock.toString(),
                                  statusKey: 'LOW STOCK',
                                  accentColor: const Color(0xFFF59E0B),
                                  icon: Icons.warning_amber_rounded,
                                  subtitle: 'Reorder soon',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildRealisticStatCard(
                                  label: 'NORMAL',
                                  count: normalStock.toString(),
                                  statusKey: 'NORMAL',
                                  accentColor: const Color(0xFF3B82F6),
                                  icon: Icons.check_circle_rounded,
                                  subtitle: 'Healthy stock',
                                ),
                                const SizedBox(width: 8),
                                _buildRealisticStatCard(
                                  label: 'HIGH STOCK',
                                  count: highStock.toString(),
                                  statusKey: 'HIGH STOCK',
                                  accentColor: const Color(0xFF10B981),
                                  icon: Icons.verified_rounded,
                                  subtitle: 'Abundant supply',
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          _buildRealisticStatCard(
                            label: 'OUT OF STOCK',
                            count: outOfStock.toString(),
                            statusKey: 'OUT OF STOCK',
                            accentColor: const Color(0xFFEF4444),
                            icon: Icons.cancel_rounded,
                            subtitle: '0 items left',
                          ),
                          const SizedBox(width: 10),
                          _buildRealisticStatCard(
                            label: 'LOW STOCK',
                            count: lowStock.toString(),
                            statusKey: 'LOW STOCK',
                            accentColor: const Color(0xFFF59E0B),
                            icon: Icons.warning_amber_rounded,
                            subtitle: '1-9 remaining',
                          ),
                          const SizedBox(width: 10),
                          _buildRealisticStatCard(
                            label: 'NORMAL STOCK',
                            count: normalStock.toString(),
                            statusKey: 'NORMAL',
                            accentColor: const Color(0xFF3B82F6),
                            icon: Icons.check_circle_rounded,
                            subtitle: '10-49 units',
                          ),
                          const SizedBox(width: 10),
                          _buildRealisticStatCard(
                            label: 'HIGH STOCK',
                            count: highStock.toString(),
                            statusKey: 'HIGH STOCK',
                            accentColor: const Color(0xFF10B981),
                            icon: Icons.verified_rounded,
                            subtitle: '50+ units',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Search and Category Filter Card
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.isMobile(context) ? 12 : 16,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Row
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search items by name or category...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF14332E),
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Horizontal Category Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        final catColor = _getCategoryColor(category);
                        final catIcon = _getCategoryIcon(category);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
                                _selectedStockStatus = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF14332E)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF14332E)
                                      : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF14332E).withValues(alpha: 0.25),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    catIcon,
                                    size: 14,
                                    color: isSelected
                                        ? const Color(0xFFE6C374)
                                        : catColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Inventory Cards Grid
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('inventory')
                    .stream(primaryKey: ['id'])
                    .order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF14332E),
                      ),
                    );
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

                    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                    final itemStockStatus = _getStockStatus(quantity);
                    final matchesStockStatus = _selectedStockStatus == null ||
                        itemStockStatus == _selectedStockStatus;

                    return matchesSearch && matchesCategory && matchesStockStatus;
                  }).toList();

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
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No inventory items found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Try adjusting your search query or filters',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = 4;
                      double childAspectRatio = 1.15;

                      if (constraints.maxWidth < 600) {
                        crossAxisCount = 1;
                        childAspectRatio = 2.1;
                      } else if (constraints.maxWidth < 900) {
                        crossAxisCount = 2;
                        childAspectRatio = 1.35;
                      } else if (constraints.maxWidth < 1300) {
                        crossAxisCount = 3;
                        childAspectRatio = 1.25;
                      } else {
                        crossAxisCount = 4;
                        childAspectRatio = 1.2;
                      }

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.isMobile(context) ? 12 : 16,
                          vertical: 8,
                        ),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            return _buildItemCard(filteredItems[index]);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _addOrEditItem(),
              backgroundColor: const Color(0xFF14332E),
              foregroundColor: const Color(0xFFE6C374),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Item',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            )
          : null,
    );
  }
}
