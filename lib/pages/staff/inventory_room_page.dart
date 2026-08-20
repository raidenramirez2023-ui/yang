import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/delivery_receipt_ocr_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class InventoryRoomPage extends StatefulWidget {
  final List<Map<String, dynamic>>? initialRestockItems;
  final String? initialSupplier;
  final String? initialDrNumber;
  final bool autoOpenIntake;
  final int initialTabIndex;

  const InventoryRoomPage({
    super.key,
    this.initialRestockItems,
    this.initialSupplier,
    this.initialDrNumber,
    this.autoOpenIntake = false,
    this.initialTabIndex = 0,
  });

  static final GlobalKey<_InventoryRoomPageState> globalKey = GlobalKey<_InventoryRoomPageState>();

  static void showDeliveryIntakeDialog(
    BuildContext context, {
    List<Map<String, dynamic>>? initialItems,
    String? initialSupplier,
    String? initialDrNumber,
  }) {
    if (globalKey.currentState != null) {
      globalKey.currentState!._showBulkReplenishDialog(
        initialItems: initialItems,
        initialSupplier: initialSupplier,
        initialDrNumber: initialDrNumber,
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => InventoryRoomPage(
            key: globalKey,
            initialRestockItems: initialItems,
            initialSupplier: initialSupplier,
            initialDrNumber: initialDrNumber,
            autoOpenIntake: true,
          ),
        ),
      );
    }
  }

  static void navigateToIncomingTab(BuildContext context) {
    if (globalKey.currentState != null) {
      globalKey.currentState!.switchToTab(1);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => InventoryRoomPage(
            key: globalKey,
            initialTabIndex: 1,
          ),
        ),
      );
    }
  }

  @override
  State<InventoryRoomPage> createState() => _InventoryRoomPageState();
}

class _InventoryRoomPageState extends State<InventoryRoomPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedStorageRoom = 'All';
  String _incomingSearchQuery = '';
  String _pettyCashSearchQuery = '';
  // ignore: unused_field
  int _incomingCurrentPage = 1;
  // ignore: unused_field
  int _incomingItemsPerPage = 10;
  int _pettyCashCurrentPage = 1;
  int _pettyCashItemsPerPage = 10;
  
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
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    if (widget.autoOpenIntake) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBulkReplenishDialog(
          initialItems: widget.initialRestockItems,
          initialSupplier: widget.initialSupplier,
          initialDrNumber: widget.initialDrNumber,
        );
      });
    }
  }

  void switchToTab(int index) {
    if (index >= 0 && index < _tabController.length) {
      _tabController.animateTo(index);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showBulkReplenishDialog({
    List<Map<String, dynamic>>? initialItems,
    String? initialSupplier,
    String? initialDrNumber,
  }) {
    final receiverCtrl = TextEditingController();
    final supplierCtrl = TextEditingController(
      text: (initialSupplier != null && initialSupplier.isNotEmpty && initialSupplier != 'All')
          ? initialSupplier
          : 'Public Market',
    );
    final drCtrl = TextEditingController(text: initialDrNumber ?? '');
    final searchCtrl = TextEditingController();

    String selectedCategoryFilter = 'All';
    String stockHealthFilter = 'ALL'; // 'ALL', 'OUT', 'LOW', 'OPTIMAL'
    bool showOnlySelected = initialItems != null && initialItems.isNotEmpty;
    bool showOnlyUnlisted = false;

    // In-memory restock quantity map: itemName -> quantity to add
    final Map<String, int> restockQtys = {};
    final Map<String, TextEditingController> qtyControllers = {};
    
    // Support custom extra/unlisted items added via modal/OCR
    final List<Map<String, dynamic>> extraCustomItems = [];

    List<Map<String, dynamic>> allDbItems = [];
    List<String> pastReceivers = [
      'pagsanjaninv@gmail.com',
      'chefycp@gmail.com',
    ];
    List<String> pastSuppliers = [
      'Public Market',
      'Metro Wholesale',
      'Puregold',
      'Local Wet Market',
      'Poultry Supplier',
      'Vegetable Supplier',
      'Direct Distributor',
    ];
    bool fetchedInitial = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!fetchedInitial) {
            fetchedInitial = true;

            final currentEmail = Supabase.instance.client.auth.currentUser?.email;
            if (currentEmail != null && currentEmail.isNotEmpty) {
              if (!pastReceivers.contains(currentEmail)) pastReceivers.insert(0, currentEmail);
              if (receiverCtrl.text.isEmpty) receiverCtrl.text = currentEmail;
            }

            // Fetch past receivers from stock_transactions and kitchen_requests in parallel
            Future.wait([
              Supabase.instance.client.from('stock_transactions').select('processed_by'),
              Supabase.instance.client.from('kitchen_requests').select('requested_by'),
              Supabase.instance.client.from('inventory').select('supplier'),
            ]).then((results) {
              final Set<String> receiversSet = Set.from(pastReceivers);
              final Set<String> suppliersSet = Set.from(pastSuppliers);

              // 1. Processed by
              final txList = results[0] as List;
              for (final r in txList) {
                final p = r['processed_by']?.toString().trim();
                if (p != null && p.isNotEmpty) receiversSet.add(p);
              }

              // 2. Requested by
              final reqList = results[1] as List;
              for (final r in reqList) {
                final q = r['requested_by']?.toString().trim();
                if (q != null && q.isNotEmpty) receiversSet.add(q);
              }

              // 3. Suppliers
              final invList = results[2] as List;
              for (final r in invList) {
                final s = r['supplier']?.toString().trim();
                if (s != null && s.isNotEmpty) suppliersSet.add(s);
              }

              if (context.mounted) {
                setDialogState(() {
                  pastReceivers = receiversSet.toList();
                  pastSuppliers = suppliersSet.toList();
                });
              }
            }).catchError((_) {});

            // Fetch current all inventory items with quantities
            Supabase.instance.client
                .from('inventory')
                .select('id, name, quantity, unit, category, supplier')
                .order('name')
                .then((items) {
              if (context.mounted) {
                setDialogState(() {
                  allDbItems = List<Map<String, dynamic>>.from(items);
                  for (final itm in allDbItems) {
                    final name = itm['name']?.toString() ?? '';
                    if (name.isNotEmpty && !qtyControllers.containsKey(name)) {
                      qtyControllers[name] = TextEditingController(text: '0');
                    }
                  }

                  // Pre-populate initial items from PO Generator
                  if (initialItems != null && initialItems.isNotEmpty) {
                    for (final initItem in initialItems) {
                      final name = initItem['name']?.toString() ?? '';
                      final qty = (initItem['quantity'] as num?)?.toInt() ?? 0;
                      if (name.isNotEmpty && qty > 0) {
                        final dbMatch = allDbItems.firstWhere(
                          (i) => (i['name']?.toString() ?? '').toLowerCase() == name.toLowerCase(),
                          orElse: () => {},
                        );
                        if (dbMatch.isEmpty) {
                          extraCustomItems.add(initItem);
                        }
                        restockQtys[name] = qty;
                        if (!qtyControllers.containsKey(name)) {
                          qtyControllers[name] = TextEditingController(text: qty.toString());
                        } else {
                          qtyControllers[name]!.text = qty.toString();
                        }
                      }
                    }
                  }
                });
              }
            });
          }

          // Combine extra custom/unlisted items at the top + DB items
          final combinedList = [...extraCustomItems, ...allDbItems];

          // Compute live inventory health counts
          int outOfStockCount = 0;
          int lowStockCount = 0;
          for (final item in combinedList) {
            final stock = (item['quantity'] as num?)?.toInt() ?? 0;
            if (stock == 0) {
              outOfStockCount++;
            } else if (stock <= 10) {
              lowStockCount++;
            }
          }

          // Filter by search, category, & stock health status
          final query = searchCtrl.text.toLowerCase().trim();
          final displayedItems = showOnlyUnlisted
              ? extraCustomItems.where((item) {
                  final name = (item['name']?.toString() ?? '').toLowerCase();
                  final cat = (item['category']?.toString() ?? 'General');
                  return query.isEmpty || name.contains(query) || cat.toLowerCase().contains(query);
                }).toList()
              : combinedList.where((item) {
                  final name = (item['name']?.toString() ?? '').toLowerCase();
                  final cat = (item['category']?.toString() ?? 'General');
                  final currentStock = (item['quantity'] as num?)?.toInt() ?? 0;
                  final currentQty = restockQtys[item['name']] ?? 0;

                  final matchesCategory = selectedCategoryFilter == 'All' ||
                      cat.toLowerCase() == selectedCategoryFilter.toLowerCase();
                  final matchesQuery = query.isEmpty || name.contains(query) || cat.toLowerCase().contains(query);
                  final matchesSelectedOnly = !showOnlySelected || currentQty > 0;

                  bool matchesStockHealth = true;
                  if (stockHealthFilter == 'OUT') {
                    matchesStockHealth = currentStock == 0;
                  } else if (stockHealthFilter == 'LOW') {
                    matchesStockHealth = currentStock > 0 && currentStock <= 10;
                  } else if (stockHealthFilter == 'OPTIMAL') {
                    matchesStockHealth = currentStock > 10;
                  }

                  return matchesCategory && matchesQuery && matchesSelectedOnly && matchesStockHealth;
                }).toList();

          // Calculate total items and units to receive
          int totalSelectedItems = 0;
          int totalUnitsCount = 0;
          for (final item in combinedList) {
            final name = item['name']?.toString() ?? '';
            final q = restockQtys[name] ?? 0;
            if (q > 0) {
              totalSelectedItems++;
              totalUnitsCount += q;
            }
          }

          void setItemQty(String name, int newQty) {
            final safeQty = newQty < 0 ? 0 : newQty;
            setDialogState(() {
              restockQtys[name] = safeQty;
              if (qtyControllers.containsKey(name)) {
                qtyControllers[name]!.text = safeQty.toString();
              }
            });
          }

          void addPresetToItem(String name, int addAmount) {
            final current = restockQtys[name] ?? 0;
            setItemQty(name, current + addAmount);
          }

          void autoFillLowStock(int targetAmount, {bool onlyZero = false}) {
            setDialogState(() {
              for (final item in allDbItems) {
                final name = item['name']?.toString() ?? '';
                final currentStock = (item['quantity'] as num?)?.toInt() ?? 0;
                if (onlyZero && currentStock == 0) {
                  restockQtys[name] = targetAmount;
                  qtyControllers[name]?.text = targetAmount.toString();
                } else if (!onlyZero && currentStock <= 10) {
                  restockQtys[name] = targetAmount;
                  qtyControllers[name]?.text = targetAmount.toString();
                }
              }
            });
          }

          void clearAllQuantities() {
            setDialogState(() {
              restockQtys.clear();
              for (final ctrl in qtyControllers.values) {
                ctrl.text = '0';
              }
            });
          }

          final isMobile = ResponsiveUtils.isMobile(context);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 16 : 24),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 14 : 20),
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 900,
                maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.96 : 0.94),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header with Title & Quick Utility Actions
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF059669), size: 18),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Delivery & Stock Intake',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.document_scanner_rounded, size: 14, color: Color(0xFF059669)),
                                label: const Text('Scan Receipt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                onPressed: () {
                                  _handleUploadDeliveryReceipt(
                                    allDbItems,
                                    (List<Map<String, dynamic>> items, {String? detectedSupplier}) {
                                      setDialogState(() {
                                        if (detectedSupplier != null && detectedSupplier.trim().isNotEmpty) {
                                          supplierCtrl.text = detectedSupplier.trim();
                                        }

                                        extraCustomItems.clear();
                                        restockQtys.clear();
                                        for (var ctrl in qtyControllers.values) {
                                          ctrl.text = '0';
                                        }

                                        for (final item in items) {
                                          final name = item['name']?.toString() ?? '';
                                          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                                          if (name.isNotEmpty && qty > 0) {
                                            final dbMatch = allDbItems.firstWhere(
                                              (i) => (i['name']?.toString() ?? '').toLowerCase() == name.toLowerCase(),
                                              orElse: () => {},
                                            );

                                            if (dbMatch.isEmpty) {
                                              final alreadyInExtra = extraCustomItems.indexWhere(
                                                (e) => (e['name']?.toString() ?? '').toLowerCase() == name.toLowerCase(),
                                              );
                                              if (alreadyInExtra >= 0) {
                                                extraCustomItems[alreadyInExtra]['quantity'] = qty;
                                              } else {
                                                extraCustomItems.add(item);
                                              }
                                            }

                                            if (!qtyControllers.containsKey(name)) {
                                              qtyControllers[name] = TextEditingController(text: qty.toString());
                                            } else {
                                              qtyControllers[name]!.text = qty.toString();
                                            }
                                            setItemQty(name, qty);
                                          }
                                        }
                                        showOnlySelected = true;
                                        showOnlyUnlisted = false;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 15, color: Color(0xFF64748B)),
                                label: const Text('+ Unlisted', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                onPressed: () {
                                  _showAddBulkItemDialog(
                                    allDbItems,
                                    (item) {
                                      setDialogState(() {
                                        extraCustomItems.add(item);
                                        final name = item['name']?.toString() ?? '';
                                        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                                        if (name.isNotEmpty) {
                                          qtyControllers[name] = TextEditingController(text: qty.toString());
                                          restockQtys[name] = qty;
                                        }
                                        showOnlyUnlisted = true;
                                        showOnlySelected = false;
                                        selectedCategoryFilter = 'All';
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: Color(0xFF059669),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fast Restock & Delivery Intake',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Quick grid entry • 1-tap auto-replenishment • OCR receipt scanning',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // OCR Upload Action
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.document_scanner_rounded, size: 15, color: Color(0xFF059669)),
                          label: const Text('Scan Receipt', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                          onPressed: () {
                            _handleUploadDeliveryReceipt(
                              allDbItems,
                              (List<Map<String, dynamic>> items, {String? detectedSupplier}) {
                                setDialogState(() {
                                  if (detectedSupplier != null && detectedSupplier.trim().isNotEmpty) {
                                    supplierCtrl.text = detectedSupplier.trim();
                                  }

                                  // Clear previous scan leftovers so old scans do not stack with new receipt!
                                  extraCustomItems.clear();
                                  restockQtys.clear();
                                  for (var ctrl in qtyControllers.values) {
                                    ctrl.text = '0';
                                  }

                                  for (final item in items) {
                                    final name = item['name']?.toString() ?? '';
                                    final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                                    if (name.isNotEmpty && qty > 0) {
                                      final dbMatch = allDbItems.firstWhere(
                                        (i) => (i['name']?.toString() ?? '').toLowerCase() == name.toLowerCase(),
                                        orElse: () => {},
                                      );

                                      if (dbMatch.isEmpty) {
                                        final alreadyInExtra = extraCustomItems.indexWhere(
                                          (e) => (e['name']?.toString() ?? '').toLowerCase() == name.toLowerCase(),
                                        );
                                        if (alreadyInExtra >= 0) {
                                          extraCustomItems[alreadyInExtra]['quantity'] = qty;
                                        } else {
                                          extraCustomItems.add(item);
                                        }
                                      }

                                      if (!qtyControllers.containsKey(name)) {
                                        qtyControllers[name] = TextEditingController(text: qty.toString());
                                      } else {
                                        qtyControllers[name]!.text = qty.toString();
                                      }
                                      setItemQty(name, qty);
                                    }
                                  }
                                  showOnlySelected = true;
                                  showOnlyUnlisted = false;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // Add Unlisted Item
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF64748B)),
                          label: const Text('+ Unlisted', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                          onPressed: () {
                            _showAddBulkItemDialog(
                              allDbItems,
                              (item) {
                                setDialogState(() {
                                  extraCustomItems.add(item);
                                  final name = item['name']?.toString() ?? '';
                                  final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                                  if (name.isNotEmpty) {
                                    qtyControllers[name] = TextEditingController(text: qty.toString());
                                    restockQtys[name] = qty;
                                  }
                                  showOnlyUnlisted = true; // SOLO UNLISTED VIEW
                                  showOnlySelected = false;
                                  selectedCategoryFilter = 'All';
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

                  // 2. Compact Delivery Header Strip (Receiver, Supplier, DR #)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: isMobile
                        ? Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _CustomSearchDropdown(
                                      controller: receiverCtrl,
                                      items: pastReceivers,
                                      label: 'Receiver',
                                      icon: Icons.person_outline_rounded,
                                      onChanged: (_) => setDialogState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _CustomSearchDropdown(
                                      controller: supplierCtrl,
                                      items: pastSuppliers,
                                      label: 'Supplier',
                                      hintText: 'Supplier',
                                      icon: Icons.storefront_rounded,
                                      onChanged: (_) => setDialogState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: drCtrl,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                decoration: InputDecoration(
                                  labelText: 'DR / Invoice #',
                                  hintText: 'Optional',
                                  prefixIcon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF64748B)),
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFFFEFDFB),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5)),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              // Receiver
                              Expanded(
                                flex: 3,
                                child: _CustomSearchDropdown(
                                  controller: receiverCtrl,
                                  items: pastReceivers,
                                  label: 'Receiver',
                                  icon: Icons.person_outline_rounded,
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Supplier
                              Expanded(
                                flex: 3,
                                child: _CustomSearchDropdown(
                                  controller: supplierCtrl,
                                  items: pastSuppliers,
                                  label: 'Supplier',
                                  hintText: 'Search or enter supplier',
                                  icon: Icons.storefront_rounded,
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // DR Number
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: drCtrl,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    labelText: 'DR / Invoice #',
                                    hintText: 'Optional',
                                    prefixIcon: const Icon(Icons.receipt_long_rounded, size: 17, color: Color(0xFF64748B)),
                                    isDense: true,
                                    filled: true,
                                    fillColor: const Color(0xFFFEFDFB),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 10),

                  // 3. Clean Integrated Filter & Action Toolbar
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 36,
                          child: TextField(
                            controller: searchCtrl,
                            onChanged: (_) => setDialogState(() {}),
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Filter ingredients by name...',
                              hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                              suffixIcon: searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 14),
                                      onPressed: () => setDialogState(() => searchCtrl.clear()),
                                    )
                                  : null,
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              // Interactive "Out of Stock" Badge
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setDialogState(() {
                                    stockHealthFilter = stockHealthFilter == 'OUT' ? 'ALL' : 'OUT';
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: stockHealthFilter == 'OUT' ? const Color(0xFFEF4444) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: stockHealthFilter == 'OUT' ? const Color(0xFFEF4444) : const Color(0xFFFECACA),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.cancel_rounded,
                                        size: 13,
                                        color: stockHealthFilter == 'OUT' ? Colors.white : const Color(0xFFEF4444),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$outOfStockCount Out',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: stockHealthFilter == 'OUT' ? Colors.white : const Color(0xFF991B1B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Interactive "Low Stock" Badge
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setDialogState(() {
                                    stockHealthFilter = stockHealthFilter == 'LOW' ? 'ALL' : 'LOW';
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: stockHealthFilter == 'LOW' ? const Color(0xFFF59E0B) : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: stockHealthFilter == 'LOW' ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 13,
                                        color: stockHealthFilter == 'LOW' ? Colors.white : const Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$lowStockCount Low',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: stockHealthFilter == 'LOW' ? Colors.white : const Color(0xFF92400E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Fast 1-Tap Replenish Action
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => autoFillLowStock(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF16A34A)),
                                      SizedBox(width: 3),
                                      Text(
                                        'Auto-Fill (<10)',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Restocking Only Filter Toggle
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => setDialogState(() {
                                  showOnlySelected = !showOnlySelected;
                                  if (showOnlySelected) showOnlyUnlisted = false;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: showOnlySelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: showOnlySelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.shopping_basket_outlined,
                                        size: 12,
                                        color: showOnlySelected ? Colors.white : const Color(0xFF475569),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Restocking ($totalSelectedItems)',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: showOnlySelected ? Colors.white : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (extraCustomItems.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setDialogState(() {
                                    showOnlyUnlisted = !showOnlyUnlisted;
                                    if (showOnlyUnlisted) showOnlySelected = false;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: showOnlyUnlisted ? const Color(0xFF7E22CE) : const Color(0xFFFAF5FF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: showOnlyUnlisted ? const Color(0xFF7E22CE) : const Color(0xFFD8B4FE),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.stars_rounded,
                                          size: 12,
                                          color: showOnlyUnlisted ? Colors.white : const Color(0xFF9333EA),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '✨ Unlisted (${extraCustomItems.length})',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: showOnlyUnlisted ? Colors.white : const Color(0xFF7E22CE),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if (totalSelectedItems > 0) ...[
                                const SizedBox(width: 6),
                                IconButton(
                                  style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
                                  tooltip: 'Clear All Inputs',
                                  icon: const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFFEF4444)),
                                  onPressed: clearAllQuantities,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        // Search Input
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              controller: searchCtrl,
                              onChanged: (_) => setDialogState(() {}),
                              style: const TextStyle(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Filter ingredients by name...',
                                hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                                suffixIcon: searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 14),
                                        onPressed: () => setDialogState(() => searchCtrl.clear()),
                                      )
                                    : null,
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Interactive "Out of Stock" Badge
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setDialogState(() {
                              stockHealthFilter = stockHealthFilter == 'OUT' ? 'ALL' : 'OUT';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: stockHealthFilter == 'OUT' ? const Color(0xFFEF4444) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: stockHealthFilter == 'OUT' ? const Color(0xFFEF4444) : const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cancel_rounded,
                                  size: 14,
                                  color: stockHealthFilter == 'OUT' ? Colors.white : const Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$outOfStockCount Out',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: stockHealthFilter == 'OUT' ? Colors.white : const Color(0xFF991B1B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Interactive "Low Stock" Badge
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setDialogState(() {
                              stockHealthFilter = stockHealthFilter == 'LOW' ? 'ALL' : 'LOW';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: stockHealthFilter == 'LOW' ? const Color(0xFFF59E0B) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: stockHealthFilter == 'LOW' ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: stockHealthFilter == 'LOW' ? Colors.white : const Color(0xFFD97706),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$lowStockCount Low',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: stockHealthFilter == 'LOW' ? Colors.white : const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Fast 1-Tap Replenish Action
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => autoFillLowStock(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF16A34A)),
                                SizedBox(width: 3),
                                Text(
                                  'Auto-Fill (<10)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Restocking Only Filter Toggle
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setDialogState(() {
                            showOnlySelected = !showOnlySelected;
                            if (showOnlySelected) showOnlyUnlisted = false;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: showOnlySelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: showOnlySelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shopping_basket_outlined,
                                  size: 13,
                                  color: showOnlySelected ? Colors.white : const Color(0xFF475569),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Restocking ($totalSelectedItems)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: showOnlySelected ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (extraCustomItems.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setDialogState(() {
                              showOnlyUnlisted = !showOnlyUnlisted;
                              if (showOnlyUnlisted) showOnlySelected = false;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: showOnlyUnlisted ? const Color(0xFF7E22CE) : const Color(0xFFFAF5FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: showOnlyUnlisted ? const Color(0xFF7E22CE) : const Color(0xFFD8B4FE),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.stars_rounded,
                                    size: 13,
                                    color: showOnlyUnlisted ? Colors.white : const Color(0xFF9333EA),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '✨ Unlisted (${extraCustomItems.length})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: showOnlyUnlisted ? Colors.white : const Color(0xFF7E22CE),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (totalSelectedItems > 0) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
                            tooltip: 'Clear All Inputs',
                            icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFEF4444)),
                            onPressed: clearAllQuantities,
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 8),

                  // 4. Category Pills (Hidden in solo unlisted mode for ultra-clean view)
                  if (!showOnlyUnlisted) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((cat) {
                          final isSel = selectedCategoryFilter == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: ChoiceChip(
                              label: Text(cat),
                              labelStyle: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                              selected: isSel,
                              selectedColor: const Color(0xFFE2E8F0),
                              backgroundColor: const Color(0xFFF8FAFC),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              side: BorderSide(color: isSel ? const Color(0xFF94A3B8) : const Color(0xFFE2E8F0)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onSelected: (val) {
                                if (val) {
                                  setDialogState(() {
                                    selectedCategoryFilter = cat;

                                    // Intelligent Supplier Auto-Detection for Category
                                    if (cat != 'All') {
                                      final categoryItems = allDbItems.where(
                                        (i) => (i['category']?.toString() ?? '').toLowerCase() == cat.toLowerCase(),
                                      );

                                      final Map<String, int> supplierCounts = {};
                                      for (final itm in categoryItems) {
                                        final sup = itm['supplier']?.toString().trim();
                                        if (sup != null && sup.isNotEmpty) {
                                          supplierCounts[sup] = (supplierCounts[sup] ?? 0) + 1;
                                        }
                                      }

                                      if (supplierCounts.isNotEmpty) {
                                        final bestSupplier = supplierCounts.entries
                                            .reduce((a, b) => a.value > b.value ? a : b)
                                            .key;
                                        supplierCtrl.text = bestSupplier;
                                      } else {
                                        if (cat.toLowerCase().contains('veg')) {
                                          supplierCtrl.text = 'Public Market';
                                        } else if (cat.toLowerCase().contains('fresh') || cat.toLowerCase().contains('meat')) {
                                          supplierCtrl.text = 'Public Market';
                                        } else if (cat.toLowerCase().contains('groc') || cat.toLowerCase().contains('sauce')) {
                                          supplierCtrl.text = 'Metro Wholesale';
                                        } else if (cat.toLowerCase().contains('david')) {
                                          supplierCtrl.text = 'Davids Supplier';
                                        } else if (cat.toLowerCase().contains('roast')) {
                                          supplierCtrl.text = 'Poultry Supplier';
                                        } else if (cat.toLowerCase().contains('drink')) {
                                          supplierCtrl.text = 'Beverage Distributor';
                                        } else if (cat.toLowerCase().contains('pack')) {
                                          supplierCtrl.text = 'Packaging Supplier';
                                        } else if (cat.toLowerCase().contains('janitor')) {
                                          supplierCtrl.text = 'Janitorial Supplies';
                                        }
                                      }
                                    }
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    // Solo Unlisted Mode Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD8B4FE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars_rounded, size: 18, color: Color(0xFF9333EA)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Solo Unlisted View: Showing ${extraCustomItems.length} new unlisted item${extraCustomItems.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6B21A8),
                              ),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF7E22CE),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.list_alt_rounded, size: 14),
                            label: const Text('Show All Items', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                            onPressed: () => setDialogState(() => showOnlyUnlisted = false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Fast Spreadsheet Restock List
                  Expanded(
                    child: displayedItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 8),
                                Text(
                                  showOnlySelected ? 'No items currently marked for restock' : 'No ingredients match filter',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: displayedItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = displayedItems[index];
                              final name = item['name']?.toString() ?? '';
                              final category = item['category']?.toString() ?? 'General';
                              final unit = item['unit']?.toString() ?? 'pcs';
                              final currentStock = (item['quantity'] as num?)?.toInt() ?? 0;
                              final restockQty = restockQtys[name] ?? 0;
                              final newTotal = currentStock + restockQty;

                              final isZero = currentStock == 0;
                              final isLow = currentStock > 0 && currentStock <= 10;
                              final stockColor = isZero
                                  ? const Color(0xFFEF4444)
                                  : isLow
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF10B981);

                              final ctrl = qtyControllers[name] ?? TextEditingController(text: restockQty.toString());
                              final isUnlisted = extraCustomItems.any((e) => (e['name'] ?? '').toString().toLowerCase() == name.toLowerCase()) || item['isUnlisted'] == true;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isUnlisted
                                      ? const Color(0xFFFAF5FF)
                                      : restockQty > 0
                                          ? const Color(0xFFF0FDF4)
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isUnlisted
                                        ? const Color(0xFFD8B4FE)
                                        : restockQty > 0
                                            ? const Color(0xFF86EFAC)
                                            : const Color(0xFFE2E8F0),
                                    width: (restockQty > 0 || isUnlisted) ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Item Name & Category / Supplier
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              if (isUnlisted) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF3E8FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFD8B4FE)),
                                                  ),
                                                  child: const Text(
                                                    '✨ UNLISTED',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF7E22CE),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                category,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (item['supplier'] != null && item['supplier'].toString().trim().isNotEmpty) ...[
                                                const Text('  •  ', style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
                                                Icon(Icons.storefront_rounded, size: 12, color: Colors.amber.shade800),
                                                const SizedBox(width: 3),
                                                Flexible(
                                                  child: Text(
                                                    item['supplier'].toString().trim(),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      color: Colors.amber.shade900,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Current Stock Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isUnlisted ? const Color(0xFFF3E8FF) : stockColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isUnlisted ? 'New Item (0 $unit)' : 'Stock: $currentStock $unit',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isUnlisted ? const Color(0xFF7E22CE) : stockColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Stepper & Quick Pills
                                    Row(
                                      children: [
                                        // Minus Button
                                        IconButton(
                                          style: IconButton.styleFrom(
                                            backgroundColor: const Color(0xFFF1F5F9),
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(28, 28),
                                          ),
                                          icon: const Icon(Icons.remove_rounded, size: 16, color: Color(0xFF0F172A)),
                                          onPressed: restockQty > 0 ? () => setItemQty(name, restockQty - 1) : null,
                                        ),
                                        const SizedBox(width: 6),

                                        // Editable Number Text Box
                                        SizedBox(
                                          width: 60,
                                          height: 34,
                                          child: TextField(
                                            controller: ctrl,
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: restockQty > 0 ? const Color(0xFF059669) : const Color(0xFF0F172A),
                                            ),
                                            decoration: InputDecoration(
                                              contentPadding: EdgeInsets.zero,
                                              isDense: true,
                                              filled: true,
                                              fillColor: restockQty > 0 ? Colors.white : const Color(0xFFF8FAFC),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: restockQty > 0 ? const Color(0xFF059669) : const Color(0xFFCBD5E1)),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: restockQty > 0 ? const Color(0xFF059669) : const Color(0xFFCBD5E1)),
                                              ),
                                            ),
                                            onChanged: (val) {
                                              final parsed = int.tryParse(val) ?? 0;
                                              restockQtys[name] = parsed < 0 ? 0 : parsed;
                                              setDialogState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Plus Button
                                        IconButton(
                                          style: IconButton.styleFrom(
                                            backgroundColor: const Color(0xFF059669),
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(28, 28),
                                          ),
                                          icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                          onPressed: () => setItemQty(name, restockQty + 1),
                                        ),
                                        const SizedBox(width: 8),

                                        // Quick Presets (+5, +10, +25, +50)
                                        ...[5, 10, 25, 50].map((preset) {
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 4),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(6),
                                              onTap: () => addPresetToItem(name, preset),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                ),
                                                child: Text(
                                                  '+$preset',
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),

                                    const SizedBox(width: 14),

                                    // Resulting Stock Preview
                                    SizedBox(
                                      width: 75,
                                      child: Text(
                                        restockQty > 0
                                            ? '➔ $newTotal $unit'
                                            : (isUnlisted ? '➔ $restockQty $unit' : '—'),
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: restockQty > 0 ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    if (isUnlisted) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Remove unlisted item',
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0xFFFEE2E2),
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(26, 26),
                                        ),
                                        icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                                        onPressed: () {
                                          setDialogState(() {
                                            extraCustomItems.removeWhere((e) => (e['name'] ?? '').toString().toLowerCase() == name.toLowerCase());
                                            restockQtys.remove(name);
                                            qtyControllers.remove(name);
                                          });
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Bottom Actions & Summary
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: totalSelectedItems > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: totalSelectedItems > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_rounded,
                                      size: 15,
                                      color: totalSelectedItems > 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '$totalSelectedItems items  •  $totalUnitsCount units',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: totalSelectedItems > 0 ? const Color(0xFF065F46) : const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: totalSelectedItems == 0 || receiverCtrl.text.trim().isEmpty
                                    ? null
                                    : () async {
                                        final receiver = receiverCtrl.text.trim();
                                        final defaultSupplier = supplierCtrl.text.trim().isEmpty ? 'Public Market' : supplierCtrl.text.trim();
                                        final drNumber = drCtrl.text.trim().isEmpty ? null : drCtrl.text.trim();

                                        final List<Map<String, dynamic>> itemsToProcess = [];
                                        for (final item in combinedList) {
                                          final name = item['name']?.toString() ?? '';
                                          final qty = restockQtys[name] ?? 0;
                                          if (name.isNotEmpty && qty > 0) {
                                            itemsToProcess.add({
                                              'name': name,
                                              'category': item['category'] ?? 'General',
                                              'quantity': qty,
                                              'unit': item['unit'] ?? 'pcs',
                                              'supplier': item['supplier'] ?? defaultSupplier,
                                            });
                                          }
                                        }

                                        Navigator.pop(context);
                                        await _processBulkIncomingStock(
                                          itemsToProcess,
                                          receiver,
                                          drNumber != null ? 'DR: $drNumber' : null,
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.check_circle_rounded, size: 17),
                                label: Text(
                                  totalSelectedItems > 0 ? 'PROCESS $totalSelectedItems ITEMS' : 'SELECT ITEMS TO RESTOCK',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.3),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              // Selected counter pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: totalSelectedItems > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: totalSelectedItems > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_rounded,
                                      size: 16,
                                      color: totalSelectedItems > 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$totalSelectedItems items to receive  •  $totalUnitsCount total units',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: totalSelectedItems > 0 ? const Color(0xFF065F46) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),

                              // Cancel
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                              ),
                              const SizedBox(width: 10),

                              // Process Button
                              ElevatedButton.icon(
                                onPressed: totalSelectedItems == 0 || receiverCtrl.text.trim().isEmpty
                                    ? null
                                    : () async {
                                        final receiver = receiverCtrl.text.trim();
                                        final defaultSupplier = supplierCtrl.text.trim().isEmpty ? 'Public Market' : supplierCtrl.text.trim();
                                        final drNumber = drCtrl.text.trim().isEmpty ? null : drCtrl.text.trim();

                                        final List<Map<String, dynamic>> itemsToProcess = [];
                                        for (final item in combinedList) {
                                          final name = item['name']?.toString() ?? '';
                                          final qty = restockQtys[name] ?? 0;
                                          if (name.isNotEmpty && qty > 0) {
                                            itemsToProcess.add({
                                              'name': name,
                                              'category': item['category'] ?? 'General',
                                              'quantity': qty,
                                              'unit': item['unit'] ?? 'pcs',
                                              'supplier': item['supplier'] ?? defaultSupplier,
                                            });
                                          }
                                        }

                                        Navigator.pop(context);
                                        await _processBulkIncomingStock(
                                          itemsToProcess,
                                          receiver,
                                          drNumber != null ? 'DR: $drNumber' : null,
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.check_circle_rounded, size: 18),
                                label: Text(
                                  totalSelectedItems > 0 ? 'PROCESS $totalSelectedItems ITEMS' : 'SELECT ITEMS TO RESTOCK',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 0.4),
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

  void _handleUploadDeliveryReceipt(
    List<Map<String, dynamic>> allItems,
    Function(List<Map<String, dynamic>>, {String? detectedSupplier}) onItemsAdded,
  ) async {
    try {
      // Open file picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'jfif'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _showErrorSnackBar('Could not read the selected file.');
        return;
      }

      // Show loading dialog safely
      if (!mounted) return;
      bool isDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (ctx) => PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Scanning Delivery Receipt...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    file.name,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Extracting items & auto-matching inventory...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ).then((_) {
        isDialogShowing = false;
      });

      // Fetch fresh inventory items directly from database
      List<Map<String, dynamic>> inventoryItems = allItems;
      try {
        final res = await Supabase.instance.client
            .from('inventory')
            .select('name, category, unit, supplier');
        if (res.isNotEmpty) {
          inventoryItems = List<Map<String, dynamic>>.from(res);
        }
      } catch (e) {
        debugPrint('Error fetching inventory for OCR matching: $e');
      }

      // Call OCR service
      final ocrResult = await DeliveryReceiptOcrService.parseDeliveryReceipt(
        fileBytes: file.bytes!,
        fileName: file.name,
      );

      // Close loading dialog safely without affecting parent modals
      if (mounted && isDialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShowing = false;
      }

      if (ocrResult['success'] != true) {
        _showErrorSnackBar(ocrResult['error'] ?? 'Failed to scan receipt');
        return;
      }

      final List<dynamic> parsedItems = ocrResult['items'] ?? [];
      final String? detectedSupplier = ocrResult['supplier'];

      if (parsedItems.isEmpty) {
        _showErrorSnackBar('No items found in the delivery receipt.');
        return;
      }

      // Match parsed items against inventory using similarity & deduplicate
      final Map<String, Map<String, dynamic>> aggregatedItems = {};
      final Set<String> matchedNamesSet = {};
      final Set<String> unmatchedDisplaySet = {};

      for (final parsed in parsedItems) {
        final String parsedName = (parsed['name'] ?? '').toString().trim();
        final int parsedQty = (parsed['quantity'] as num?)?.toInt() ?? 0;
        final String parsedUnit = (parsed['unit'] ?? 'Pcs').toString().trim();

        if (parsedName.isEmpty || parsedQty <= 0) continue;

        String cleanParsedName = parsedName;
        if (detectedSupplier != null && detectedSupplier.trim().isNotEmpty) {
          cleanParsedName = cleanParsedName
              .replaceAll(RegExp(r'\b' + RegExp.escape(detectedSupplier.trim()) + r'\b', caseSensitive: false), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
        }
        if (cleanParsedName.isEmpty) cleanParsedName = parsedName;

        // Skip any lingering headers/footers
        final lower = cleanParsedName.toLowerCase();
        if (lower.contains('yang chow') ||
            lower.contains('purchase order') ||
            lower.contains('delivery receipt') ||
            lower.contains('prepared &') ||
            lower.contains('signature') ||
            lower.contains('acknowledged by') ||
            lower.contains('combined suppliers') ||
            lower.contains('target delivery') ||
            lower.contains('delivery location') ||
            lower.contains('order qty') ||
            lower.contains('current stock') ||
            lower.contains('category /') ||
            lower == 'fresh produce' ||
            lower == 'public market' ||
            lower == 'poultry & meat supplier' ||
            lower == 'metro wholesale' ||
            lower == 'beverage distributor' ||
            lower == 'fresh' ||
            lower == 'market' ||
            lower == 'supplier') {
          continue;
        }

        // Find best match in inventory (Strict threshold: 0.70)
        Map<String, dynamic>? bestMatch;
        double highestScore = 0.0;

        for (final inv in inventoryItems) {
          final invName = inv['name']?.toString() ?? '';
          final score = DeliveryReceiptOcrService.calculateSimilarity(cleanParsedName, invName);
          if (score > highestScore && score >= 0.70) {
            highestScore = score;
            bestMatch = inv;
          }
        }

        // Clean supplier text
        String finalSupplier = (bestMatch != null && bestMatch['supplier'] != null && bestMatch['supplier'].toString().trim().isNotEmpty)
            ? bestMatch['supplier'].toString().trim()
            : (detectedSupplier ?? '');
        finalSupplier = finalSupplier
            .replaceAll(RegExp(r'\b(PREPARED BY|DELIVERY LOCATION|TARGET DELIVERY).*$', caseSensitive: false), '')
            .replaceAll(RegExp(r'[:#*_-]+$'), '')
            .trim();

        if (bestMatch != null) {
          final String matchedName = (bestMatch['name'] ?? cleanParsedName).toString().trim();
          final String dedupKey = matchedName.toLowerCase();
          matchedNamesSet.add(dedupKey);

          if (aggregatedItems.containsKey(dedupKey)) {
            // Merge quantity if already read
            aggregatedItems[dedupKey]!['quantity'] = (aggregatedItems[dedupKey]!['quantity'] as int) + parsedQty;
          } else {
            aggregatedItems[dedupKey] = {
              'name': matchedName,
              'category': bestMatch['category'] ?? 'Groceries',
              'quantity': parsedQty,
              'unit': (bestMatch['unit'] != null && bestMatch['unit'].toString().trim().isNotEmpty)
                  ? bestMatch['unit'].toString().trim()
                  : parsedUnit,
              'supplier': finalSupplier,
            };
          }
        } else {
          // Unlisted / New Item: Clean name and deduplicate
          final String dedupKey = cleanParsedName.toLowerCase();
          if (aggregatedItems.containsKey(dedupKey)) {
            aggregatedItems[dedupKey]!['quantity'] = (aggregatedItems[dedupKey]!['quantity'] as int) + parsedQty;
          } else {
            aggregatedItems[dedupKey] = {
              'name': cleanParsedName,
              'category': 'Groceries',
              'quantity': parsedQty,
              'unit': parsedUnit.isNotEmpty ? parsedUnit : 'Pcs',
              'supplier': finalSupplier,
            };
          }
          unmatchedDisplaySet.add('$cleanParsedName ($parsedQty $parsedUnit)');
        }
      }

      final List<Map<String, dynamic>> itemsToAdd = aggregatedItems.values.toList();
      final int matchedCount = matchedNamesSet.length;
      final List<String> unmatchedNames = unmatchedDisplaySet.toList();

      // Add all items to the bulk list
      if (itemsToAdd.isNotEmpty) {
        onItemsAdded(itemsToAdd, detectedSupplier: detectedSupplier);
      }

      if (!mounted) return;
      if (unmatchedNames.isNotEmpty) {
        _showReceiptScanResults(itemsToAdd.length, matchedCount, unmatchedNames);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Scanned ${itemsToAdd.length} items from receipt (all matched with inventory)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
      }
      _showErrorSnackBar('Error processing receipt: $e');
    }
  }

  void _showReceiptScanResults(int totalAdded, int matchedCount, List<String> unmatchedNames) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 440),
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
                      color: AppTheme.successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Delivery Receipt Scanned',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total added banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.successGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2,
                      color: AppTheme.successGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$totalAdded item${totalAdded > 1 ? 's' : ''} added to the delivery list ($matchedCount auto-matched with inventory)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Note on new / unmatched items if any
              if (unmatchedNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${unmatchedNames.length} new item${unmatchedNames.length > 1 ? 's' : ''} added (not in inventory yet):',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...unmatchedNames.map(
                        (name) => Padding(
                          padding: const EdgeInsets.only(left: 26, bottom: 2),
                          child: Text(
                            '• $name',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.white,
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddBulkItemDialog(
    List<Map<String, dynamic>> allItems,
    Function(Map<String, dynamic>) onItemAdded,
  ) {
    String? selectedCategory;
    final itemNameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    List<String> filteredItemNames = allItems
        .map((item) => item['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    bool initialized = false;
    bool isExistingItem = false;

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
                final dbCategory = match['category']?.toString();
                
                bool changed = false;
                if (!isExistingItem) {
                  isExistingItem = true;
                  changed = true;
                }
                if (dbCategory != null && dbCategory.isNotEmpty && dbCategory != selectedCategory && categories.contains(dbCategory)) {
                  selectedCategory = dbCategory;
                  changed = true;
                }
                if (dbUnit != null && dbUnit.isNotEmpty && unitCtrl.text != dbUnit) {
                  unitCtrl.text = dbUnit;
                  changed = true;
                }
                if (dbSupplier != null && dbSupplier.isNotEmpty && supplierCtrl.text != dbSupplier) {
                  supplierCtrl.text = dbSupplier;
                  changed = true;
                }
                if (changed && context.mounted) setDialogState(() {});
              } catch (_) {
                if (isExistingItem) {
                  isExistingItem = false;
                  if (context.mounted) setDialogState(() {});
                }
              }
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
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                                      .map(
                                        (item) =>
                                            item['name']?.toString() ?? '',
                                      )
                                      .where((name) => name.isNotEmpty)
                                      .toList();
                                  // Do not clear the item and its details, allowing user to keep typed item with newly selected category.
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
                                showDropdownIcon: false,
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
                                  readOnly: isExistingItem,
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
                            readOnly: isExistingItem,
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
                              selectedCategory == null ||
                              selectedCategory!.isEmpty ||
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

  InputDecoration _buildDecoration(String label, IconData icon, {bool readOnly = false}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: readOnly ? AppTheme.mediumGrey : AppTheme.primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.lightGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: readOnly ? AppTheme.lightGrey : AppTheme.primaryColor),
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
    bool readOnly = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      decoration: _buildDecoration(label, icon, readOnly: readOnly),
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
    String? purpose, {
    bool showNotification = true,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final cleanName = name.trim();

      // 1. Check if item exists in inventory (Case-insensitive)
      final existingItems = await Supabase.instance.client
          .from('inventory')
          .select()
          .ilike('name', cleanName)
          .limit(1);

      if (existingItems.isNotEmpty) {
        final existingItem = existingItems.first;
        final currentQty = (existingItem['quantity'] as num?)?.toInt() ?? 0;
        await Supabase.instance.client
            .from('inventory')
            .update({
              'quantity': currentQty + quantity,
              if (supplier.isNotEmpty) 'supplier': supplier,
            })
            .eq('id', existingItem['id']);
      } else {
        // Fallback: check normalized name across all inventory
        final allInv = await Supabase.instance.client
            .from('inventory')
            .select('id, name, quantity');
        final normTarget = cleanName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        final match = allInv.firstWhere(
          (inv) => (inv['name'] ?? '').toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), '') == normTarget,
          orElse: () => {},
        );

        if (match.isNotEmpty) {
          final currentQty = (match['quantity'] as num?)?.toInt() ?? 0;
          await Supabase.instance.client
              .from('inventory')
              .update({'quantity': currentQty + quantity})
              .eq('id', match['id']);
        } else {
          await Supabase.instance.client.from('inventory').insert({
            'name': cleanName,
            'category': category,
            'quantity': quantity,
            'unit': unit,
            'supplier': supplier,
            'created_by': user?.email,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }

      await Supabase.instance.client.from('stock_transactions').insert({
        'item_name': cleanName,
        'transaction_type': 'incoming',
        'quantity': quantity,
        'unit': unit,
        'supplier': supplier,
        'processed_by': receiver,
        'created_at': deliveryTimestamp ?? DateTime.now().toUtc().toIso8601String(),
        if (drNumber != null) 'purpose': 'DR: $drNumber',
        if (purpose != null) 'purpose': purpose,
      });

      if (showNotification) {
        _showSuccessSnackBar('Stock added successfully!');
      }
    } catch (e) {
      if (showNotification) {
        _showErrorSnackBar('Failed to add stock: $e');
      }
      rethrow;
    }
  }

  Future<void> _processBulkIncomingStock(
    List<Map<String, dynamic>> bulkItems,
    String receiver,
    String? purpose,
  ) async {
    int successCount = 0;
    int failureCount = 0;
    List<String> failedItems = [];
    
    // Generate a single DR Number (5-digit random) for this bulk delivery
    final drNumber = (10000 + Random().nextInt(90000)).toString();
    final deliveryTimestamp = DateTime.now().toUtc().toIso8601String();

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
          purpose, // Pass purpose
          showNotification: false,
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

  Future<void> _processPettyCashToStorage(
    String itemName,
    int quantity,
    String unit,
    String supplier,
    String transactionId,
  ) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      // Add to inventory first
      final existingItems = await Supabase.instance.client
          .from('inventory')
          .select()
          .eq('name', itemName)
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
          'name': itemName,
          'category': 'Groceries', // Default category
          'quantity': quantity,
          'unit': unit,
          'supplier': supplier,
          'created_by': user?.email,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      // Update purpose to mark as transferred (no need to delete due to RLS policy)
      print('Updating transaction $transactionId purpose to Transferred to Storage');
      final updateResult = await Supabase.instance.client
          .from('stock_transactions')
          .update({'purpose': 'Transferred to Storage'})
          .eq('id', transactionId)
          .select();

      print('Update result: $updateResult');
      print('Update successful: ${updateResult.isNotEmpty}');

      // Force UI refresh
      setState(() {});

      _showPettyCashModal(itemName, quantity, unit);
    } catch (e) {
      print('Error in _processPettyCashToStorage: $e');
      _showErrorSnackBar('Failed to add to storage: $e');
    }
  }

  void _showPettyCashModal(String itemName, int quantity, String unit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _emeraldDeep.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _emeraldDeep.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: _emeraldDeep, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Petty Cash Transferred',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _emeraldDeep.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _emeraldDeep.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _emeraldDeep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$quantity $unit',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'This item was purchased via petty cash and has been successfully added to the storage room.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _emeraldDeep,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _emeraldDeep.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_shipping_rounded, color: _emeraldDeep, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Details',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'DR Number: $drNumber',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _emeraldMedium,
                    ),
                  ),
                  Text(
                    'Receiver: $receiver  •  $deliveryDateTime',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
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
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_rounded, size: 16, color: _emeraldDeep),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            transaction['item_name'] ?? 'Unknown Item',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.numbers_rounded, size: 14, color: _emeraldMedium),
                        const SizedBox(width: 8),
                        Text(
                          '${transaction['quantity']} ${transaction['unit']?.toString().trim() ?? 'units'}'.trim(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _emeraldMedium,
                          ),
                        ),
                      ],
                    ),
                    if (transaction['supplier'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.business_rounded, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Supplier: ${transaction['supplier']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _emeraldDeep,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Unified Realistic Theme Palette ──
  static const Color _obsidianDark = Color(0xFF0B211D);
  static const Color _emeraldDeep = Color(0xFF133831);
  static const Color _emeraldMedium = Color(0xFF1C4D43);
  static const Color _goldAccent = Color(0xFFE6C374);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_obsidianDark, _emeraldDeep],
            ),
            border: Border(
              bottom: BorderSide(color: Color(0x33E6C374), width: 1),
            ),
          ),
        ),
        elevation: 6,
        shadowColor: const Color(0x660B211D),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _goldAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _goldAccent.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.warehouse_rounded, color: _goldAccent, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Storage Room',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  'Inventory & Delivery Management',
                  style: TextStyle(
                    color: _goldAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _goldAccent,
          indicatorWeight: 3.5,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: _goldAccent,
          unselectedLabelColor: Colors.white60,
          labelStyle: TextStyle(
            fontSize: ResponsiveUtils.isMobile(context) ? 11 : 13,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: ResponsiveUtils.isMobile(context) ? 11 : 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            Tab(
              icon: Icon(Icons.warehouse_rounded,
                  size: ResponsiveUtils.isMobile(context) ? 18 : 20),
              text: ResponsiveUtils.isMobile(context) ? 'Storage' : 'Storage Room',
            ),
            Tab(
              icon: Icon(Icons.local_shipping_rounded,
                  size: ResponsiveUtils.isMobile(context) ? 18 : 20),
              text: 'Incoming',
            ),
            Tab(
              icon: Icon(Icons.account_balance_wallet_rounded,
                  size: ResponsiveUtils.isMobile(context) ? 18 : 20),
              text: 'Petty Cash',
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFFF3F6F6),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildStorageRoomTab(),
            _buildIncomingTab(),
            _buildPettyCashTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageRoomTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('inventory')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];
        final filteredItems = allItems.where((item) {
          final name = (item['name'] ?? '').toString().toLowerCase();
          final storageRoom = (item['storage_room'] ?? '').toString().toLowerCase();
          final query = _searchQuery.toLowerCase();
          final matchesSearch = name.contains(query) || storageRoom.contains(query);
          final matchesRoom = _selectedStorageRoom == 'All' ||
              item['storage_room']?.toString() == _selectedStorageRoom;
          return matchesSearch && matchesRoom;
        }).toList()
          ..sort((a, b) => (a['name'] ?? '').toString().toLowerCase()
              .compareTo((b['name'] ?? '').toString().toLowerCase()));

        final totalItems = allItems.length;
        final outOfStock = allItems.where((i) => ((i['quantity'] as num?)?.toInt() ?? 0) == 0).length;
        final lowStock = allItems.where((i) {
          final q = (i['quantity'] as num?)?.toInt() ?? 0;
          return q > 0 && q < 10;
        }).length;

        return Column(
          children: [
            // ── Unified Realistic Header Banner ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_obsidianDark, _emeraldDeep],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _goldAccent.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: _obsidianDark.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _goldAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _goldAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.warehouse_rounded, color: _goldAccent, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Storage Inventory',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Live storage stock levels & room allocations',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stat badges
                  Row(
                    children: [
                      _statBadge('$totalItems Total', Colors.white.withValues(alpha: 0.15), Colors.white, border: Colors.white24),
                      if (outOfStock > 0) ...[
                        const SizedBox(width: 6),
                        _statBadge('$outOfStock Out', const Color(0x33EF4444), const Color(0xFFFCA5A5), border: const Color(0x66EF4444)),
                      ] else if (lowStock > 0) ...[
                        const SizedBox(width: 6),
                        _statBadge('$lowStock Low', const Color(0x33F59E0B), const Color(0xFFFCD34D), border: const Color(0x66F59E0B)),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Search + Room Filters ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search items or storage rooms...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: _emeraldMedium, size: 22),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                        borderSide: const BorderSide(color: _emeraldMedium, width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: storageRooms.map((room) {
                        final isSel = _selectedStorageRoom == room;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedStorageRoom = room),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSel ? _emeraldDeep : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSel ? _goldAccent.withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
                                  width: isSel ? 1.2 : 1,
                                ),
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: _emeraldDeep.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSel) ...[
                                    const Icon(Icons.check_circle_rounded, size: 13, color: _goldAccent),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(
                                    room,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                      color: isSel ? _goldAccent : const Color(0xFF475569),
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

            const SizedBox(height: 10),

            // ── Grid of Storage Items ──
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator(color: _emeraldMedium))
                  : snapshot.hasError
                      ? Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.errorRed)))
                      : filteredItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: _emeraldDeep.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(color: _emeraldDeep.withValues(alpha: 0.2)),
                                    ),
                                    child: const Icon(Icons.warehouse_outlined, size: 52, color: _emeraldMedium),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('No storage items found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                  const SizedBox(height: 4),
                                  const Text('Try adjusting your search query or room filter', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: ResponsiveUtils.isMobile(context) ? 2 : ResponsiveUtils.isTablet(context) ? 4 : 6,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: ResponsiveUtils.isMobile(context) ? 1.2 : 1.25,
                                ),
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];
                                  final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                                  final stockColor = _getStockStatusColor(quantity);
                                  final stockIcon = _getStockStatusIcon(quantity);
                                  final stockLabel = _getStockStatus(quantity);
                                  final category = item['category']?.toString() ?? '';
                                  final storageRoom = item['storage_room']?.toString() ?? 'Unassigned';

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Top status accent stripe
                                          Container(
                                            height: 4,
                                            color: stockColor,
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          item['name'] ?? 'Unknown',
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w800,
                                                            color: Color(0xFF0F172A),
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Container(
                                                        padding: const EdgeInsets.all(4),
                                                        decoration: BoxDecoration(
                                                          color: stockColor.withValues(alpha: 0.12),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Icon(stockIcon, color: stockColor, size: 14),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.room_rounded, size: 11, color: Color(0xFF94A3B8)),
                                                      const SizedBox(width: 3),
                                                      Expanded(
                                                        child: Text(
                                                          storageRoom,
                                                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (category.isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF1F5F9),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        category,
                                                        style: const TextStyle(fontSize: 9, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                  ],
                                                  const Spacer(),
                                                  // Quantity block
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: stockColor.withValues(alpha: 0.08),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: stockColor.withValues(alpha: 0.25)),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          stockLabel,
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.w800,
                                                            color: stockColor,
                                                          ),
                                                        ),
                                                        Text(
                                                          '$quantity ${item['unit']?.toString().trim() ?? 'pcs'}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w900,
                                                            color: stockColor,
                                                          ),
                                                        ),
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
                                },
                              ),
                            ),
            ),
          ],
        );
      },
    );
  }

  Widget _statBadge(String label, Color bg, Color fg, {Color? border}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _buildPettyCashTab() {
    return Column(
      children: [
        // ── Unified Obsidian Emerald Header ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_obsidianDark, _emeraldDeep],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _goldAccent.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: _obsidianDark.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _goldAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _goldAccent.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: _goldAccent, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Petty Cash Purchases',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Purchases pending transfer into storage inventory',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _goldAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _goldAccent.withValues(alpha: 0.6)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pending_actions_rounded, size: 12, color: _goldAccent),
                    SizedBox(width: 4),
                    Text(
                      'PENDING',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _goldAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Search bar ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: TextField(
            onChanged: (v) => setState(() { _pettyCashSearchQuery = v; _pettyCashCurrentPage = 1; }),
            decoration: InputDecoration(
              hintText: 'Search petty cash items or suppliers...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _emeraldMedium, size: 22),
              suffixIcon: _pettyCashSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                      onPressed: () => setState(() { _pettyCashSearchQuery = ''; _pettyCashCurrentPage = 1; }),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _emeraldMedium, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        // ── Transactions ──
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('stock_transactions')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _emeraldMedium));
              }

              final transactions = snapshot.data ?? [];
              final pettyCashTransactions = transactions
                  .where((t) => t['transaction_type'] == 'incoming' && t['purpose'] == 'Petty Cash Purchase')
                  .toList();

              if (pettyCashTransactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _emeraldDeep.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: _emeraldDeep.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined, size: 52, color: _emeraldMedium),
                      ),
                      const SizedBox(height: 16),
                      const Text('No pending petty cash purchases', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      const Text('Items purchased via petty cash will appear here for storage transfer', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                );
              }

              final filteredTransactions = _pettyCashSearchQuery.isEmpty
                  ? pettyCashTransactions
                  : pettyCashTransactions.where((t) {
                      final q = _pettyCashSearchQuery.toLowerCase();
                      return (t['item_name']?.toString() ?? '').toLowerCase().contains(q) ||
                          (t['supplier']?.toString() ?? '').toLowerCase().contains(q);
                    }).toList();

              final startIndex = (_pettyCashCurrentPage - 1) * _pettyCashItemsPerPage;
              final endIndex = startIndex + _pettyCashItemsPerPage;
              final paginatedTransactions = filteredTransactions.skip(startIndex).take(_pettyCashItemsPerPage).toList();

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: paginatedTransactions.length,
                      itemBuilder: (context, index) {
                        final t = paginatedTransactions[index];
                        final itemName = t['item_name']?.toString() ?? 'Unknown';
                        final qty = t['quantity']?.toString() ?? '0';
                        final unit = t['unit']?.toString() ?? 'pcs';
                        final supplier = t['supplier']?.toString() ?? 'Unknown';
                        final processedBy = t['processed_by']?.toString() ?? 'Unknown';
                        String timeStr = '';
                        try {
                          final dt = DateTime.parse(t['created_at'] as String).toLocal();
                          final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
                          final m = dt.minute.toString().padLeft(2, '0');
                          final ap = dt.hour >= 12 ? 'PM' : 'AM';
                          timeStr = '${dt.month}/${dt.day}/${dt.year}  $h:$m $ap';
                        } catch (_) {}

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Left accent bar
                                  Container(width: 5, color: _emeraldMedium),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Top row: name + badge
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  itemName,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: _emeraldDeep.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: _emeraldDeep.withValues(alpha: 0.25)),
                                                ),
                                                child: const Text(
                                                  'Petty Cash',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _emeraldDeep),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // Qty + Supplier row
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _emeraldMedium.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: _emeraldMedium.withValues(alpha: 0.25)),
                                                ),
                                                child: Text(
                                                  '$qty $unit',
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _emeraldMedium),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              const Icon(Icons.business_rounded, size: 14, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  supplier,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // Processed by + timestamp
                                          Row(
                                            children: [
                                              const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  processedBy,
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  timeStr,
                                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          // Unified Action Button
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () async {
                                                await _processPettyCashToStorage(
                                                  itemName,
                                                  t['quantity'] as int? ?? 0,
                                                  unit,
                                                  supplier,
                                                  t['id']?.toString() ?? '',
                                                );
                                              },
                                              icon: const Icon(Icons.add_to_photos_rounded, size: 17, color: _goldAccent),
                                              label: const Text(
                                                'Add to Storage Room',
                                                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _emeraldDeep,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                elevation: 2,
                                                shadowColor: _emeraldDeep.withValues(alpha: 0.3),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Pagination
                  if (filteredTransactions.length > _pettyCashItemsPerPage)
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _pettyCashCurrentPage > 1
                                ? () => setState(() => _pettyCashCurrentPage--)
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _emeraldDeep.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _emeraldDeep.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              'Page $_pettyCashCurrentPage',
                              style: const TextStyle(color: _emeraldDeep, fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                          IconButton(
                            onPressed: endIndex < filteredTransactions.length
                                ? () => setState(() => _pettyCashCurrentPage++)
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                ],
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
        // ── Unified Obsidian Emerald Header ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_obsidianDark, _emeraldDeep],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _goldAccent.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: _obsidianDark.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _goldAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _goldAccent.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: _goldAccent, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incoming Stock',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Track and log all supplier deliveries & DRs',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showBulkReplenishDialog,
                icon: const Icon(Icons.add_rounded, size: 18, color: _obsidianDark),
                label: const Text(
                  'New Delivery',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _obsidianDark),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _goldAccent,
                  foregroundColor: _obsidianDark,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),

        // ── Search bar ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: TextField(
            onChanged: (v) => setState(() { _incomingSearchQuery = v; _incomingCurrentPage = 1; }),
            decoration: InputDecoration(
              hintText: 'Search by DR Number or Date...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _emeraldMedium, size: 22),
              suffixIcon: _incomingSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                      onPressed: () => setState(() { _incomingSearchQuery = ''; _incomingCurrentPage = 1; }),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _emeraldMedium, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        // ── Delivery list ──
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('stock_transactions')
                .stream(primaryKey: ['id'])
                .eq('transaction_type', 'incoming')
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _emeraldMedium));
              }

              final transactions = snapshot.data ?? [];
              final filteredTransactions = transactions
                  .where((t) => t['purpose'] != 'Petty Cash Purchase')
                  .toList();

              if (filteredTransactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _emeraldDeep.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: _emeraldDeep.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.local_shipping_outlined, size: 52, color: _emeraldMedium),
                      ),
                      const SizedBox(height: 16),
                      const Text('No incoming deliveries logged', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      const Text('Tap "New Delivery" to log stock arrivals with DR receipts', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                );
              }

              // Group by DR Number
              final Map<String, List<Map<String, dynamic>>> groupedTransactions = {};
              for (final transaction in filteredTransactions) {
                final purpose = transaction['purpose']?.toString() ?? '';
                final drNumber = purpose.startsWith('DR: ') ? purpose.substring(4) : transaction['id'].toString();
                groupedTransactions.putIfAbsent(drNumber, () => []).add(transaction);
              }

              List<String> filteredDrNumbers;
              if (_incomingSearchQuery.isEmpty) {
                filteredDrNumbers = groupedTransactions.keys.toList();
              } else {
                final q = _incomingSearchQuery.toLowerCase();
                filteredDrNumbers = groupedTransactions.keys.where((dr) {
                  final date = _formatExactDate(groupedTransactions[dr]!.first['created_at']).toLowerCase();
                  return dr.toLowerCase().contains(q) || date.contains(q);
                }).toList();
              }

              return ListView.builder(
                padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 10 : 16),
                itemCount: filteredDrNumbers.length,
                itemBuilder: (context, index) {
                  final drNumber = filteredDrNumbers[index];
                  final drTransactions = groupedTransactions[drNumber]!;
                  return _IncomingDeliveryItem(
                    drNumber: drNumber,
                    drTransactions: drTransactions,
                    itemCount: drTransactions.length,
                    firstTransaction: drTransactions.first,
                    onTap: () => _showDeliveryDetailsModal(drNumber, drTransactions),
                    formatDate: _formatExactDate,
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
    if (quantity == 0) return const Color(0xFFEF4444);
    if (quantity < 10) return const Color(0xFFF59E0B);
    if (quantity < 50) return const Color(0xFF3B82F6);
    return const Color(0xFF10B981);
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
    final receiver = widget.firstTransaction['processed_by']?.toString();
    final dateStr = widget.formatDate(widget.firstTransaction['created_at']);
    final itemCount = widget.itemCount;

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered ? const Color(0xFF163E37) : const Color(0xFFE2E8F0),
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? const Color(0xFF133831).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: _isHovered ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar
                  Container(width: 5, color: const Color(0xFF133831)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF133831).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF133831), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DR #${widget.drNumber}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE6C374).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFE6C374).withValues(alpha: 0.6)),
                                          ),
                                          child: Text(
                                            '$itemCount item${itemCount > 1 ? 's' : ''}',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF9A7B2C)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      dateStr,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF133831), size: 20),
                                ],
                              ),
                            ],
                          ),
                          if (receiver != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  'Received by: $receiver',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
  final bool showDropdownIcon;

  const _CustomSearchDropdown({
    required this.label,
    required this.icon,
    this.hintText,
    required this.controller,
    required this.items,
    this.onChanged,
    this.showDropdownIcon = true,
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
    _filteredItems = List.from(widget.items);
  }
  
  @override
  void didUpdateWidget(_CustomSearchDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _filteredItems = List.from(widget.items);
    }
  }

  void _filter(String query, {bool autoOpen = true}) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      _filteredItems = List.from(widget.items);
    } else {
      _filteredItems = widget.items
          .where((item) => item.toLowerCase().contains(cleanQuery))
          .toList();
    }
    setState(() {});
    
    if (autoOpen) {
      if (_filteredItems.isNotEmpty && !_menuController.isOpen) {
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
          alignmentOffset: const Offset(0, 4),
          style: MenuStyle(
            backgroundColor: WidgetStateProperty.all(Colors.white),
            elevation: WidgetStateProperty.all(10),
            shadowColor: WidgetStateProperty.all(Colors.black.withValues(alpha: 0.18)),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            maximumSize: WidgetStateProperty.all(Size(constraints.maxWidth, 260)),
            minimumSize: WidgetStateProperty.all(Size(constraints.maxWidth, 44)),
          ),
          builder: (context, controller, child) {
            return TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onTap: () {
                _filteredItems = List.from(widget.items);
                setState(() {});
                if (!_menuController.isOpen && _filteredItems.isNotEmpty) {
                  _menuController.open();
                }
              },
              onChanged: (val) {
                _filter(val, autoOpen: true);
                widget.onChanged?.call(val);
              },
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hintText,
                prefixIcon: Icon(widget.icon, color: const Color(0xFFD97706), size: 18),
                suffixIcon: widget.showDropdownIcon ? IconButton(
                  icon: Icon(
                    controller.isOpen ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                    color: const Color(0xFF64748B),
                    size: 22,
                  ),
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      _filteredItems = List.from(widget.items);
                      setState(() {});
                      controller.open();
                      _focusNode.requestFocus();
                    }
                  },
                ) : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                filled: true,
                fillColor: const Color(0xFFFEFDFB),
              ),
            );
          },
          menuChildren: _filteredItems.isEmpty 
              ? [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Text('No options found', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ),
                ]
              : _filteredItems.map((item) {
            return MenuItemButton(
              style: MenuItemButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () {
                widget.controller.text = item;
                widget.onChanged?.call(item);
                _menuController.close();
              },
              child: ConstrainedBox(
                 constraints: BoxConstraints(minWidth: constraints.maxWidth - 28),
                 child: Row(
                   children: [
                     Icon(widget.icon, size: 14, color: const Color(0xFFD97706)),
                     const SizedBox(width: 8),
                     Expanded(
                       child: Text(
                         item,
                         style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                       ),
                     ),
                   ],
                 ),
              ),
            );
          }).toList(),
        );
      }
    );
  }
}

