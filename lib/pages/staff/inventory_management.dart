import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart' as csv_pkg;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:yang_chow/utils/file_download.dart';
import 'package:yang_chow/utils/global_messenger.dart';
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
  bool _isBannerCollapsed = false;
  List<Map<String, dynamic>> _currentDisplayedItems = [];

  // ── INVENTORY MANAGEMENT COLOR SYSTEM ──
  // Primary   : brand forest green — the ONLY solid fill color for actions & selected states.
  // Neutrals  : slate scale — text hierarchy, borders, surfaces (no harsh pure black).
  // Semantic  : muted status hues — used sparingly as indicators & soft tints.
  static const Color _invPrimary = Color(0xFF14332E);
  static const Color _invTextPrimary = Color(0xFF0F172A);
  static const Color _invTextSecondary = Color(0xFF334155);
  static const Color _invTextTertiary = Color(0xFF64748B);
  static const Color _invTextMuted = Color(0xFF94A3B8);
  static const Color _invBorder = Color(0xFFE2E8F0);
  static const Color _invBorderStrong = Color(0xFFCBD5E1);
  static const Color _invSurface = Color(0xFFF8FAFC);
  static const Color _invSurfaceAlt = Color(0xFFF1F5F9);
  static const Color _invSuccess = Color(0xFF15803D);
  static const Color _invWarning = Color(0xFFB45309);
  static const Color _invDanger = Color(0xFFB91C1C);

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

  List<Map<String, dynamic>> _filterAndSortItems(List<Map<String, dynamic>> items) {
    final filtered = items.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final category = (item['category'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty || name.contains(query) || category.contains(query);
      final matchesCategory = _selectedCategory == 'All' ||
          item['category']?.toString() == _selectedCategory;

      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      final itemStockStatus = _getStockStatus(quantity);
      final matchesStockStatus = _selectedStockStatus == null ||
          itemStockStatus == _selectedStockStatus;

      return matchesSearch && matchesCategory && matchesStockStatus;
    }).toList();

    filtered.sort((a, b) {
      final nameA = (a['name'] ?? '').toString().toLowerCase();
      final nameB = (b['name'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });

    return filtered;
  }

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
    return Colors.black;
  }

  String _getStockStatus(int quantity) {
    if (quantity == 0) return 'OUT OF STOCK';
    if (quantity < 10) return 'LOW STOCK';
    if (quantity < 50) return 'NORMAL';
    return 'HIGH STOCK';
  }

  Color _getStockStatusColor(int quantity) {
    if (quantity == 0) return _invDanger;
    if (quantity < 10) return _invWarning;
    return _invSuccess;
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
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: _invBorder, width: 1.0),
            ),
            elevation: 12,
            backgroundColor: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.isMobile(context) ? double.infinity : 480,
                maxHeight: ResponsiveUtils.isMobile(context)
                    ? MediaQuery.of(context).size.height * 0.88
                    : 650,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: _invBorder, width: 1.0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _invPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _invPrimary.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Icon(
                            item == null
                                ? Icons.add_box_rounded
                                : Icons.edit_note_rounded,
                            color: _invPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item == null ? 'Add New Item' : 'Edit Inventory Item',
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      color: _invTextPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _invPrimary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      item == null ? 'NEW' : 'EDIT',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: _invPrimary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item == null
                                    ? 'Fill in item details to register to inventory'
                                    : 'Update item specifications or storage location',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _invTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _invSurface,
                              shape: BoxShape.circle,
                              border: Border.all(color: _invBorder),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: _invTextTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dialog Form Body
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section 1: Item Identification
                          _buildFormSectionHeader('Item Identification', Icons.info_outline_rounded),

                          _buildFieldLabel('Category', isRequired: true),
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: _decoration('Category', Icons.category_rounded, hintText: 'Select category'),
                            hint: const Text(
                              'Select category',
                              style: TextStyle(color: _invTextMuted, fontSize: 13),
                            ),
                            items: categoryList
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getCategoryIcon(category),
                                          size: 15,
                                          color: _getCategoryColor(category),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          category,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: _invTextPrimary,
                                          ),
                                        ),
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

                          _input(
                            nameCtrl,
                            'Item Name',
                            Icons.inventory_2_rounded,
                            hintText: 'e.g. Beef Campto, Jasmine Rice',
                            isRequired: true,
                            inputFormatters: [LengthLimitingTextInputFormatter(50)],
                          ),
                          const SizedBox(height: 16),

                          // Section 2: Storage & Units
                          _buildFormSectionHeader('Storage & Measurement', Icons.straighten_rounded),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Measurement Unit
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('Measurement Unit', isRequired: true),
                                    DropdownButtonFormField<String>(
                                      initialValue: selectedUnit,
                                      decoration: _decoration(
                                        'Measurement Unit',
                                        Icons.straighten_rounded,
                                        hintText: 'Select unit',
                                      ),
                                      hint: const Text(
                                        'Select unit',
                                        style: TextStyle(color: _invTextMuted, fontSize: 13),
                                      ),
                                      items: unitList
                                          .map(
                                            (unit) => DropdownMenuItem(
                                              value: unit,
                                              child: Text(
                                                unit,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: _invTextPrimary,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(() => selectedUnit = value);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Storage Room
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('Storage Room', isRequired: true),
                                    DropdownButtonFormField<String>(
                                      initialValue: selectedStorageRoom,
                                      decoration: _decoration(
                                        'Storage Room',
                                        Icons.kitchen_rounded,
                                        hintText: 'Select room',
                                      ),
                                      hint: const Text(
                                        'Select room',
                                        style: TextStyle(color: _invTextMuted, fontSize: 13),
                                      ),
                                      items: storageRoomList
                                          .map(
                                            (room) {
                                              IconData roomIcon = Icons.kitchen_rounded;
                                              final r = room.toLowerCase();
                                              if (r.contains('freezer')) {
                                                roomIcon = Icons.ac_unit_rounded;
                                              } else if (r.contains('dry')) {
                                                roomIcon = Icons.inventory_2_outlined;
                                              } else if (r.contains('cleaning')) {
                                                roomIcon = Icons.cleaning_services_rounded;
                                              }
                                              return DropdownMenuItem(
                                                value: room,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(roomIcon, size: 14, color: _invTextTertiary),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        room,
                                                        style: const TextStyle(
                                                          fontSize: 12.5,
                                                          fontWeight: FontWeight.w500,
                                                          color: _invTextPrimary,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(() => selectedStorageRoom = value);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (item != null) ...[
                            const SizedBox(height: 14),
                            _input(
                              qtyCtrl,
                              'Current Stock Quantity',
                              Icons.pin_rounded,
                              isNumber: true,
                              readOnly: true,
                              helperText: 'Stock is updated via audits and receiving logs',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Section 3: Procurement
                          _buildFormSectionHeader('Procurement', Icons.business_rounded),

                          _input(
                            supplierCtrl,
                            'Supplier Name',
                            Icons.business_rounded,
                            hintText: 'e.g. San Miguel Corp, Direct Wholesale',
                            isRequired: item == null,
                            inputFormatters: [LengthLimitingTextInputFormatter(50)],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // Dialog Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: _invSurface,
                      border: Border(
                        top: BorderSide(color: _invBorder, width: 1.0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _invBorderStrong),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _invTextSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
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
                          icon: Icon(
                            item == null ? Icons.add_rounded : Icons.check_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                          label: Text(
                            item == null ? 'Create Item' : 'Save Changes',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _invPrimary,
                            foregroundColor: Colors.white,
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _invTextSecondary,
              letterSpacing: 0.1,
            ),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _invTextTertiary),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: _invTextTertiary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: _invBorder,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? hintText,
    String? helperText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: _invTextMuted,
        fontSize: 12.5,
        fontWeight: FontWeight.normal,
      ),
      helperText: helperText,
      helperStyle: const TextStyle(
        color: _invTextTertiary,
        fontSize: 11,
      ),
      prefixIcon: Icon(icon, color: _invTextTertiary, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _invBorder, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _invBorder, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _invPrimary, width: 1.5),
      ),
      filled: true,
      fillColor: _invSurface,
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNumber = false,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    String? hintText,
    String? helperText,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired: isRequired),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          style: const TextStyle(
            fontSize: 13,
            color: _invTextPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: _decoration(
            label,
            icon,
            hintText: hintText,
            helperText: helperText,
          ),
        ),
      ],
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
    final effectiveItems = items ?? _currentDisplayedItems;
    final hasCategoryFilter = _selectedCategory != 'All';
    final hasSearchFilter = _searchQuery.trim().isNotEmpty;
    final hasStockFilter = _selectedStockStatus != null;
    final isFiltered = hasCategoryFilter || hasSearchFilter || hasStockFilter;

    final String scopeLabel;
    if (hasSearchFilter) {
      scopeLabel = 'Search: "$_searchQuery"';
    } else if (hasStockFilter) {
      scopeLabel = '$_selectedStockStatus';
    } else if (hasCategoryFilter) {
      scopeLabel = '$_selectedCategory';
    } else {
      scopeLabel = 'All Categories';
    }

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
              'Export & Count Sheets',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      'Screen View: $scopeLabel (${effectiveItems.length} items)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF14332E)),
                    ),
                  ],
                ),
              ),
              const Text(
                'Choose a format for manual inventory, reporting, or downloading count sheets:',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),

              // Option 1: Download PDF Physical Count Sheet
              _buildExportOptionTile(
                icon: Icons.picture_as_pdf_rounded,
                title: isFiltered ? 'Download Physical Count Sheet (PDF) ($scopeLabel)' : 'Download Physical Count Sheet (PDF)',
                subtitle: 'Directly saves formatted multi-page PDF to your device (${effectiveItems.length} items, no printer needed)',
                color: const Color(0xFFDC2626),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadPhysicalInventoryPdf(items: effectiveItems, categoryScope: _selectedCategory);
                },
              ),
              const SizedBox(height: 10),

              // Option 2: Print Physical Count Sheet
              _buildExportOptionTile(
                icon: Icons.print_rounded,
                title: isFiltered ? 'Print Physical Count Sheet ($scopeLabel)' : 'Print Physical Count Sheet (All Categories)',
                subtitle: 'Send count sheet directly to system printer dialog (${effectiveItems.length} items)',
                color: const Color(0xFF14332E),
                onTap: () {
                  Navigator.pop(ctx);
                  _printPhysicalInventorySheet(items: effectiveItems, categoryScope: _selectedCategory);
                },
              ),
              const SizedBox(height: 10),

              // Option 3: Export Excel
              _buildExportOptionTile(
                icon: Icons.table_chart_rounded,
                title: isFiltered ? 'Export to Excel ($scopeLabel)' : 'Export to Excel (All Categories)',
                subtitle: 'Download the exact ${effectiveItems.length} items displayed on screen in formatted Excel (.xlsx)',
                color: const Color(0xFF0D9488),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportInventoryToExcel(items: effectiveItems);
                },
              ),
              const SizedBox(height: 10),

              // Option 4: Download Excel Template
              _buildExportOptionTile(
                icon: Icons.download_rounded,
                title: 'Download Blank Excel Template',
                subtitle: 'Pre-formatted .xlsx template with sample rows and guidelines for batch encoding',
                color: const Color(0xFF4F46E5),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadExcelTemplate();
                },
              ),
            ],
          ),
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

  Future<void> _saveAndDownloadExcel({
    required Uint8List bytes,
    required String fileName,
    required String successMessage,
  }) async {
    // 1. Direct Web Download
    if (kIsWeb) {
      final downloaded = downloadBinaryFile(
        bytes,
        '$fileName.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (downloaded) {
        GlobalMessenger.showSuccess(successMessage);
        return;
      }
    } else {
      // 2. Direct Desktop Download to Downloads folder
      try {
        if (!kIsWeb && Platform.isWindows) {
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null) {
            final downloadsDir = Directory('$userProfile\\Downloads');
            if (downloadsDir.existsSync()) {
              final targetPath = '${downloadsDir.path}\\$fileName.xlsx';
              final file = File(targetPath);
              await file.writeAsBytes(bytes);
              GlobalMessenger.showSuccess('$successMessage (Saved to Downloads)');
              return;
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: FilePicker save dialog
    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Excel Spreadsheet',
      fileName: '$fileName.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      bytes: bytes,
    );

    if (outputFile != null && mounted) {
      GlobalMessenger.showSuccess(successMessage);
    }
  }

  Future<void> _saveAndDownloadPdf({
    required Uint8List bytes,
    required String fileName,
    required String successMessage,
  }) async {
    // 1. Direct Web Download
    if (kIsWeb) {
      final downloaded = downloadBinaryFile(
        bytes,
        '$fileName.pdf',
        'application/pdf',
      );
      if (downloaded) {
        GlobalMessenger.showSuccess(successMessage);
        return;
      }
    } else {
      // 2. Direct Desktop Download to Downloads folder
      try {
        if (!kIsWeb && Platform.isWindows) {
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null) {
            final downloadsDir = Directory('$userProfile\\Downloads');
            if (downloadsDir.existsSync()) {
              final targetPath = '${downloadsDir.path}\\$fileName.pdf';
              final file = File(targetPath);
              await file.writeAsBytes(bytes);
              GlobalMessenger.showSuccess('$successMessage (Saved to Downloads)');
              return;
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: FilePicker save dialog
    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF Document',
      fileName: '$fileName.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );

    if (outputFile != null && mounted) {
      GlobalMessenger.showSuccess(successMessage);
    }
  }

  Future<void> _exportInventoryToExcel({List<Map<String, dynamic>>? items}) async {
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

      GlobalMessenger.showInfo('Generating organized Excel inventory masterlist...');

      final excel = excel_pkg.Excel.createExcel();
      excel.delete('Sheet1');

      final headerStyle = excel_pkg.CellStyle(
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#14332E'),
        horizontalAlign: excel_pkg.HorizontalAlign.Left,
        bold: true,
      );

      final titleStyle = excel_pkg.CellStyle(
        fontSize: 14,
        bold: true,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#14332E'),
      );

      final subTitleStyle = excel_pkg.CellStyle(
        fontSize: 10,
        bold: true,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#475569'),
      );

      final totalRowStyle = excel_pkg.CellStyle(
        bold: true,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#0F172A'),
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E2E8F0'),
      );

      final zebraStyle = excel_pkg.CellStyle(
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#F8FAFC'),
      );

      void appendRow(excel_pkg.Sheet sheet, List<excel_pkg.CellValue?> rowValues, {excel_pkg.CellStyle? style}) {
        sheet.appendRow(rowValues);
        if (style != null) {
          final rIndex = sheet.maxRows - 1;
          for (var c = 0; c < rowValues.length; c++) {
            final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rIndex));
            cell.cellStyle = style;
          }
        }
      }

      // ────────────────────────────────────────────────────────────────────────
      // TAB 1: INVENTORY MASTERLIST
      // Clean 8-column layout matching inventory management needs:
      //  # | Item Name | Category | Stock Quantity | Unit | Stock Status | Storage Room | Supplier
      // ────────────────────────────────────────────────────────────────────────
      final sheet = excel['Inventory Masterlist'];
      sheet.setColumnWidth(0, 6.0);   // #
      sheet.setColumnWidth(1, 32.0);  // Item Name
      sheet.setColumnWidth(2, 18.0);  // Category
      sheet.setColumnWidth(3, 16.0);  // Stock Quantity
      sheet.setColumnWidth(4, 10.0);  // Unit
      sheet.setColumnWidth(5, 16.0);  // Stock Status
      sheet.setColumnWidth(6, 22.0);  // Storage Room
      sheet.setColumnWidth(7, 26.0);  // Supplier

      appendRow(sheet, [excel_pkg.TextCellValue('YANG CHOW PALACE RESTAURANT - INVENTORY MASTERLIST')], style: titleStyle);
      appendRow(sheet, [
        excel_pkg.TextCellValue(
          'Export Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} • Category: $_selectedCategory • Total Items: ${exportList.length}',
        ),
      ], style: subTitleStyle);
      sheet.appendRow([excel_pkg.TextCellValue('')]);

      appendRow(sheet, [
        excel_pkg.TextCellValue('#'),
        excel_pkg.TextCellValue('Item Name'),
        excel_pkg.TextCellValue('Category'),
        excel_pkg.TextCellValue('Stock Quantity'),
        excel_pkg.TextCellValue('Unit'),
        excel_pkg.TextCellValue('Stock Status'),
        excel_pkg.TextCellValue('Storage Room'),
        excel_pkg.TextCellValue('Supplier'),
      ], style: headerStyle);

      num totalStockVolume = 0;
      final Map<String, int> categoryCounts = {};
      final Map<String, num> categoryStockTotals = {};

      for (int i = 0; i < exportList.length; i++) {
        final item = exportList[i];
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final qtyInt = qty.toInt();
        totalStockVolume += qty;

        final cat = (item['category'] ?? 'Uncategorized').toString().trim();
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
        categoryStockTotals[cat] = (categoryStockTotals[cat] ?? 0) + qty;

        final status = _getStockStatus(qtyInt);
        final isEven = (i % 2 == 0);

        appendRow(
          sheet,
          [
            excel_pkg.IntCellValue(i + 1),
            excel_pkg.TextCellValue(item['name']?.toString() ?? ''),
            excel_pkg.TextCellValue(cat),
            qty == qtyInt ? excel_pkg.IntCellValue(qtyInt) : excel_pkg.DoubleCellValue(qty),
            excel_pkg.TextCellValue(item['unit']?.toString() ?? ''),
            excel_pkg.TextCellValue(status),
            excel_pkg.TextCellValue(item['storage_room']?.toString() ?? ''),
            excel_pkg.TextCellValue(item['supplier']?.toString() ?? ''),
          ],
          style: isEven ? null : zebraStyle,
        );
      }

      // Total row — 8 columns
      appendRow(sheet, [
        excel_pkg.TextCellValue('TOTAL'),
        excel_pkg.TextCellValue('${exportList.length} Items Listed'),
        excel_pkg.TextCellValue('-'),
        totalStockVolume == totalStockVolume.toInt()
            ? excel_pkg.IntCellValue(totalStockVolume.toInt())
            : excel_pkg.DoubleCellValue(totalStockVolume.toDouble()),
        excel_pkg.TextCellValue('Total Units'),
        excel_pkg.TextCellValue('-'),
        excel_pkg.TextCellValue('-'),
        excel_pkg.TextCellValue('-'),
      ], style: totalRowStyle);

      // ────────────────────────────────────────────────────────────────────────
      // TAB 2: PHYSICAL INVENTORY COUNT SHEET (grouped by category)
      // Columns: # | Item Name | Unit | System Qty | Physical Count | Storage Room | Stock Status | Notes
      // ────────────────────────────────────────────────────────────────────────
      final catSheet = excel['Physical Count Sheet'];
      catSheet.setColumnWidth(0, 6.0);   // #
      catSheet.setColumnWidth(1, 32.0);  // Item Name
      catSheet.setColumnWidth(2, 10.0);  // Unit
      catSheet.setColumnWidth(3, 16.0);  // System Qty
      catSheet.setColumnWidth(4, 20.0);  // Physical Count (blank)
      catSheet.setColumnWidth(5, 22.0);  // Storage Room
      catSheet.setColumnWidth(6, 16.0);  // Stock Status
      catSheet.setColumnWidth(7, 30.0);  // Notes

      final categoryHeaderStyle = excel_pkg.CellStyle(
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#0D9488'),
        bold: true,
      );

      final categoryTotalStyle = excel_pkg.CellStyle(
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#0F172A'),
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#CCFBF1'),
        bold: true,
        italic: true,
      );

      final nowStr = DateFormat('MMMM dd, yyyy – hh:mm a').format(DateTime.now());
      appendRow(catSheet, [
        excel_pkg.TextCellValue('YANG CHOW PALACE RESTAURANT — PHYSICAL INVENTORY COUNT SHEET'),
      ], style: titleStyle);
      appendRow(catSheet, [
        excel_pkg.TextCellValue('Date: $nowStr   •   Checked by: ___________________________   •   Category: $_selectedCategory'),
      ], style: subTitleStyle);
      catSheet.appendRow([excel_pkg.TextCellValue('')]);

      // Group items by category (preserve insertion order from exportList)
      final Map<String, List<Map<String, dynamic>>> groupedByCategory = {};
      for (final item in exportList) {
        final cat = (item['category'] ?? 'Uncategorized').toString().trim();
        groupedByCategory.putIfAbsent(cat, () => []).add(item);
      }

      // Sort categories alphabetically
      final sortedCategories = groupedByCategory.keys.toList()..sort();

      int rowNum = 1;
      for (final cat in sortedCategories) {
        final items = groupedByCategory[cat]!;

        // Category group header (8 columns)
        appendRow(catSheet, [
          excel_pkg.TextCellValue(''),
          excel_pkg.TextCellValue('📦  ${cat.toUpperCase()}'),
          excel_pkg.TextCellValue(''),
          excel_pkg.TextCellValue(''),
          excel_pkg.TextCellValue(''),
          excel_pkg.TextCellValue(''),
          excel_pkg.TextCellValue(''),
          excel_pkg.TextCellValue(''),
        ], style: categoryHeaderStyle);

        // Column headers per group (8 columns)
        appendRow(catSheet, [
          excel_pkg.TextCellValue('#'),
          excel_pkg.TextCellValue('Item Name'),
          excel_pkg.TextCellValue('Unit'),
          excel_pkg.TextCellValue('System Qty'),
          excel_pkg.TextCellValue('Physical Count'),
          excel_pkg.TextCellValue('Storage Room'),
          excel_pkg.TextCellValue('Stock Status'),
          excel_pkg.TextCellValue('Notes'),
        ], style: headerStyle);

        num catSystemTotal = 0;
        for (int j = 0; j < items.length; j++) {
          final item = items[j];
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          final qtyInt = qty.toInt();
          catSystemTotal += qty;
          final status = _getStockStatus(qtyInt);
          final isEven = (j % 2 == 0);

          appendRow(catSheet, [
            excel_pkg.IntCellValue(rowNum++),
            excel_pkg.TextCellValue(item['name']?.toString() ?? ''),
            excel_pkg.TextCellValue(item['unit']?.toString() ?? ''),
            qty == qtyInt ? excel_pkg.IntCellValue(qtyInt) : excel_pkg.DoubleCellValue(qty),
            excel_pkg.TextCellValue(''),   // Physical Count — blank for staff to fill
            excel_pkg.TextCellValue(item['storage_room']?.toString() ?? ''),
            excel_pkg.TextCellValue(status),
            excel_pkg.TextCellValue(''),   // Notes — blank
          ], style: isEven ? null : zebraStyle);
        }

        // Category subtotal row (8 columns)
        appendRow(catSheet, [
          excel_pkg.TextCellValue(''),
          excel_pkg.TextCellValue('${cat.toUpperCase()} SUBTOTAL — ${items.length} item(s)'),
          excel_pkg.TextCellValue(''),
          catSystemTotal == catSystemTotal.toInt()
              ? excel_pkg.IntCellValue(catSystemTotal.toInt())
              : excel_pkg.DoubleCellValue(catSystemTotal.toDouble()),
          excel_pkg.TextCellValue(''),
          excel_pkg.TextCellValue(''),
          excel_pkg.TextCellValue(''),
          excel_pkg.TextCellValue(''),
        ], style: categoryTotalStyle);

        catSheet.appendRow([excel_pkg.TextCellValue('')]); // spacer between categories
      }

      // Grand total row (8 columns)
      appendRow(catSheet, [
        excel_pkg.TextCellValue('GRAND TOTAL'),
        excel_pkg.TextCellValue('${exportList.length} Items'),
        excel_pkg.TextCellValue(''),
        totalStockVolume == totalStockVolume.toInt()
            ? excel_pkg.IntCellValue(totalStockVolume.toInt())
            : excel_pkg.DoubleCellValue(totalStockVolume.toDouble()),
        excel_pkg.TextCellValue(''),
        excel_pkg.TextCellValue(''),
        excel_pkg.TextCellValue(''),
        excel_pkg.TextCellValue(''),
      ], style: totalRowStyle);

      final excelBytes = excel.save();
      if (excelBytes == null) throw Exception('Excel encoding failed');
      final Uint8List bytes = Uint8List.fromList(excelBytes);

      final fileName = 'yangchow_inventory_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

      await _saveAndDownloadExcel(
        bytes: bytes,
        fileName: fileName,
        successMessage: 'Exported ${exportList.length} inventory items to Excel spreadsheet!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel export failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _downloadExcelTemplate() async {
    // Fetch real items from the DB to use as sample rows
    List<Map<String, dynamic>> sampleItems = [];
    try {
      final res = await Supabase.instance.client
          .from('inventory')
          .select('name, category, quantity, unit, storage_room, supplier')
          .order('name', ascending: true)
          .limit(5);
      sampleItems = List<Map<String, dynamic>>.from(res);
    } catch (_) {}
    try {
      final excel = excel_pkg.Excel.createExcel();
      excel.delete('Sheet1');

      final headerStyle = excel_pkg.CellStyle(
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#14332E'),
        horizontalAlign: excel_pkg.HorizontalAlign.Left,
        bold: true,
      );

      final titleStyle = excel_pkg.CellStyle(
        fontSize: 13,
        bold: true,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#14332E'),
      );

      final guideHeaderStyle = excel_pkg.CellStyle(
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#0D9488'),
        horizontalAlign: excel_pkg.HorizontalAlign.Left,
        bold: true,
      );

      void appendRow(excel_pkg.Sheet sheet, List<excel_pkg.CellValue?> rowValues, {excel_pkg.CellStyle? style}) {
        sheet.appendRow(rowValues);
        if (style != null) {
          final rIndex = sheet.maxRows - 1;
          for (var c = 0; c < rowValues.length; c++) {
            final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rIndex));
            cell.cellStyle = style;
          }
        }
      }

      // TAB 1: Template
      final templateSheet = excel['Inventory Import Template'];
      templateSheet.setColumnWidth(0, 30.0); // Item Name
      templateSheet.setColumnWidth(1, 18.0); // Category
      templateSheet.setColumnWidth(2, 14.0); // Quantity
      templateSheet.setColumnWidth(3, 12.0); // Unit
      templateSheet.setColumnWidth(4, 20.0); // Storage Room
      templateSheet.setColumnWidth(5, 28.0); // Supplier

      appendRow(templateSheet, [
        excel_pkg.TextCellValue('Item Name'),
        excel_pkg.TextCellValue('Category'),
        excel_pkg.TextCellValue('Quantity'),
        excel_pkg.TextCellValue('Unit'),
        excel_pkg.TextCellValue('Storage Room'),
        excel_pkg.TextCellValue('Supplier'),
      ], style: headerStyle);

      // Sample rows — pulled dynamically from the live inventory database
      if (sampleItems.isNotEmpty) {
        for (final item in sampleItems) {
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          final qtyInt = qty.toInt();
          appendRow(templateSheet, [
            excel_pkg.TextCellValue(item['name']?.toString() ?? ''),
            excel_pkg.TextCellValue(item['category']?.toString() ?? ''),
            qty == qtyInt ? excel_pkg.IntCellValue(qtyInt) : excel_pkg.DoubleCellValue(qty),
            excel_pkg.TextCellValue(item['unit']?.toString() ?? 'pcs'),
            excel_pkg.TextCellValue(item['storage_room']?.toString() ?? 'Dry Storage'),
            excel_pkg.TextCellValue(item['supplier']?.toString() ?? ''),
          ]);
        }
      } else {
        // Fallback placeholder if DB is empty
        appendRow(templateSheet, [
          excel_pkg.TextCellValue('(Item Name)'),
          excel_pkg.TextCellValue('(Category)'),
          excel_pkg.IntCellValue(0),
          excel_pkg.TextCellValue('pcs'),
          excel_pkg.TextCellValue('Dry Storage'),
          excel_pkg.TextCellValue('(Supplier)'),
        ]);
      }

      // TAB 2: Guide & Reference
      final guideSheet = excel['Guidelines & Valid Values'];
      guideSheet.setColumnWidth(0, 22.0);
      guideSheet.setColumnWidth(1, 48.0);

      appendRow(guideSheet, [excel_pkg.TextCellValue('YANG CHOW INVENTORY BATCH ENCODING GUIDELINES')], style: titleStyle);
      guideSheet.appendRow([excel_pkg.TextCellValue('')]);
      appendRow(guideSheet, [
        excel_pkg.TextCellValue('Column Field'),
        excel_pkg.TextCellValue('Accepted Options & Validation Rule'),
      ], style: guideHeaderStyle);

      appendRow(guideSheet, [
        excel_pkg.TextCellValue('Item Name'),
        excel_pkg.TextCellValue('Required. Unique name of the ingredient or item (e.g. Fresh Pork Belly)'),
      ]);
      appendRow(guideSheet, [
        excel_pkg.TextCellValue('Category'),
        excel_pkg.TextCellValue(
          categories.where((c) => c != 'All').join(', '),
        ),
      ]);
      appendRow(guideSheet, [
        excel_pkg.TextCellValue('Quantity'),
        excel_pkg.TextCellValue('Required. Physical count quantity (whole numbers or decimals like 25 or 12.5)'),
      ]);
      appendRow(guideSheet, [
        excel_pkg.TextCellValue('Unit'),
        excel_pkg.TextCellValue(unitOptions.join(', ')),
      ]);
      appendRow(guideSheet, [
        excel_pkg.TextCellValue('Storage Room'),
        excel_pkg.TextCellValue('Freezer, Chiller, Dry Storage, Bar, Kitchen Counter'),
      ]);
      appendRow(guideSheet, [
        excel_pkg.TextCellValue('Supplier'),
        excel_pkg.TextCellValue('Optional. Vendor or supplier company name'),
      ]);

      final excelBytes = excel.save();
      if (excelBytes == null) throw Exception('Excel template encoding failed');
      final Uint8List bytes = Uint8List.fromList(excelBytes);

      const fileName = 'yangchow_inventory_template';

      await _saveAndDownloadExcel(
        bytes: bytes,
        fileName: fileName,
        successMessage: 'Inventory Excel template downloaded successfully!',
      );
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

  Future<pw.Document?> _generatePhysicalInventoryPdfDoc({
    List<Map<String, dynamic>>? items,
    String? categoryScope,
  }) async {
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
            content: Text('No inventory items to export.'),
            backgroundColor: AppTheme.warningOrange,
          ),
        );
      }
      return null;
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
    return doc;
  }

  Future<void> _downloadPhysicalInventoryPdf({
    List<Map<String, dynamic>>? items,
    String? categoryScope,
  }) async {
    try {
      final doc = await _generatePhysicalInventoryPdfDoc(
        items: items,
        categoryScope: categoryScope,
      );
      if (doc == null) return;

      final pdfBytes = await doc.save();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final cleanScope = (categoryScope != null && categoryScope != 'All')
          ? '_${categoryScope.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}'
          : '_all';
      final fileName = 'yangchow_physical_count_sheet${cleanScope}_$dateStr';

      await _saveAndDownloadPdf(
        bytes: pdfBytes,
        fileName: fileName,
        successMessage: 'Physical count sheet downloaded as PDF successfully!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF download failed: $e'),
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
      final doc = await _generatePhysicalInventoryPdfDoc(
        items: items,
        categoryScope: categoryScope,
      );
      if (doc == null) return;

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
  // ── PHYSICAL STOCK AUDIT & VARIANCE CHECKER (READ-ONLY) ─────────────────
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
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read the selected spreadsheet file.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
        return;
      }

      List<List<dynamic>> rawRows = [];
      final ext = file.extension?.toLowerCase() ?? '';

      if (ext == 'xlsx' || ext == 'xls') {
        try {
          final excel = excel_pkg.Excel.decodeBytes(file.bytes!);
          if (excel.tables.isNotEmpty) {
            excel_pkg.Sheet? targetSheet;
            final sheetNames = excel.tables.keys.toList();

            excel_pkg.Sheet? physicalSheet;
            excel_pkg.Sheet? masterSheet;
            excel_pkg.Sheet? firstSheet;

            for (var name in sheetNames) {
              final s = excel.tables[name];
              if (s == null || s.rows.isEmpty) continue;
              firstSheet ??= s;

              final lower = name.toLowerCase();
              if (lower.contains('physical') || lower.contains('count sheet') || lower.contains('audit')) {
                physicalSheet = s;
              } else if (lower.contains('masterlist') || lower.contains('template') || lower.contains('inventory') || lower.contains('stock')) {
                masterSheet = s;
              }
            }

            // Check if physicalSheet actually has numbers in its Physical Count column (column 4):
            bool physicalSheetHasEnteredCounts = false;
            if (physicalSheet != null) {
              for (int r = 1; r < physicalSheet.rows.length; r++) {
                final row = physicalSheet.rows[r];
                if (row.length > 4) {
                  final val = row[4]?.value?.toString().trim() ?? '';
                  if (val.isNotEmpty && RegExp(r'[0-9]').hasMatch(val)) {
                    physicalSheetHasEnteredCounts = true;
                    break;
                  }
                }
              }
            }

            if (physicalSheet != null && physicalSheetHasEnteredCounts) {
              targetSheet = physicalSheet;
            } else if (masterSheet != null) {
              targetSheet = masterSheet;
            } else if (physicalSheet != null) {
              targetSheet = physicalSheet;
            } else {
              targetSheet = firstSheet;
            }

            if (targetSheet != null) {
              for (var row in targetSheet.rows) {
                final rowValues = row.map((cell) => cell?.value?.toString() ?? '').toList();
                if (rowValues.any((c) => c.trim().isNotEmpty)) {
                  rawRows.add(rowValues);
                }
              }
            }
          }
        } catch (err) {
          debugPrint('Error decoding Excel file: $err');
        }
      } else {
        final csvString = utf8.decode(file.bytes!);
        rawRows = csv_pkg.CsvCodec().decode(csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
      }

      if (rawRows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The selected file has no readable data rows.'),
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
      int physicalCountCol = -1;
      int stockQtyCol = -1;
      int systemQtyCol = -1;
      int unitCol = -1;
      int storageCol = -1;
      int supplierCol = -1;

      for (int i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (h == 'item id' || h == 'id' || h == 'item_id' || h == 'itemid' || h.contains('uuid')) {
          idCol = i;
        } else if (h == 'item name' || h == 'name' || h == 'item_name' || h.contains('item name') || h.contains('product name')) {
          nameCol = i;
        } else if (h.contains('category') || h == 'cat') {
          catCol = i;
        } else if (h.contains('status') ||
            h.contains('capacity') ||
            h.contains('%') ||
            h.contains('percent') ||
            h.contains('progress') ||
            h.contains('variance') ||
            h.contains('diff') ||
            h.contains('remark') ||
            h.contains('note') ||
            h == '#' ||
            h == 'no' ||
            h == 'num') {
          // Explicitly skip status, capacity %, progress, notes, and variance columns
          continue;
        } else if (h == 'physical count' ||
            h == 'physical_count' ||
            h == 'actual count' ||
            h == 'actual_count' ||
            h == 'phys count' ||
            h == 'phys_count' ||
            h == 'physical stock' ||
            h == 'counted' ||
            h == 'physical' ||
            h == 'actual') {
          physicalCountCol = i;
        } else if (h == 'system qty' ||
            h == 'sys qty' ||
            h == 'system stock' ||
            h == 'sys stock' ||
            h == 'system quantity' ||
            h == 'sys quantity') {
          systemQtyCol = i;
        } else if (h == 'quantity' ||
            h == 'qty' ||
            h == 'stock quantity' ||
            h == 'stock qty' ||
            h == 'stock' ||
            h == 'count' ||
            h.contains('quantity') ||
            h.contains('qty')) {
          stockQtyCol = i;
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
              content: Text('Invalid CSV/Excel format: Missing "Item Name" column.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
        return;
      }

      // Check if physicalCountCol actually contains any filled numeric values in the data rows:
      bool physicalColHasValues = false;
      if (physicalCountCol != -1) {
        for (int i = headerRowIndex + 1; i < rawRows.length; i++) {
          if (physicalCountCol < rawRows[i].length) {
            final val = rawRows[i][physicalCountCol].toString().trim();
            if (val.isNotEmpty && RegExp(r'[0-9]').hasMatch(val)) {
              physicalColHasValues = true;
              break;
            }
          }
        }
      }

      // Choose which column represents physical / uploaded quantity:
      // If physicalCountCol has actual counts entered by user, use it!
      // Otherwise, fall back to stockQtyCol or systemQtyCol so it reads the actual quantities.
      final int qtyCol = (physicalCountCol != -1 && physicalColHasValues)
          ? physicalCountCol
          : (stockQtyCol != -1 ? stockQtyCol : (systemQtyCol != -1 ? systemQtyCol : physicalCountCol));

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

      List<Map<String, dynamic>> auditRows = [];

      for (int i = headerRowIndex + 1; i < rawRows.length; i++) {
        final row = rawRows[i];
        if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) continue;

        final rawId = (idCol >= 0 && idCol < row.length) ? row[idCol].toString().trim() : '';
        final rawName = (nameCol >= 0 && nameCol < row.length) ? row[nameCol].toString().trim() : '';
        if (rawName.isEmpty && rawId.isEmpty) continue;

        final lowerName = rawName.toLowerCase();
        final firstCol = row[0].toString().trim().toLowerCase();

        // Skip category banners, repeated titles, and sheet headers
        if (rawName.startsWith('📦') ||
            rawName.contains('—') ||
            lowerName.contains('palace restaurant') ||
            lowerName.contains('physical inventory count') ||
            lowerName.contains('count sheet') ||
            lowerName == 'item name' ||
            lowerName == 'name') {
          continue;
        }

        // Skip summary / TOTAL rows
        if (lowerName == 'total' ||
            lowerName.startsWith('total ') ||
            lowerName.contains('items listed') ||
            lowerName.contains('grand total') ||
            lowerName.contains('category total') ||
            lowerName.contains('subtotal') ||
            firstCol == 'total' ||
            firstCol.startsWith('total ') ||
            firstCol == 'subtotal') {
          continue;
        }

        final rawCat = (catCol >= 0 && catCol < row.length) ? row[catCol].toString().trim() : '';
        String rawQtyStr = (qtyCol >= 0 && qtyCol < row.length) ? row[qtyCol].toString().trim() : '';
        final rawUnit = (unitCol >= 0 && unitCol < row.length) ? row[unitCol].toString().trim() : 'pcs';
        final rawStorage = (storageCol >= 0 && storageCol < row.length) ? row[storageCol].toString().trim() : 'Dry Storage';
        final rawSupplier = (supplierCol >= 0 && supplierCol < row.length) ? row[supplierCol].toString().trim() : '';

        // If physical counts were entered for the sheet, but this row was left blank, skip uncounted row
        if (physicalColHasValues && rawQtyStr.isEmpty) {
          continue;
        }

        // If rawQtyStr is empty and we have a system quantity fallback, use it
        if (rawQtyStr.isEmpty && systemQtyCol != -1 && systemQtyCol < row.length) {
          rawQtyStr = row[systemQtyCol].toString().trim();
        }
        if (rawQtyStr.isEmpty && stockQtyCol != -1 && stockQtyCol < row.length) {
          rawQtyStr = row[stockQtyCol].toString().trim();
        }

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
        final sysQty = (existing != null) ? ((existing['quantity'] as num?)?.toInt() ?? 0) : 0;

        // Clean and parse quantity (supports decimals e.g. 12.5 -> rounded)
        final cleanNumStr = rawQtyStr.replaceAll(RegExp(r'[^0-9.]'), '');
        final parsedDouble = double.tryParse(cleanNumStr);
        final parsedQty = parsedDouble?.round();

        if (parsedQty == null || parsedQty < 0) {
          auditRows.add({
            'status': 'error',
            'name': finalItemName,
            'category': rawCat.isEmpty ? (existing?['category'] ?? 'Groceries') : rawCat,
            'systemStock': sysQty,
            'physicalCount': 0,
            'variance': 0,
            'unit': rawUnit,
            'storage_room': rawStorage,
            'supplier': rawSupplier,
            'error': 'Invalid quantity format: "$rawQtyStr"',
            'existingId': existing?['id'],
          });
        } else if (existing != null) {
          final variance = parsedQty - sysQty;
          String status = 'balanced';
          if (variance < 0) {
            status = 'shortage';
          } else if (variance > 0) {
            status = 'surplus';
          }

          auditRows.add({
            'status': status,
            'name': finalItemName,
            'category': rawCat.isNotEmpty ? rawCat : (existing['category'] ?? 'Groceries'),
            'systemStock': sysQty,
            'physicalCount': parsedQty,
            'variance': variance,
            'unit': rawUnit.isNotEmpty ? rawUnit : (existing['unit'] ?? 'pcs'),
            'storage_room': rawStorage.isNotEmpty ? rawStorage : (existing['storage_room'] ?? 'Dry Storage'),
            'supplier': rawSupplier.isNotEmpty ? rawSupplier : (existing['supplier'] ?? ''),
            'existingId': existing['id'],
          });
        } else {
          auditRows.add({
            'status': 'new',
            'name': finalItemName,
            'category': rawCat.isNotEmpty ? rawCat : 'Groceries',
            'systemStock': 0,
            'physicalCount': parsedQty,
            'variance': parsedQty,
            'unit': rawUnit.isNotEmpty ? rawUnit : 'pcs',
            'storage_room': rawStorage.isNotEmpty ? rawStorage : 'Dry Storage',
            'supplier': rawSupplier,
            'existingId': null,
          });
        }
      }

      if (auditRows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid inventory rows found in the selected file.'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
        return;
      }

      // Log audit check activity to audit log service (read-only audit activity)
      try {
        await AuditLogService.logActivity(
          action: 'AUDIT_CHECK',
          module: 'Inventory',
          description: 'Checked physical inventory CSV (${file.name}) with ${auditRows.length} items. Database unchanged.',
          metadata: {
            'file_name': file.name,
            'total_items': auditRows.length,
          },
        );
      } catch (_) {}

      if (!mounted) return;
      _showStockAuditVarianceDialog(auditRows, file.name);
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

  void _showStockAuditVarianceDialog(
    List<Map<String, dynamic>> auditRows,
    String fileName,
  ) {
    String filterTab = 'all'; // 'all', 'discrepancy', 'shortage', 'surplus', 'balanced'
    String searchQuery = '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final shortageCount = auditRows.where((r) => r['status'] == 'shortage').length;
          final surplusCount = auditRows.where((r) => r['status'] == 'surplus').length;
          final balancedCount = auditRows.where((r) => r['status'] == 'balanced').length;
          final newCount = auditRows.where((r) => r['status'] == 'new').length;
          final errorCount = auditRows.where((r) => r['status'] == 'error').length;
          final discrepancyCount = shortageCount + surplusCount;

          final filteredRows = auditRows.where((row) {
            final name = (row['name'] ?? '').toString().toLowerCase();
            final category = (row['category'] ?? '').toString().toLowerCase();
            final status = row['status'];

            final matchesSearch = searchQuery.isEmpty ||
                name.contains(searchQuery.toLowerCase()) ||
                category.contains(searchQuery.toLowerCase());

            if (!matchesSearch) return false;

            if (filterTab == 'discrepancy') {
              return status == 'shortage' || status == 'surplus';
            } else if (filterTab == 'shortage') {
              return status == 'shortage';
            } else if (filterTab == 'surplus') {
              return status == 'surplus';
            } else if (filterTab == 'balanced') {
              return status == 'balanced';
            } else if (filterTab == 'new') {
              return status == 'new';
            } else if (filterTab == 'error') {
              return status == 'error';
            }
            return true;
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            elevation: 16,
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.isMobile(context) ? double.infinity : 820,
                maxHeight: ResponsiveUtils.isMobile(context)
                    ? MediaQuery.of(context).size.height * 0.92
                    : 720,
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
                          Icons.fact_check_rounded,
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
                              'Physical Stock Audit & Variance Report',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'File: $fileName • Read-only comparison (Live stocks remain untouched)',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                  const SizedBox(height: 12),

                  // Safe Mode Alert Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Color(0xFF059669), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Safe Audit Mode: Comparing physical counts against system records. Your inventory will NOT be modified.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Metrics Summary Banner
                  Row(
                    children: [
                      _buildAuditStatCard(
                        label: 'Total Checked',
                        count: auditRows.length.toString(),
                        color: const Color(0xFF14332E),
                        icon: Icons.inventory_2_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildAuditStatCard(
                        label: 'Shortage (Lacking)',
                        count: shortageCount.toString(),
                        color: const Color(0xFFDC2626),
                        icon: Icons.trending_down_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildAuditStatCard(
                        label: 'Surplus (Over)',
                        count: surplusCount.toString(),
                        color: const Color(0xFFD97706),
                        icon: Icons.trending_up_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildAuditStatCard(
                        label: 'Balanced (Match)',
                        count: balancedCount.toString(),
                        color: const Color(0xFF16A34A),
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      if (newCount > 0) ...[
                        const SizedBox(width: 8),
                        _buildAuditStatCard(
                          label: 'New Items',
                          count: newCount.toString(),
                          color: const Color(0xFF2563EB),
                          icon: Icons.add_circle_outline_rounded,
                        ),
                      ],
                      if (errorCount > 0) ...[
                        const SizedBox(width: 8),
                        _buildAuditStatCard(
                          label: 'Format Errors',
                          count: errorCount.toString(),
                          color: const Color(0xFF9333EA),
                          icon: Icons.error_outline_rounded,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips & Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildFilterChip('All Items (${auditRows.length})', 'all', filterTab, (val) {
                                setDialogState(() => filterTab = val);
                              }),
                              const SizedBox(width: 6),
                              _buildFilterChip('Discrepancies ($discrepancyCount)', 'discrepancy', filterTab, (val) {
                                setDialogState(() => filterTab = val);
                              }, badgeColor: discrepancyCount > 0 ? const Color(0xFFEF4444) : null),
                              const SizedBox(width: 6),
                              _buildFilterChip('Shortages ($shortageCount)', 'shortage', filterTab, (val) {
                                setDialogState(() => filterTab = val);
                              }),
                              const SizedBox(width: 6),
                              _buildFilterChip('Surpluses ($surplusCount)', 'surplus', filterTab, (val) {
                                setDialogState(() => filterTab = val);
                              }),
                              const SizedBox(width: 6),
                              _buildFilterChip('Balanced ($balancedCount)', 'balanced', filterTab, (val) {
                                setDialogState(() => filterTab = val);
                              }),
                              if (newCount > 0) ...[
                                const SizedBox(width: 6),
                                _buildFilterChip('New ($newCount)', 'new', filterTab, (val) {
                                  setDialogState(() => filterTab = val);
                                }),
                              ],
                              if (errorCount > 0) ...[
                                const SizedBox(width: 6),
                                _buildFilterChip('Errors ($errorCount)', 'error', filterTab, (val) {
                                  setDialogState(() => filterTab = val);
                                }, badgeColor: const Color(0xFF9333EA)),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 170,
                        height: 34,
                        child: TextField(
                          onChanged: (val) => setDialogState(() => searchQuery = val),
                          style: const TextStyle(fontSize: 11),
                          decoration: InputDecoration(
                            hintText: 'Search items...',
                            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 14, color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Table Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            'STATUS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'ITEM / SPECIFICATIONS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                        ),
                        SizedBox(
                          width: 85,
                          child: Text(
                            'SYSTEM STOCK',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            'PHYSICAL COUNT',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            'VARIANCE / DIFF',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Audit Rows List
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: filteredRows.isEmpty
                          ? const Center(
                              child: Text(
                                'No items found matching the selected filter.',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: filteredRows.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black),
                                itemBuilder: (context, idx) {
                                  final row = filteredRows[idx];
                                  final status = row['status'];
                                  final variance = (row['variance'] as num?)?.toInt() ?? 0;
                                  final sysQty = (row['systemStock'] as num?)?.toInt() ?? 0;
                                  final physQty = (row['physicalCount'] as num?)?.toInt() ?? 0;
                                  final unit = row['unit'] ?? 'pcs';

                                  Color badgeBg;
                                  Color badgeFg;
                                  String badgeText;

                                  if (status == 'shortage') {
                                    badgeBg = const Color(0xFFFEE2E2);
                                    badgeFg = const Color(0xFFDC2626);
                                    badgeText = 'SHORTAGE';
                                  } else if (status == 'surplus') {
                                    badgeBg = const Color(0xFFFEF3C7);
                                    badgeFg = const Color(0xFFD97706);
                                    badgeText = 'SURPLUS';
                                  } else if (status == 'balanced') {
                                    badgeBg = const Color(0xFFDCFCE7);
                                    badgeFg = const Color(0xFF16A34A);
                                    badgeText = 'MATCHED';
                                  } else if (status == 'new') {
                                    badgeBg = const Color(0xFFDBEAFE);
                                    badgeFg = const Color(0xFF2563EB);
                                    badgeText = 'NEW ITEM';
                                  } else {
                                    badgeBg = const Color(0xFFF1F5F9);
                                    badgeFg = const Color(0xFF64748B);
                                    badgeText = 'ERROR';
                                  }

                                  return Container(
                                    color: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    child: Row(
                                      children: [
                                        // Status badge
                                        SizedBox(
                                          width: 80,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: badgeBg,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.black, width: 0.8),
                                              ),
                                              child: Text(
                                                badgeText,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: badgeFg,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Name and specifications
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                row['name'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '${row['category']} • ${row['storage_room']}${row['supplier'] != null && row['supplier'].toString().isNotEmpty ? ' • ${row['supplier']}' : ''}',
                                                style: const TextStyle(fontSize: 10, color: Colors.black87),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // System Stock
                                        SizedBox(
                                          width: 85,
                                          child: Text(
                                            '$sysQty $unit',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        // Physical Count
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            '$physQty $unit',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        // Variance Display
                                        SizedBox(
                                          width: 110,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: variance < 0
                                                    ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                                                    : variance > 0
                                                        ? const Color(0xFFD97706).withValues(alpha: 0.1)
                                                        : const Color(0xFF16A34A).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.black, width: 0.8),
                                              ),
                                              child: Text(
                                                variance < 0
                                                    ? '$variance $unit'
                                                    : variance > 0
                                                        ? '+$variance $unit'
                                                        : '0 (Balanced)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: variance < 0
                                                      ? const Color(0xFFDC2626)
                                                      : variance > 0
                                                          ? const Color(0xFFD97706)
                                                          : const Color(0xFF16A34A),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Actions: Download PDF, Print PDF, Export Excel, Close
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Download Excel Variance Button
                      OutlinedButton.icon(
                        onPressed: () => _exportVarianceToExcel(auditRows, fileName),
                        icon: const Icon(Icons.table_chart_rounded, size: 16),
                        label: const Text('Export Variance (Excel)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D9488),
                          side: const BorderSide(color: Color(0xFF0D9488)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),

                      // Download Variance PDF Button (Direct Download)
                      ElevatedButton.icon(
                        onPressed: () => _downloadVarianceReportPdf(auditRows, fileName),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('Download Variance (PDF)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),

                      // Print Variance PDF Button
                      OutlinedButton.icon(
                        onPressed: () => _printVarianceReportPdf(auditRows, fileName),
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF14332E),
                          side: const BorderSide(color: Color(0xFF14332E)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),

                      // Close Button
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          foregroundColor: const Color(0xFF64748B),
                        ),
                        child: const Text('Close Audit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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

  Widget _buildAuditStatCard({
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
            const SizedBox(width: 6),
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
                  style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentVal,
    ValueChanged<String> onSelected, {
    Color? badgeColor,
  }) {
    final isSelected = currentVal == value;
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (badgeColor ?? const Color(0xFF14332E))
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? (badgeColor ?? const Color(0xFF14332E)) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Future<void> _exportVarianceToExcel(
    List<Map<String, dynamic>> auditRows,
    String sourceFile,
  ) async {
    try {
      final excel = excel_pkg.Excel.createExcel();
      excel.delete('Sheet1');

      final headerStyle = excel_pkg.CellStyle(
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#14332E'),
        horizontalAlign: excel_pkg.HorizontalAlign.Left,
        bold: true,
      );

      final titleStyle = excel_pkg.CellStyle(
        fontSize: 13,
        bold: true,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#14332E'),
      );

      final subTitleStyle = excel_pkg.CellStyle(
        fontSize: 10,
        bold: true,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#475569'),
      );

      final totalRowStyle = excel_pkg.CellStyle(
        bold: true,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#0F172A'),
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E2E8F0'),
      );

      final shortageStyle = excel_pkg.CellStyle(
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#DC2626'),
        bold: true,
      );

      final surplusStyle = excel_pkg.CellStyle(
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#D97706'),
        bold: true,
      );

      final balancedStyle = excel_pkg.CellStyle(
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#16A34A'),
        bold: true,
      );

      void appendRow(excel_pkg.Sheet sheet, List<excel_pkg.CellValue?> rowValues, {excel_pkg.CellStyle? style}) {
        sheet.appendRow(rowValues);
        if (style != null) {
          final rIndex = sheet.maxRows - 1;
          for (var c = 0; c < rowValues.length; c++) {
            final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rIndex));
            cell.cellStyle = style;
          }
        }
      }

      final sheet = excel['Stock Variance Report'];
      sheet.setColumnWidth(0, 6.0);   // #
      sheet.setColumnWidth(1, 28.0);  // Item Name
      sheet.setColumnWidth(2, 16.0);  // Category
      sheet.setColumnWidth(3, 20.0);  // Storage Room
      sheet.setColumnWidth(4, 10.0);  // Unit
      sheet.setColumnWidth(5, 14.0);  // System Stock
      sheet.setColumnWidth(6, 14.0);  // Physical Count
      sheet.setColumnWidth(7, 14.0);  // Variance
      sheet.setColumnWidth(8, 16.0);  // Audit Status
      sheet.setColumnWidth(9, 24.0);  // Supplier
      sheet.setColumnWidth(10, 30.0); // Notes / Remarks

      appendRow(sheet, [excel_pkg.TextCellValue('YANG CHOW PALACE RESTAURANT - PHYSICAL STOCK AUDIT & VARIANCE REPORT')], style: titleStyle);
      appendRow(sheet, [
        excel_pkg.TextCellValue(
          'Audit Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} • Source File: $sourceFile • Total Evaluated: ${auditRows.length} Items',
        ),
      ], style: subTitleStyle);
      sheet.appendRow([excel_pkg.TextCellValue('')]);

      appendRow(sheet, [
        excel_pkg.TextCellValue('#'),
        excel_pkg.TextCellValue('Item Name'),
        excel_pkg.TextCellValue('Category'),
        excel_pkg.TextCellValue('Storage Location'),
        excel_pkg.TextCellValue('Unit'),
        excel_pkg.TextCellValue('System Stock'),
        excel_pkg.TextCellValue('Physical Count'),
        excel_pkg.TextCellValue('Variance (Diff)'),
        excel_pkg.TextCellValue('Audit Status'),
        excel_pkg.TextCellValue('Supplier'),
        excel_pkg.TextCellValue('Audit Notes / Remarks'),
      ], style: headerStyle);

      int shortageCount = 0;
      int surplusCount = 0;
      int balancedCount = 0;

      for (int i = 0; i < auditRows.length; i++) {
        final row = auditRows[i];
        final variance = (row['variance'] as num?)?.toInt() ?? 0;
        final status = (row['status'] ?? '').toString().toUpperCase();
        final unit = (row['unit'] ?? '').toString();

        if (status == 'SHORTAGE') shortageCount++;
        if (status == 'SURPLUS') surplusCount++;
        if (status == 'BALANCED') balancedCount++;

        final remarks = status == 'SHORTAGE'
            ? 'Lacking by ${variance.abs()} $unit'
            : status == 'SURPLUS'
                ? 'Surplus by $variance $unit'
                : 'Balanced';

        appendRow(sheet, [
          excel_pkg.IntCellValue(i + 1),
          excel_pkg.TextCellValue(row['name']?.toString() ?? ''),
          excel_pkg.TextCellValue(row['category']?.toString() ?? ''),
          excel_pkg.TextCellValue(row['storage_room']?.toString() ?? ''),
          excel_pkg.TextCellValue(unit),
          excel_pkg.IntCellValue((row['systemStock'] as num?)?.toInt() ?? 0),
          excel_pkg.IntCellValue((row['physicalCount'] as num?)?.toInt() ?? 0),
          excel_pkg.TextCellValue(variance > 0 ? '+$variance' : variance.toString()),
          excel_pkg.TextCellValue(status),
          excel_pkg.TextCellValue(row['supplier']?.toString() ?? ''),
          excel_pkg.TextCellValue(remarks),
        ]);

        final rowIndex = sheet.maxRows - 1;
        final statusCell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex));
        if (status == 'SHORTAGE') statusCell.cellStyle = shortageStyle;
        if (status == 'SURPLUS') statusCell.cellStyle = surplusStyle;
        if (status == 'BALANCED') statusCell.cellStyle = balancedStyle;
      }

      // Summary row
      appendRow(sheet, [
        excel_pkg.TextCellValue('TOTAL'),
        excel_pkg.TextCellValue('${auditRows.length} Items Evaluated'),
        excel_pkg.TextCellValue('-'),
        excel_pkg.TextCellValue('-'),
        excel_pkg.TextCellValue('-'),
        excel_pkg.TextCellValue('-'),
        excel_pkg.TextCellValue('-'),
        excel_pkg.TextCellValue('Shortages: $shortageCount | Surplus: $surplusCount | Balanced: $balancedCount'),
        excel_pkg.TextCellValue('-'),
        excel_pkg.TextCellValue('-'),
        excel_pkg.TextCellValue('-'),
      ], style: totalRowStyle);

      final excelBytes = excel.save();
      if (excelBytes == null) throw Exception('Excel encoding failed');
      final Uint8List bytes = Uint8List.fromList(excelBytes);

      final fileName = 'yangchow_stock_variance_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

      await _saveAndDownloadExcel(
        bytes: bytes,
        fileName: fileName,
        successMessage: 'Exported Variance Report for ${auditRows.length} items to Excel!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export variance Excel: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  pw.Document _generateVarianceReportPdfDoc(
    List<Map<String, dynamic>> auditRows,
    String sourceFile,
  ) {
    final doc = pw.Document();
    final nowStr = DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now());

    final shortageCount = auditRows.where((r) => r['status'] == 'shortage').length;
    final surplusCount = auditRows.where((r) => r['status'] == 'surplus').length;
    final balancedCount = auditRows.where((r) => r['status'] == 'balanced').length;

    const itemsPerPage = 20;
    final totalPages = (auditRows.length / itemsPerPage).ceil();

    for (int pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final start = pageIdx * itemsPerPage;
      final end = (start + itemsPerPage < auditRows.length) ? start + itemsPerPage : auditRows.length;
      final pageItems = auditRows.sublist(start, end);
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
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal900,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'PHYSICAL INVENTORY AUDIT & VARIANCE REPORT',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey900,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Source File: $sourceFile  |  Total Items: ${auditRows.length}  |  Shortages: $shortageCount  |  Surpluses: $surplusCount  |  Balanced: $balancedCount',
                          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
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
                    0: const pw.FixedColumnWidth(22), // #
                    1: const pw.FlexColumnWidth(2.8), // Item Name
                    2: const pw.FlexColumnWidth(1.5), // Category
                    3: const pw.FlexColumnWidth(1.6), // Location
                    4: const pw.FixedColumnWidth(38), // Unit
                    5: const pw.FixedColumnWidth(48), // Sys Stock
                    6: const pw.FixedColumnWidth(52), // Physical
                    7: const pw.FixedColumnWidth(50), // Variance
                    8: const pw.FlexColumnWidth(1.8), // Status/Remarks
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
                        _buildPdfHeaderCell('Phys Count'),
                        _buildPdfHeaderCell('Variance'),
                        _buildPdfHeaderCell('Status / Remarks'),
                      ],
                    ),
                    // Table Rows
                    ...pageItems.asMap().entries.map((entry) {
                      final index = start + entry.key + 1;
                      final item = entry.value;
                      final isEven = entry.key % 2 == 0;
                      final variance = (item['variance'] as num?)?.toInt() ?? 0;
                      final status = item['status'];

                      PdfColor statusColor = PdfColors.black;
                      String statusDesc = 'Matched';
                      if (status == 'shortage') {
                        statusColor = PdfColors.red800;
                        statusDesc = 'Shortage (${variance.abs()})';
                      } else if (status == 'surplus') {
                        statusColor = PdfColors.amber800;
                        statusDesc = 'Surplus (+$variance)';
                      } else if (status == 'new') {
                        statusColor = PdfColors.blue800;
                        statusDesc = 'New Item';
                      }

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: status == 'shortage'
                              ? PdfColors.red50
                              : status == 'surplus'
                                  ? PdfColors.amber50
                                  : (isEven ? PdfColors.white : PdfColors.grey100),
                        ),
                        children: [
                          _buildPdfCell(index.toString(), align: pw.TextAlign.center),
                          _buildPdfCell(item['name']?.toString() ?? '', isBold: true),
                          _buildPdfCell(item['category']?.toString() ?? ''),
                          _buildPdfCell(item['storage_room']?.toString() ?? 'Dry Storage'),
                          _buildPdfCell(item['unit']?.toString() ?? 'pcs', align: pw.TextAlign.center),
                          _buildPdfCell(item['systemStock']?.toString() ?? '0', align: pw.TextAlign.center),
                          _buildPdfCell(item['physicalCount']?.toString() ?? '0', align: pw.TextAlign.center, isBold: true),
                          _buildPdfCell(
                            variance > 0 ? '+$variance' : variance.toString(),
                            align: pw.TextAlign.center,
                            isBold: true,
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: pw.Text(
                              statusDesc,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                pw.Spacer(),

                // Signatures Footer only on last page
                if (isLastPage) ...[
                  pw.SizedBox(height: 10),
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
                          pw.Text('Variance Audited & Reviewed By:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 18),
                          pw.Container(width: 180, height: 0.5, color: PdfColors.black),
                          pw.SizedBox(height: 2),
                          pw.Text('Inventory Manager / Admin Signature / Date', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
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
    return doc;
  }

  Future<void> _downloadVarianceReportPdf(
    List<Map<String, dynamic>> auditRows,
    String sourceFile,
  ) async {
    try {
      final doc = _generateVarianceReportPdfDoc(auditRows, sourceFile);
      final pdfBytes = await doc.save();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'yangchow_stock_variance_report_$dateStr';

      await _saveAndDownloadPdf(
        bytes: pdfBytes,
        fileName: fileName,
        successMessage: 'Stock Variance Report PDF downloaded successfully!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Variance PDF download failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _printVarianceReportPdf(
    List<Map<String, dynamic>> auditRows,
    String sourceFile,
  ) async {
    try {
      final doc = _generateVarianceReportPdfDoc(auditRows, sourceFile);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'yangchow_stock_variance_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Variance print failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
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
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.isMobile(context) ? 10 : 14,
              vertical: ResponsiveUtils.isMobile(context) ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 6 : 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: ResponsiveUtils.isMobile(context) ? 15 : 17,
                  ),
                ),
                SizedBox(width: ResponsiveUtils.isMobile(context) ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            count,
                            style: TextStyle(
                              fontSize: ResponsiveUtils.isMobile(context) ? 15 : 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.isMobile(context) ? 7 : 8,
                                  fontWeight: FontWeight.w700,
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
                          fontSize: ResponsiveUtils.isMobile(context) ? 9.5 : 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.65),
                          letterSpacing: 0.2,
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
    final categoryIcon = _getCategoryIcon(category);
    final unit = (item['unit']?.toString() ?? 'pcs').trim();
    final storageRoom = item['storage_room']?.toString();
    final supplier = item['supplier']?.toString();
    final itemName = item['name']?.toString() ?? 'Unknown';

    // Header Background: Dark Enterprise Green, matching Kitchen Requests KDS header
    const Color headerBg = _invPrimary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _invBorder,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KDS DOCKET HEADER BAR (36px, comfortable typography) ──
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                color: headerBg,
              ),
              child: Row(
                children: [
                  // Category Badge with icon
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(categoryIcon, size: 10.5, color: Colors.white.withValues(alpha: 0.85)),
                        const SizedBox(width: 4),
                        Text(
                          category.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Stock Status Badge (Refined translucent status chip)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: (quantity == 0
                              ? const Color(0xFFF87171)
                              : (quantity < 10
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFF4ADE80)))
                          .withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStockStatusIcon(quantity),
                          size: 10,
                          color: quantity == 0
                              ? const Color(0xFFF87171)
                              : (quantity < 10
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFF4ADE80)),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stockStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.95),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_canEdit) ...[
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 17,
                        color: Colors.white.withValues(alpha: 0.85),
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
                                    color: _invDanger,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete Item',
                                    style: TextStyle(
                                      color: _invTextPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              content: Text(
                                'Are you sure you want to delete "${item['name']}"?',
                                style: const TextStyle(color: _invTextSecondary),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: _invTextTertiary),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _invDanger,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
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
                              Icon(Icons.edit_rounded, size: 16, color: _invTextSecondary),
                              SizedBox(width: 8),
                              Text('Edit Item', style: TextStyle(fontSize: 13, color: _invTextPrimary)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 16, color: _invDanger),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(fontSize: 13, color: _invDanger)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── COMFORTABLE BODY (SPACIOUS, GENEROUS BREATHING ROOM) ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Row 1: Item Identity + Hero Stock Quantity Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7.5),
                          decoration: BoxDecoration(
                            color: _invSurfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _invBorder, width: 1.0),
                          ),
                          child: Icon(categoryIcon, size: 16, color: _invTextTertiary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                itemName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: _invTextPrimary,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                storageRoom != null && storageRoom.isNotEmpty
                                    ? storageRoom
                                    : (supplier != null && supplier.isNotEmpty ? supplier : 'Main Storage'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _invTextTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Hero Stock Quantity Badge (Matching Enterprise Dispatch Badge)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: _invPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '$quantity ',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                TextSpan(
                                  text: unit.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Row 2: Stock Capacity Meter
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Stock Capacity',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _invTextTertiary,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _invTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Stack(
                            children: [
                              Container(
                                height: 6,
                                width: double.infinity,
                                color: _invBorder,
                              ),
                              FractionallySizedBox(
                                widthFactor: progress.clamp(0.02, 1.0),
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: stockColor,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Row 3: Footer Bar (Storage / Location Details with Quick Edit)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: _invSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _invBorder, width: 1.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            storageRoom != null && storageRoom.isNotEmpty
                                ? Icons.location_on_outlined
                                : Icons.inventory_2_outlined,
                            size: 13,
                            color: _invTextMuted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              storageRoom != null && storageRoom.isNotEmpty
                                  ? 'Location: $storageRoom'
                                  : (supplier != null && supplier.isNotEmpty ? 'Supplier: $supplier' : 'Standard Inventory'),
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: _invTextSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_canEdit) ...[
                            InkWell(
                              onTap: () => _addOrEditItem(item: item),
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: _invBorderStrong, width: 1.0),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded, size: 10, color: _invTextSecondary),
                                    SizedBox(width: 3),
                                    Text(
                                      'EDIT',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: _invTextSecondary,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
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
            // Top: Real-time Command Center / Inventory Monitoring Banner (Collapsible)
            GestureDetector(
              onTap: () => setState(() => _isBannerCollapsed = !_isBannerCollapsed),
              child: Container(
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
                    // Banner Header (always visible, acts as toggle)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.analytics_rounded,
                            color: Colors.white,
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
                                  height: 1.15,
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                        if (_selectedStockStatus != null && !_isBannerCollapsed) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: (){ setState(() => _selectedStockStatus = null); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.filter_alt_off_rounded, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Reset Filter',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        // Collapse / expand chevron
                        AnimatedRotation(
                          turns: _isBannerCollapsed ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 220),
                          child: Icon(
                            Icons.expand_less_rounded,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 22,
                          ),
                        ),
                      ],
                    ),

                    // Collapsible stats section
                    AnimatedCrossFade(
                      firstChild: Column(
                        children: [
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
                                        color: Colors.white,
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
                                          accentColor: const Color(0xFFF87171),
                                          icon: Icons.cancel_rounded,
                                          subtitle: 'Immediate action',
                                        ),
                                        const SizedBox(width: 8),
                                        _buildRealisticStatCard(
                                          label: 'LOW STOCK',
                                          count: lowStock.toString(),
                                          statusKey: 'LOW STOCK',
                                          accentColor: const Color(0xFFFBBF24),
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
                                          accentColor: const Color(0xFF4ADE80),
                                          icon: Icons.check_circle_rounded,
                                          subtitle: 'Healthy stock',
                                        ),
                                        const SizedBox(width: 8),
                                        _buildRealisticStatCard(
                                          label: 'HIGH STOCK',
                                          count: highStock.toString(),
                                          statusKey: 'HIGH STOCK',
                                          accentColor: const Color(0xFF2DD4BF),
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
                                    accentColor: const Color(0xFFF87171),
                                    icon: Icons.cancel_rounded,
                                    subtitle: '0 items left',
                                  ),
                                  const SizedBox(width: 10),
                                  _buildRealisticStatCard(
                                    label: 'LOW STOCK',
                                    count: lowStock.toString(),
                                    statusKey: 'LOW STOCK',
                                    accentColor: const Color(0xFFFBBF24),
                                    icon: Icons.warning_amber_rounded,
                                    subtitle: '1-9 remaining',
                                  ),
                                  const SizedBox(width: 10),
                                  _buildRealisticStatCard(
                                    label: 'NORMAL STOCK',
                                    count: normalStock.toString(),
                                    statusKey: 'NORMAL',
                                    accentColor: const Color(0xFF4ADE80),
                                    icon: Icons.check_circle_rounded,
                                    subtitle: '10-49 units',
                                  ),
                                  const SizedBox(width: 10),
                                  _buildRealisticStatCard(
                                    label: 'HIGH STOCK',
                                    count: highStock.toString(),
                                    statusKey: 'HIGH STOCK',
                                    accentColor: const Color(0xFF2DD4BF),
                                    icon: Icons.verified_rounded,
                                    subtitle: '50+ units',
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      secondChild: const SizedBox.shrink(),
                      crossFadeState: _isBannerCollapsed
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 220),
                    ),
                  ],
                ),
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
                  color: _invBorder,
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
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
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: _invTextPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search items by name or category...',
                            hintStyle: const TextStyle(color: _invTextMuted, fontSize: 12.5),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: _invTextTertiary,
                              size: 18,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: _invTextTertiary, size: 16),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _invBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _invBorder),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                              borderSide: BorderSide(color: _invPrimary, width: 1.5),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      if (widget.showImportExport) ...[
                        const SizedBox(width: 8),
                        // Actions dropdown
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'passcode') _showPasscodeManagerDialog();
                            if (value == 'audit') _handleImportCsv();
                            if (value == 'export') _showExportOptionsDialog(items: _currentDisplayedItems);
                          },
                          offset: const Offset(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: _invBorder),
                          ),
                          color: Colors.white,
                          elevation: 6,
                          itemBuilder: (context) => [
                            if (_isPagsanjanInv || !widget.isViewOnly)
                              const PopupMenuItem<String>(
                                value: 'passcode',
                                child: Row(children: [
                                  Icon(Icons.vpn_key_rounded, size: 16, color: _invTextTertiary),
                                  SizedBox(width: 10),
                                  Text('Passcode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _invTextPrimary)),
                                ]),
                              ),
                            const PopupMenuItem<String>(
                              value: 'audit',
                              child: Row(children: [
                                Icon(Icons.fact_check_outlined, size: 16, color: _invTextTertiary),
                                SizedBox(width: 10),
                                Text('Audit (Excel/CSV)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _invTextPrimary)),
                              ]),
                            ),
                            const PopupMenuItem<String>(
                              value: 'export',
                              child: Row(children: [
                                Icon(Icons.print_outlined, size: 16, color: _invTextTertiary),
                                SizedBox(width: 10),
                                Text('Export / Print', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _invTextPrimary)),
                              ]),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _invPrimary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down_rounded, size: 18, color: Colors.white),
                              ],
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
                        final catIcon = _getCategoryIcon(category);

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
                                _selectedStockStatus = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _invPrimary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: isSelected ? _invPrimary : _invBorder,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    catIcon,
                                    size: 13.5,
                                    color: isSelected
                                        ? Colors.white
                                        : _invTextTertiary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : _invTextSecondary,
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
                  final filteredItems = _filterAndSortItems(items);
                  _currentDisplayedItems = filteredItems;

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
                      int crossAxisCount = 3;
                      if (constraints.maxWidth < 640) {
                        crossAxisCount = 1;
                      } else if (constraints.maxWidth < 1050) {
                        crossAxisCount = 2;
                      } else if (constraints.maxWidth < 1500) {
                        crossAxisCount = 3;
                      } else {
                        crossAxisCount = 4;
                      }

                      const double spacing = 16.0;
                      final double totalSpacing = spacing * (crossAxisCount - 1);
                      final double cardWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;
                      final double targetHeight = crossAxisCount == 1 ? 192.0 : 198.0;
                      final double childAspectRatio = cardWidth / targetHeight;

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.isMobile(context) ? 14 : 18,
                          vertical: 12,
                        ),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
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
              backgroundColor: _invPrimary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Item',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            )
          : null,
    );
  }
}
