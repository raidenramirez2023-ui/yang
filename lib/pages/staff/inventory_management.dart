import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart' as csv_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:yang_chow/services/audit_log_service.dart';
import 'package:yang_chow/services/app_settings_service.dart';

class InventoryPage extends StatefulWidget {
  final bool isViewOnly;
  final bool showImportExport;
  const InventoryPage({
    super.key,
    this.isViewOnly = false,
    this.showImportExport = false,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool _isAdmin = false;
  bool _isPagsanjanInv = false;
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

      final isStaffInv = userEmail == 'pagsanjaninv@gmail.com' || role == 'inventory staff';
      if (userEmail == 'pagsanjaninv@gmail.com' ||
          role == 'inventory staff' ||
          role == 'admin') {
        setState(() {
          _isAdmin = true;
          _isPagsanjanInv = isStaffInv;
        });
      } else {
        setState(() {
          _isAdmin = false;
          _isPagsanjanInv = false;
        });
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

  // ══════════════════════════════════════════════════════════════════════════
  // ── ADMIN INVENTORY EXPORT & PRINT LOGIC ───────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  void _showExportOptionsDialog({List<Map<String, dynamic>>? items}) {
    final hasCategoryFilter = _selectedCategory != 'All';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.output_rounded, color: Color(0xFF14332E), size: 22),
            SizedBox(width: 10),
            Text(
              'Export & Print Inventory',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasCategoryFilter) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF14332E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF14332E).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFF14332E)),
                    const SizedBox(width: 6),
                    Text(
                      'Filtered Category: $_selectedCategory',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF14332E)),
                    ),
                  ],
                ),
              ),
            ],
            const Text(
              'Choose an export format for manual inventory, reporting, or printing physical count sheets:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),

            // Option 1: Print / PDF Physical Inventory Sheet
            _buildExportOptionTile(
              icon: Icons.print_rounded,
              title: hasCategoryFilter ? 'Print Physical Count Sheet ($_selectedCategory)' : 'Print Full Physical Count Sheet (All Categories)',
              subtitle: 'Formatted multi-page sheet with blank write-in boxes for manual audit',
              color: const Color(0xFF14332E),
              onTap: () {
                Navigator.pop(ctx);
                _printPhysicalInventorySheet(items: items, categoryScope: _selectedCategory);
              },
            ),
            const SizedBox(height: 10),

            // Option 2: Export CSV
            _buildExportOptionTile(
              icon: Icons.table_chart_rounded,
              title: hasCategoryFilter ? 'Export to CSV ($_selectedCategory)' : 'Export to CSV (All Categories)',
              subtitle: 'Download complete inventory spreadsheet for Excel / Google Sheets',
              color: const Color(0xFF0D9488),
              onTap: () {
                Navigator.pop(ctx);
                _exportInventoryToCsv(items: items);
              },
            ),
            const SizedBox(height: 10),

            // Option 3: Download CSV Template
            _buildExportOptionTile(
              icon: Icons.download_rounded,
              title: 'Download Blank CSV Template',
              subtitle: 'Pre-formatted template with example rows for manual batch encoding',
              color: const Color(0xFF4F46E5),
              onTap: () {
                Navigator.pop(ctx);
                _downloadCsvTemplate();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
            color: color.withValues(alpha: 0.04),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportInventoryToCsv({List<Map<String, dynamic>>? items}) async {
    try {
      List<Map<String, dynamic>> exportList = items ?? [];
      if (exportList.isEmpty) {
        final res = await Supabase.instance.client
            .from('inventory')
            .select('*')
            .order('name', ascending: true);
        exportList = List<Map<String, dynamic>>.from(res);
      }

      if (exportList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No inventory items to export.'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add(['YANG CHOW PALACE RESTAURANT - INVENTORY MASTER EXPORT']);
      rows.add([
        'Export Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
        'Total Records: ${exportList.length}',
      ]);
      rows.add([]);
      rows.add([
        'Item ID',
        'Item Name',
        'Category',
        'Quantity',
        'Unit',
        'Storage Room',
        'Supplier',
        'Stock Status',
      ]);

      for (var item in exportList) {
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        rows.add([
          item['id']?.toString() ?? '',
          item['name']?.toString() ?? '',
          item['category']?.toString() ?? '',
          qty,
          item['unit']?.toString() ?? '',
          item['storage_room']?.toString() ?? '',
          item['supplier']?.toString() ?? '',
          _getStockStatus(qty),
        ]);
      }

      final csvData = csv_pkg.CsvCodec().encode(rows);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvData));
      final fileName = 'yangchow_inventory_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Inventory CSV',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (outputFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Exported ${exportList.length} inventory items to CSV!')),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _downloadCsvTemplate() async {
    try {
      List<List<dynamic>> rows = [];
      rows.add([
        'Item Name',
        'Category',
        'Quantity',
        'Unit',
        'Storage Room',
        'Supplier',
      ]);
      rows.add([
        'Fresh Pork Belly',
        'Fresh',
        '50',
        'kilo',
        'Freezer',
        'Mega Meat Supply',
      ]);
      rows.add([
        'Soy Sauce Premium',
        'Sauces',
        '24',
        'bot',
        'Dry Storage',
        'Golden Dragon Goods',
      ]);
      rows.add([
        'Takeout Box 500ml',
        'Packaging',
        '100',
        'pcs',
        'Dry Storage',
        'Eco Pack Trading',
      ]);

      final csvData = csv_pkg.CsvCodec().encode(rows);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvData));
      const fileName = 'yangchow_inventory_template.csv';

      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Inventory CSV Template',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (outputFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory CSV template downloaded successfully!'),
            backgroundColor: Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template download failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _printPhysicalInventorySheet({
    List<Map<String, dynamic>>? items,
    String? categoryScope,
  }) async {
    try {
      List<Map<String, dynamic>> printList = items ?? [];
      if (printList.isEmpty) {
        final query = Supabase.instance.client.from('inventory').select('*');
        final res = (categoryScope != null && categoryScope != 'All')
            ? await query.eq('category', categoryScope).order('name', ascending: true)
            : await query.order('category', ascending: true);
        printList = List<Map<String, dynamic>>.from(res);
      }

      if (printList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No inventory items to print.'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
        return;
      }

      // Sort by Category then by Name
      printList.sort((a, b) {
        final catA = (a['category'] ?? '').toString();
        final catB = (b['category'] ?? '').toString();
        final comp = catA.compareTo(catB);
        if (comp != 0) return comp;
        return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
      });

      final doc = pw.Document();
      final nowStr = DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now());

      const itemsPerPage = 22;
      final totalPages = (printList.length / itemsPerPage).ceil();

      for (int pageIdx = 0; pageIdx < totalPages; pageIdx++) {
        final start = pageIdx * itemsPerPage;
        final end = (start + itemsPerPage < printList.length) ? start + itemsPerPage : printList.length;
        final pageItems = printList.sublist(start, end);
        final isLastPage = (pageIdx == totalPages - 1);

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Restaurant Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'YANG CHOW PALACE RESTAURANT',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal900,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'PHYSICAL INVENTORY COUNT & AUDIT SHEET',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            (categoryScope != null && categoryScope != 'All')
                                ? 'Category: $categoryScope (${printList.length} items)'
                                : 'Scope: All Categories (${printList.length} Total Inventory Items)',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal800,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Date: $nowStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text('Page ${pageIdx + 1} of $totalPages', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                  pw.Divider(color: PdfColors.teal900, thickness: 1.5),
                  pw.SizedBox(height: 6),

                  // Table of items
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(24), // #
                      1: const pw.FlexColumnWidth(3.0), // Item Name
                      2: const pw.FlexColumnWidth(1.6), // Category
                      3: const pw.FlexColumnWidth(1.8), // Storage Room
                      4: const pw.FixedColumnWidth(42), // Unit
                      5: const pw.FixedColumnWidth(55), // System Stock
                      6: const pw.FixedColumnWidth(70), // Physical Count (Blank)
                      7: const pw.FlexColumnWidth(2.0), // Remarks
                    },
                    children: [
                      // Table Header
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.teal900),
                        children: [
                          _buildPdfHeaderCell('#'),
                          _buildPdfHeaderCell('Item Name'),
                          _buildPdfHeaderCell('Category'),
                          _buildPdfHeaderCell('Location'),
                          _buildPdfHeaderCell('Unit'),
                          _buildPdfHeaderCell('Sys Qty'),
                          _buildPdfHeaderCell('Physical Count'),
                          _buildPdfHeaderCell('Remarks / Notes'),
                        ],
                      ),
                      // Table Rows
                      ...pageItems.asMap().entries.map((entry) {
                        final index = start + entry.key + 1;
                        final item = entry.value;
                        final isEven = entry.key % 2 == 0;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: isEven ? PdfColors.white : PdfColors.grey100,
                          ),
                          children: [
                            _buildPdfCell(index.toString(), align: pw.TextAlign.center),
                            _buildPdfCell(item['name']?.toString() ?? '', isBold: true),
                            _buildPdfCell(item['category']?.toString() ?? ''),
                            _buildPdfCell(item['storage_room']?.toString() ?? 'Dry Storage'),
                            _buildPdfCell(item['unit']?.toString() ?? 'pcs', align: pw.TextAlign.center),
                            _buildPdfCell(item['quantity']?.toString() ?? '0', align: pw.TextAlign.center, isBold: true),
                            // Blank box for physical count
                            pw.Container(
                              height: 18,
                              margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey500, width: 0.8),
                                color: PdfColors.white,
                              ),
                            ),
                            _buildPdfCell(''),
                          ],
                        );
                      }),
                    ],
                  ),

                  pw.Spacer(),

                  // Signatures Footer only on last page
                  if (isLastPage) ...[
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Physical Count Conducted By:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 18),
                            pw.Container(width: 180, height: 0.5, color: PdfColors.black),
                            pw.SizedBox(height: 2),
                            pw.Text('Staff Signature over Printed Name / Date', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Verified & Approved By:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 18),
                            pw.Container(width: 180, height: 0.5, color: PdfColors.black),
                            pw.SizedBox(height: 2),
                            pw.Text('Admin / Manager Signature / Date', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'yangchow_inventory_count_sheet_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print generation failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  static pw.Widget _buildPdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildPdfCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
        textAlign: align,
        maxLines: 1,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── ADMIN INVENTORY PASSCODE AUTHORIZATION LOGIC ─────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _promptPasscodeVerification() async {
    final passcodeCtrl = TextEditingController();
    bool isObscured = true;
    String? errorMessage;
    bool isValidating = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            elevation: 16,
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon + Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lock_person_rounded,
                          color: Color(0xFFD97706),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Staff Passcode Required',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              'Pagsanjan Inventory Authorization',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB45309)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin inventory is set to audit/monitoring mode. To batch update stock via CSV, please enter the authorization passcode from Pagsanjan Inventory staff.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Passcode Input
                  TextField(
                    controller: passcodeCtrl,
                    obscureText: isObscured,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2),
                    decoration: InputDecoration(
                      labelText: 'Pagsanjan Staff Passcode',
                      hintText: 'Enter authorization code',
                      prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18, color: Color(0xFF14332E)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 18,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () => setDialogState(() => isObscured = !isObscured),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (_) async {
                      if (isValidating) return;
                      setDialogState(() {
                        isValidating = true;
                        errorMessage = null;
                      });
                      final input = passcodeCtrl.text.trim();
                      final currentPasscode = AppSettingsService().getInventoryImportPasscode();
                      if (input.toLowerCase() == currentPasscode.trim().toLowerCase()) {
                        Navigator.pop(dialogCtx, true);
                      } else {
                        setDialogState(() {
                          isValidating = false;
                          errorMessage = 'Invalid Passcode. Please coordinate with Pagsanjan Inventory staff.';
                        });
                      }
                    },
                  ),

                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 14, color: AppTheme.errorRed),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(fontSize: 11, color: AppTheme.errorRed, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14332E),
                          foregroundColor: const Color(0xFFE6C374),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onPressed: isValidating
                            ? null
                            : () async {
                                setDialogState(() {
                                  isValidating = true;
                                  errorMessage = null;
                                });
                                final input = passcodeCtrl.text.trim();
                                final currentPasscode = AppSettingsService().getInventoryImportPasscode();
                                if (input.toLowerCase() == currentPasscode.trim().toLowerCase()) {
                                  Navigator.pop(dialogCtx, true);
                                } else {
                                  setDialogState(() {
                                    isValidating = false;
                                    errorMessage = 'Invalid Passcode. Please coordinate with Pagsanjan Inventory staff.';
                                  });
                                }
                              },
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: const Text('Verify & Proceed', style: TextStyle(fontWeight: FontWeight.w700)),
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

    return result ?? false;
  }

  void _showPasscodeManagerDialog() {
    final currentPasscode = AppSettingsService().getInventoryImportPasscode();
    final editCtrl = TextEditingController(text: currentPasscode);
    bool isEditing = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            elevation: 16,
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 440),
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
                        child: const Icon(
                          Icons.vpn_key_rounded,
                          color: Color(0xFF14332E),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Import Authorization Passcode',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Passcode required by Admin to import stock',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (!isEditing) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F2C27), Color(0xFF14332E)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'CURRENT ACTIVE PASSCODE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB0C8C3),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            currentPasscode,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE6C374),
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: currentPasscode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Passcode copied to clipboard!'),
                                      backgroundColor: Color(0xFF15803D),
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 14),
                                label: const Text('Copy Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE6C374),
                                  foregroundColor: const Color(0xFF14332E),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => setDialogState(() => isEditing = true),
                                icon: const Icon(Icons.edit_rounded, size: 14),
                                label: const Text('Change Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: editCtrl,
                      autofocus: true,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        labelText: 'New Passcode',
                        hintText: 'Enter new authorization code',
                        prefixIcon: const Icon(Icons.key_rounded, size: 18, color: Color(0xFF14332E)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setDialogState(() => isEditing = false),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14332E),
                            foregroundColor: const Color(0xFFE6C374),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final newCode = editCtrl.text.trim();
                                  if (newCode.isEmpty) return;
                                  setDialogState(() => isSaving = true);
                                  await AppSettingsService().updateInventoryImportPasscode(newCode);
                                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Passcode updated to "$newCode"!'),
                                        backgroundColor: const Color(0xFF15803D),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                          child: Text(isSaving ? 'Saving...' : 'Save Passcode', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── ADMIN INVENTORY IMPORT & RECONCILIATION LOGIC ─────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleImportCsv() async {
    // If on Admin side (view-only mode or not pagsanjaninv staff), require passcode verification
    final needsPasscode = widget.isViewOnly || !_isPagsanjanInv;

    if (needsPasscode) {
      final isAuthorized = await _promptPasscodeVerification();
      if (!isAuthorized) return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read the selected CSV file.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
        return;
      }

      final csvString = utf8.decode(file.bytes!);
      final rawRows = csv_pkg.CsvCodec().decode(csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));

      if (rawRows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The selected CSV file is empty.'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
        return;
      }

      // Find header row
      int headerRowIndex = -1;
      for (int i = 0; i < rawRows.length; i++) {
        final row = rawRows[i];
        final rowStr = row.map((c) => c.toString().trim().toLowerCase()).toList();
        if (rowStr.contains('item name') ||
            rowStr.contains('name') ||
            (rowStr.contains('category') && (rowStr.contains('quantity') || rowStr.contains('unit')))) {
          headerRowIndex = i;
          break;
        }
      }

      if (headerRowIndex == -1) {
        for (int i = 0; i < rawRows.length; i++) {
          final row = rawRows[i];
          if (row.any((cell) => cell.toString().toLowerCase().contains('name'))) {
            headerRowIndex = i;
            break;
          }
        }
      }

      if (headerRowIndex == -1) {
        headerRowIndex = 0;
      }

      final headers = rawRows[headerRowIndex].map((h) => h.toString().trim().toLowerCase()).toList();

      int idCol = -1;
      int nameCol = -1;
      int catCol = -1;
      int qtyCol = -1;
      int unitCol = -1;
      int storageCol = -1;
      int supplierCol = -1;

      for (int i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (h == 'item id' || h == 'id' || h == 'item_id' || h == 'itemid') {
          idCol = i;
        } else if (h == 'item name' || h == 'name' || h == 'item_name' || h.contains('item name') || h.contains('product name')) {
          nameCol = i;
        } else if (h.contains('category') || h.contains('cat')) {
          catCol = i;
        } else if (h.contains('status')) {
          // Ignore 'Stock Status' column so it does not overwrite Quantity
          continue;
        } else if (h == 'quantity' ||
            h == 'qty' ||
            h == 'stock' ||
            h == 'count' ||
            h == 'physical count' ||
            h == 'physical_count' ||
            h == 'sys qty' ||
            h.contains('qty') ||
            h.contains('quantity') ||
            h.contains('count') ||
            (h.contains('stock') && !h.contains('status'))) {
          qtyCol = i;
        } else if (h.contains('unit') || h == 'uom') {
          unitCol = i;
        } else if (h.contains('storage') || h.contains('room') || h.contains('location') || h.contains('area')) {
          storageCol = i;
        } else if (h.contains('supplier') || h.contains('vendor')) {
          supplierCol = i;
        }
      }

      // If nameCol is still -1, check for general 'name' or 'item' (excluding idCol)
      if (nameCol == -1) {
        for (int i = 0; i < headers.length; i++) {
          if (i != idCol && (headers[i].contains('name') || headers[i] == 'item')) {
            nameCol = i;
            break;
          }
        }
      }

      if (nameCol == -1 && idCol == -1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid CSV format: Missing "Item Name" column.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
        return;
      }

      // Fetch all current database items
      final existingRes = await Supabase.instance.client
          .from('inventory')
          .select('*');
      final existingList = List<Map<String, dynamic>>.from(existingRes);

      final Map<String, Map<String, dynamic>> existingById = {};
      final Map<String, Map<String, dynamic>> existingByName = {};
      for (var it in existingList) {
        final idStr = it['id']?.toString().trim() ?? '';
        if (idStr.isNotEmpty) {
          existingById[idStr.toLowerCase()] = it;
        }
        final norm = _normalizeItemName(it['name']?.toString() ?? '');
        if (norm.isNotEmpty) {
          existingByName[norm] = it;
        }
      }

      List<Map<String, dynamic>> previewRows = [];

      for (int i = headerRowIndex + 1; i < rawRows.length; i++) {
        final row = rawRows[i];
        if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) continue;

        final rawId = (idCol >= 0 && idCol < row.length) ? row[idCol].toString().trim() : '';
        final rawName = (nameCol >= 0 && nameCol < row.length) ? row[nameCol].toString().trim() : '';
        if (rawName.isEmpty && rawId.isEmpty) continue;

        final rawCat = (catCol >= 0 && catCol < row.length) ? row[catCol].toString().trim() : '';
        final rawQtyStr = (qtyCol >= 0 && qtyCol < row.length) ? row[qtyCol].toString().trim() : '0';
        final rawUnit = (unitCol >= 0 && unitCol < row.length) ? row[unitCol].toString().trim() : 'pcs';
        final rawStorage = (storageCol >= 0 && storageCol < row.length) ? row[storageCol].toString().trim() : 'Dry Storage';
        final rawSupplier = (supplierCol >= 0 && supplierCol < row.length) ? row[supplierCol].toString().trim() : '';

        final parsedQty = int.tryParse(rawQtyStr.replaceAll(RegExp(r'[^0-9]'), ''));

        // Match existing item by ID first, then by normalized Name
        Map<String, dynamic>? existing;
        if (rawId.isNotEmpty && existingById.containsKey(rawId.toLowerCase())) {
          existing = existingById[rawId.toLowerCase()];
        }
        if (existing == null && rawName.isNotEmpty) {
          final norm = _normalizeItemName(rawName);
          existing = existingByName[norm];
        }

        final finalItemName = existing != null ? (existing['name'] ?? rawName) : rawName;

        if (parsedQty == null || parsedQty < 0) {
          previewRows.add({
            'type': 'error',
            'name': finalItemName,
            'category': rawCat.isEmpty ? (existing?['category'] ?? 'Groceries') : rawCat,
            'oldQuantity': existing?['quantity'] ?? 0,
            'newQuantity': 0,
            'unit': rawUnit,
            'storage_room': rawStorage,
            'supplier': rawSupplier,
            'error': 'Invalid quantity ($rawQtyStr)',
            'existingId': existing?['id'],
          });
        } else if (existing != null) {
          final oldQty = (existing['quantity'] as num?)?.toInt() ?? 0;
          previewRows.add({
            'type': 'update',
            'name': finalItemName,
            'category': rawCat.isNotEmpty ? rawCat : (existing['category'] ?? 'Groceries'),
            'oldQuantity': oldQty,
            'newQuantity': parsedQty,
            'diff': parsedQty - oldQty,
            'unit': rawUnit.isNotEmpty ? rawUnit : (existing['unit'] ?? 'pcs'),
            'storage_room': rawStorage.isNotEmpty ? rawStorage : (existing['storage_room'] ?? 'Dry Storage'),
            'supplier': rawSupplier.isNotEmpty ? rawSupplier : (existing['supplier'] ?? ''),
            'existingId': existing['id'],
          });
        } else {
          previewRows.add({
            'type': 'new',
            'name': finalItemName,
            'category': rawCat.isNotEmpty ? rawCat : 'Groceries',
            'oldQuantity': 0,
            'newQuantity': parsedQty,
            'diff': parsedQty,
            'unit': rawUnit.isNotEmpty ? rawUnit : 'pcs',
            'storage_room': rawStorage.isNotEmpty ? rawStorage : 'Dry Storage',
            'supplier': rawSupplier,
            'existingId': null,
          });
        }
      }

      if (previewRows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid inventory rows found in the CSV file.'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      _showImportPreviewDialog(previewRows, file.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read CSV: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showImportPreviewDialog(
    List<Map<String, dynamic>> previewRows,
    String fileName,
  ) {
    final updateCount = previewRows.where((r) => r['type'] == 'update').length;
    final newCount = previewRows.where((r) => r['type'] == 'new').length;
    final errorCount = previewRows.where((r) => r['type'] == 'error').length;
    bool isSyncing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            elevation: 16,
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.isMobile(context) ? double.infinity : 780,
                maxHeight: ResponsiveUtils.isMobile(context)
                    ? MediaQuery.of(context).size.height * 0.9
                    : 680,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14332E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.sync_alt_rounded,
                          color: Color(0xFF14332E),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Physical Inventory Import & Reconciliation',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'File: $fileName • Review stock adjustments before syncing',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: isSyncing ? null : () => Navigator.pop(dialogCtx),
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Metrics Summary Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        _buildImportStatBadge(
                          label: 'Total Rows',
                          count: previewRows.length.toString(),
                          color: const Color(0xFF14332E),
                          icon: Icons.receipt_long_rounded,
                        ),
                        const SizedBox(width: 10),
                        _buildImportStatBadge(
                          label: 'Stock Updates',
                          count: updateCount.toString(),
                          color: const Color(0xFF3B82F6),
                          icon: Icons.update_rounded,
                        ),
                        const SizedBox(width: 10),
                        _buildImportStatBadge(
                          label: 'New Items',
                          count: newCount.toString(),
                          color: const Color(0xFF10B981),
                          icon: Icons.add_circle_outline_rounded,
                        ),
                        if (errorCount > 0) ...[
                          const SizedBox(width: 10),
                          _buildImportStatBadge(
                            label: 'Errors / Skip',
                            count: errorCount.toString(),
                            color: const Color(0xFFEF4444),
                            icon: Icons.error_outline_rounded,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Preview List Table
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: previewRows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, idx) {
                            final row = previewRows[idx];
                            final type = row['type'];
                            final isUpdate = type == 'update';
                            final isNew = type == 'new';
                            final isError = type == 'error';
                            final diff = (row['diff'] as num?)?.toInt() ?? 0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  // Action badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isUpdate
                                          ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                                          : isNew
                                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                              : const Color(0xFFEF4444).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isUpdate ? 'UPDATE' : isNew ? 'NEW ITEM' : 'ERROR',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: isUpdate
                                            ? const Color(0xFF2563EB)
                                            : isNew
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Name and Category
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row['name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${row['category']} • ${row['storage_room']} • ${row['unit']}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Quantities and diff
                                  if (isError) ...[
                                    Text(
                                      row['error'] ?? 'Error',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFDC2626),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ] else ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isUpdate) ...[
                                              Text(
                                                '${row['oldQuantity']} → ',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF94A3B8),
                                                  decoration: TextDecoration.lineThrough,
                                                ),
                                              ),
                                            ],
                                            Text(
                                              '${row['newQuantity']} ${row['unit']}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (isUpdate) ...[
                                          Text(
                                            diff > 0 ? '+$diff ${row['unit']}' : diff < 0 ? '$diff ${row['unit']}' : 'No change',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: diff > 0
                                                  ? const Color(0xFF10B981)
                                                  : diff < 0
                                                      ? const Color(0xFFEF4444)
                                                      : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSyncing ? null : () => Navigator.pop(dialogCtx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          foregroundColor: const Color(0xFF64748B),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14332E),
                          foregroundColor: const Color(0xFFE6C374),
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isSyncing
                            ? null
                            : () async {
                                setDialogState(() => isSyncing = true);
                                await _executeImportSync(previewRows, dialogCtx);
                              },
                        icon: isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFE6C374),
                                ),
                              )
                            : const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: Text(
                          isSyncing ? 'Syncing...' : 'Confirm & Sync Inventory',
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

  Widget _buildImportStatBadge({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeImportSync(
    List<Map<String, dynamic>> previewRows,
    BuildContext dialogCtx,
  ) async {
    int updated = 0;
    int added = 0;
    int failed = 0;

    final user = Supabase.instance.client.auth.currentUser;

    for (var row in previewRows) {
      if (row['type'] == 'error') {
        failed++;
        continue;
      }

      try {
        if (row['type'] == 'update' && row['existingId'] != null) {
          await Supabase.instance.client.from('inventory').update({
            'quantity': row['newQuantity'],
            if (row['category'] != null) 'category': row['category'],
            if (row['unit'] != null) 'unit': row['unit'],
            if (row['storage_room'] != null) 'storage_room': row['storage_room'],
            if (row['supplier'] != null && row['supplier'].toString().isNotEmpty)
              'supplier': row['supplier'],
          }).eq('id', row['existingId']);
          updated++;
        } else if (row['type'] == 'new') {
          await Supabase.instance.client.from('inventory').insert({
            'name': row['name'],
            'category': row['category'],
            'quantity': row['newQuantity'],
            'unit': row['unit'],
            'storage_room': row['storage_room'],
            'supplier': row['supplier'],
            'created_by': user?.email,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
          added++;
        }
      } catch (e) {
        debugPrint('Error syncing row ${row['name']}: $e');
        failed++;
      }
    }

    // Log to Audit Log Service
    try {
      await AuditLogService.logActivity(
        action: 'IMPORT',
        module: 'Inventory',
        description: 'Physical inventory import: updated $updated items, added $added items.',
        metadata: {
          'updated_count': updated,
          'added_count': added,
          'failed_count': failed,
          'total_processed': previewRows.length,
        },
      );
    } catch (_) {}

    if (dialogCtx.mounted) {
      Navigator.pop(dialogCtx);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Inventory sync complete! Updated: $updated, Added: $added${failed > 0 ? ', Errors: $failed' : ''}'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                  // Search Row + Admin Import/Export actions
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
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
                      ),
                      if (widget.showImportExport) ...[
                        if (_isPagsanjanInv || !widget.isViewOnly) ...[
                          const SizedBox(width: 8),
                          // Passcode manager button for pagsanjaninv
                          ElevatedButton.icon(
                            onPressed: _showPasscodeManagerDialog,
                            icon: const Icon(Icons.vpn_key_rounded, size: 15),
                            label: ResponsiveUtils.isMobile(context)
                                ? const SizedBox.shrink()
                                : const Text(
                                    'Passcode',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFEF3C7),
                              foregroundColor: const Color(0xFFB45309),
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.isMobile(context) ? 10 : 12,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFFDE68A)),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        // Import CSV Button
                        ElevatedButton.icon(
                          onPressed: _handleImportCsv,
                          icon: const Icon(Icons.file_upload_outlined, size: 16),
                          label: ResponsiveUtils.isMobile(context)
                              ? const SizedBox.shrink()
                              : const Text(
                                  'Import CSV',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            foregroundColor: const Color(0xFF14332E),
                            elevation: 0,
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.isMobile(context) ? 10 : 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Export & Print Button
                        ElevatedButton.icon(
                          onPressed: () => _showExportOptionsDialog(),
                          icon: const Icon(Icons.print_outlined, size: 16),
                          label: ResponsiveUtils.isMobile(context)
                              ? const SizedBox.shrink()
                              : const Text(
                                  'Export / Print',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14332E),
                            foregroundColor: const Color(0xFFE6C374),
                            elevation: 1,
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.isMobile(context) ? 10 : 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ],
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
