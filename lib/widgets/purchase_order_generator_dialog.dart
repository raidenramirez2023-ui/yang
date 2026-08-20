import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yang_chow/pages/staff/inventory_room_page.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class PurchaseOrderGeneratorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> criticalItems;
  final String? initialSupplier;
  final VoidCallback? onGoToStorageRoom;

  const PurchaseOrderGeneratorDialog({
    super.key,
    required this.criticalItems,
    this.initialSupplier,
    this.onGoToStorageRoom,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Map<String, dynamic>> criticalItems,
    String? initialSupplier,
    VoidCallback? onGoToStorageRoom,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PurchaseOrderGeneratorDialog(
        criticalItems: criticalItems,
        initialSupplier: initialSupplier,
        onGoToStorageRoom: onGoToStorageRoom,
      ),
    );
  }

  @override
  State<PurchaseOrderGeneratorDialog> createState() => _PurchaseOrderGeneratorDialogState();
}

class _PurchaseOrderGeneratorDialogState extends State<PurchaseOrderGeneratorDialog> {
  late String _poNumber;
  late DateTime _poDate;
  String _selectedSupplier = 'All';
  final TextEditingController _deliveryTargetController = TextEditingController(text: 'Tomorrow Morning (8:00 AM)');

  // Map of Supplier -> List of items with editable order qty controllers
  final Map<String, List<Map<String, dynamic>>> _supplierGroupedItems = {};
  final Map<String, TextEditingController> _qtyControllers = {};
  final Set<String> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _poDate = DateTime.now();
    _poNumber = 'PO-${DateFormat('yyyyMMdd').format(_poDate)}-${(_poDate.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}';
    _initializeItems();
  }

  @override
  void dispose() {
    _deliveryTargetController.dispose();
    for (var ctrl in _qtyControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _initializeItems() {
    _supplierGroupedItems.clear();
    _qtyControllers.clear();
    _selectedItemIds.clear();

    for (var item in widget.criticalItems) {
      final id = (item['id'] ?? item['name'] ?? DateTime.now().millisecondsSinceEpoch).toString();
      final supplier = _resolveSupplier(item);
      final curQty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final unit = (item['unit'] ?? 'units').toString();

      // Recommended restock quantity
      double recommendedQty = _calculateRecommendedQty(curQty, unit);

      final ctrl = TextEditingController(
        text: recommendedQty.truncateToDouble() == recommendedQty
            ? recommendedQty.toInt().toString()
            : recommendedQty.toStringAsFixed(1),
      );

      _qtyControllers[id] = ctrl;
      _selectedItemIds.add(id);

      _supplierGroupedItems.putIfAbsent(supplier, () => []).add({
        ...item,
        '_id': id,
        '_supplier': supplier,
      });
    }

    if (widget.initialSupplier != null && _supplierGroupedItems.containsKey(widget.initialSupplier)) {
      _selectedSupplier = widget.initialSupplier!;
    } else if (_supplierGroupedItems.length == 1) {
      // Auto-detect and auto-select the single dominant supplier!
      _selectedSupplier = _supplierGroupedItems.keys.first;
    } else {
      _selectedSupplier = 'All';
    }
  }

  String _resolveSupplier(Map<String, dynamic> item) {
    final sup = item['supplier']?.toString().trim();
    if (sup != null && sup.isNotEmpty && sup.toLowerCase() != 'unknown' && sup.toLowerCase() != 'null') {
      return sup;
    }

    final cat = (item['category'] ?? '').toString().toLowerCase();
    final name = (item['name'] ?? '').toString().toLowerCase();

    if (cat.contains('meat') || cat.contains('roasting') || name.contains('chicken') || name.contains('pork') || name.contains('beef') || name.contains('patatim') || name.contains('duck')) {
      return 'Poultry & Meat Supplier';
    }
    if (cat.contains('seafood') || name.contains('fish') || name.contains('shrimp') || name.contains('squid')) {
      return 'Seafood & Fish Dealer';
    }
    if (cat.contains('fresh') || cat.contains('veg') || name.contains('onion') || name.contains('garlic') || name.contains('egg') || name.contains('cabbage') || name.contains('tomato')) {
      return 'Public Market / Fresh Produce';
    }
    if (cat.contains('drink') || cat.contains('beverage') || name.contains('7up') || name.contains('coke') || name.contains('royal') || name.contains('sprite')) {
      return 'Beverage Distributor';
    }
    if (cat.contains('packaging') || name.contains('box') || name.contains('cup') || name.contains('plastic')) {
      return 'Packaging & Supplies';
    }

    return 'Metro Wholesale Groceries';
  }

  double _calculateRecommendedQty(double currentStock, String unit) {
    final u = unit.toLowerCase();
    if (u.contains('can') || u.contains('bot') || u.contains('bottle') || u.contains('pack')) {
      return currentStock <= 0 ? 12.0 : 6.0;
    }
    if (u.contains('kilo') || u.contains('kg')) {
      return currentStock <= 0 ? 20.0 : 10.0;
    }
    if (u.contains('pc') || u.contains('piece')) {
      return currentStock <= 0 ? 100.0 : 50.0;
    }
    if (u.contains('gram') || u.contains('g')) {
      return currentStock <= 0 ? 1000.0 : 500.0;
    }
    return currentStock <= 0 ? 10.0 : 5.0;
  }

  List<Map<String, dynamic>> get _activeDisplayedItems {
    if (_selectedSupplier == 'All') {
      final List<Map<String, dynamic>> all = [];
      for (var list in _supplierGroupedItems.values) {
        all.addAll(list);
      }
      return all;
    }
    return _supplierGroupedItems[_selectedSupplier] ?? [];
  }

  List<Map<String, dynamic>> get _activeSelectedItems {
    return _activeDisplayedItems.where((i) => _selectedItemIds.contains(i['_id'])).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final displayedItems = _activeDisplayedItems;
    final selectedCount = _activeSelectedItems.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: 720,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.20),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Executive Header ──────────────────────────────────────────
            _buildHeader(),

            // ── Target Delivery Date & Time Bar ──────────────────────────
            _buildTargetDeliveryBar(),

            // ── Supplier Tabs / Filters ──────────────────────────────────
            _buildSupplierSegment(),

            // ── Table / Items List ───────────────────────────────────────
            Expanded(
              child: displayedItems.isEmpty
                  ? _buildEmptySupplier()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: displayedItems.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _buildItemRow(displayedItems[i]),
                    ),
            ),

            // ── Quick Summary & Actions Footer ────────────────────────────
            _buildFooter(selectedCount),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C241F), Color(0xFF143A32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD97706).withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFFFBBF24),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Purchase Order (PO) Generator',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9A441).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFD9A441).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _poNumber,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFDE68A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Auto-grouped low stock items for fast supplier replenishment',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
          splashRadius: 18,
        ),
      ],
    ),
  );
}

Widget _buildTargetDeliveryBar() {
  final isMobile = ResponsiveUtils.isMobile(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: const BoxDecoration(
      color: Color(0xFFF1F5F9),
      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
    ),
    child: isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 15, color: Color(0xFF0C241F)),
                  const SizedBox(width: 6),
                  Text(
                    'Target Delivery:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (picked != null) {
                        setState(() {
                          _deliveryTargetController.text = DateFormat('MMMM d, yyyy (EEEE)').format(picked);
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF0C241F)),
                          const SizedBox(width: 4),
                          Text(
                            'Pick Date',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF0C241F)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _deliveryTargetController,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0C241F),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    hintText: 'e.g. Tomorrow 8:00 AM, ASAP, Friday...',
                  ),
                ),
              ),
            ],
          )
        : Row(
            children: [
              const Icon(Icons.local_shipping_outlined, size: 16, color: Color(0xFF0C241F)),
              const SizedBox(width: 8),
              Text(
                'Target Delivery:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _deliveryTargetController,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0C241F),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      hintText: 'e.g. Tomorrow 8:00 AM, ASAP, Friday...',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) {
                    setState(() {
                      _deliveryTargetController.text = DateFormat('MMMM d, yyyy (EEEE)').format(picked);
                    });
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF0C241F)),
                      const SizedBox(width: 4),
                      Text(
                        'Pick Date',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0C241F)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}

  Widget _buildSupplierSegment() {
    final suppliers = ['All', ..._supplierGroupedItems.keys];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: suppliers.map((sup) {
            final isSel = _selectedSupplier == sup;
            final count = sup == 'All'
                ? widget.criticalItems.length
                : (_supplierGroupedItems[sup]?.length ?? 0);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedSupplier = sup),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF0C241F) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? const Color(0xFF0C241F) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        sup,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFFD9A441)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSel ? const Color(0xFF0C241F) : const Color(0xFF475569),
                          ),
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
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final id = item['_id'] as String;
    final isSelected = _selectedItemIds.contains(id);
    final curQty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
    final unit = (item['unit'] ?? '').toString();
    final supplier = (item['_supplier'] ?? 'General').toString();
    final isOut = curQty <= 0;
    final ctrl = _qtyControllers[id] ?? TextEditingController(text: '10');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? (isOut ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1))
              : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Checkbox toggle
          Checkbox(
            value: isSelected,
            activeColor: const Color(0xFF0C241F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedItemIds.add(id);
                } else {
                  _selectedItemIds.remove(id);
                }
              });
            },
          ),
          const SizedBox(width: 4),

          // Item Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item['name'] ?? 'Unnamed Item',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOut ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isOut ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Text(
                        isOut ? 'OUT OF STOCK' : 'LOW STOCK',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isOut ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Current: ${curQty.toStringAsFixed(curQty.truncateToDouble() == curQty ? 0 : 2)} $unit • Supplier: $supplier',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Order Qty Input Box
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Order Qty:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 75,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySupplier() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 42, color: Color(0xFF10B981)),
            const SizedBox(height: 10),
            Text(
              'No items for this supplier',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(int selectedCount) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(isMobile ? 14 : 20, 12, isMobile ? 14 : 20, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$selectedCount items selected • ${_selectedSupplier == "All" ? "Combined PO" : _selectedSupplier}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Print / System Preview',
                      onPressed: selectedCount == 0 ? null : _printOrExportPO,
                      icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF64748B)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _goToStorageRoom,
                        icon: const Icon(Icons.meeting_room_outlined, size: 14, color: Color(0xFFFBBF24)),
                        label: Text(
                          'Storage',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C241F),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: selectedCount == 0 ? null : _showMessagingOptions,
                        icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                        label: Text(
                          'Send',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: selectedCount == 0 ? null : _downloadPdfDirectly,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: Color(0xFF0C241F)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'PDF',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: const Color(0xFF0C241F),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$selectedCount items selected for order',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Supplier: ${_selectedSupplier == "All" ? "Combined PO" : _selectedSupplier}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // 1. Quick Navigation to Storage Room (Outside main view)
                ElevatedButton.icon(
                  onPressed: _goToStorageRoom,
                  icon: const Icon(Icons.meeting_room_outlined, size: 15, color: Color(0xFFFBBF24)),
                  label: Text(
                    'Go to Storage Room',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C241F),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Send / Share PO (Viber, Messenger, SMS, WhatsApp)
                ElevatedButton.icon(
                  onPressed: selectedCount == 0 ? null : _showMessagingOptions,
                  icon: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
                  label: Text(
                    'Send PO',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Direct Download PDF (Paperless File Save)
                OutlinedButton.icon(
                  onPressed: selectedCount == 0 ? null : _downloadPdfDirectly,
                  icon: const Icon(Icons.download_rounded, size: 15, color: Color(0xFF0C241F)),
                  label: Text(
                    'PDF',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: const Color(0xFF0C241F),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                    side: const BorderSide(color: Color(0xFF0C241F)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 6),

                // 4. Print / System Preview
                IconButton(
                  tooltip: 'Print / System Preview',
                  onPressed: selectedCount == 0 ? null : _printOrExportPO,
                  icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF64748B)),
                ),
              ],
            ),
    );
  }

  // ── Quick Navigation to Storage Room (Outside view, no auto-add) ───────────
  void _goToStorageRoom() {
    Navigator.of(context).pop();

    if (widget.onGoToStorageRoom != null) {
      widget.onGoToStorageRoom!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => const InventoryRoomPage(),
        ),
      );
    }
  }

  // ── Build Clean PO Text for Messaging ──────────────────────────────────────
  String _buildOrderMessageText() {
    final items = _activeSelectedItems;
    if (items.isEmpty) return '';

    final targetSupplier = _selectedSupplier == 'All' ? 'Combined Restaurant Suppliers' : _selectedSupplier;
    final dateStr = DateFormat('MMMM d, yyyy - hh:mm a').format(_poDate);

    final StringBuffer sb = StringBuffer();
    sb.writeln('📋 *PURCHASE ORDER - YANG CHOW RESTAURANT*');
    sb.writeln('📄 *PO Number:* $_poNumber');
    sb.writeln('📅 *Date:* $dateStr');
    sb.writeln('🏢 *Supplier:* $targetSupplier');
    sb.writeln('');
    sb.writeln('🛒 *ITEMS TO DELIVER / RESTOCK:*');

    for (int i = 0; i < items.length; i++) {
      final itm = items[i];
      final id = itm['_id'] as String;
      final name = itm['name'] ?? 'Item';
      final unit = itm['unit'] ?? 'units';
      final orderQty = _qtyControllers[id]?.text.trim() ?? '1';

      sb.writeln('${i + 1}. *$name* ➔ *$orderQty $unit*');
    }

    sb.writeln('');
    final targetDelivery = _deliveryTargetController.text.trim().isEmpty ? 'ASAP / Next Delivery Schedule' : _deliveryTargetController.text.trim();
    sb.writeln('📍 *Delivery Address:* Yang Chow Restaurant, Pagsanjan Branch');
    sb.writeln('⏰ *Target Delivery:* $targetDelivery');
    sb.writeln('Please acknowledge upon receipt. Thank you!');

    return sb.toString();
  }

  // ── Show Messaging & Chat Share Options Modal ──────────────────────────────
  void _showMessagingOptions() {
    final poText = _buildOrderMessageText();
    if (poText.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.send_to_mobile_rounded, color: Color(0xFF16A34A), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send Purchase Order',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Choose an app to send your delivery order',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Option 1: Messenger / Facebook
            _buildShareOptionTile(
              icon: Icons.chat_bubble_rounded,
              iconColor: const Color(0xFF0084FF), // Messenger Blue
              bgColor: const Color(0xFFEFF6FF),
              title: 'Send via Messenger',
              subtitle: 'Copies order & opens Facebook Messenger',
              onTap: () {
                Navigator.pop(ctx);
                _sendViaMessenger(poText);
              },
            ),
            const SizedBox(height: 10),

            // Option 2: Copy to Clipboard
            _buildShareOptionTile(
              icon: Icons.copy_rounded,
              iconColor: const Color(0xFF0C241F),
              bgColor: const Color(0xFFF8FAFC),
              title: 'Copy Text Only',
              subtitle: 'Copy formatted PO text to clipboard',
              onTap: () {
                Navigator.pop(ctx);
                _copyOrderToClipboard();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOptionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: iconColor),
          ],
        ),
      ),
    );
  }

  // ── Individual Share Launchers ─────────────────────────────────────────────
  Future<void> _sendViaMessenger(String poText) async {
    await Clipboard.setData(ClipboardData(text: poText));

    final messengerAppUri = Uri.parse('fb-messenger://');
    final messengerWebUri = Uri.parse('https://www.messenger.com');
    final fbWebUri = Uri.parse('https://www.facebook.com/messages');

    try {
      if (await canLaunchUrl(messengerAppUri)) {
        await launchUrl(messengerAppUri, mode: LaunchMode.externalApplication);
        _showSuccessNotification('PO copied! Opening Facebook Messenger App...');
        return;
      }
    } catch (_) {}

    try {
      final launched = await launchUrl(messengerWebUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(fbWebUri, mode: LaunchMode.externalApplication);
      }
      _showSuccessNotification('PO copied! Opening Messenger in browser to send...');
    } catch (_) {
      try {
        await launchUrl(fbWebUri, mode: LaunchMode.externalApplication);
        _showSuccessNotification('PO copied! Opening Facebook Messages...');
      } catch (e) {
        _showSuccessNotification('Purchase Order copied to clipboard! Paste directly in Messenger.');
      }
    }
  }

  void _copyOrderToClipboard() {
    final text = _buildOrderMessageText();
    if (text.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text));
    _showSuccessNotification('Purchase Order copied to clipboard! Ready to paste.');
  }

  void _showSuccessNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF0C241F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build PDF Document Object ──────────────────────────────────────────────
  pw.Document _generatePdfDocument() {
    final items = _activeSelectedItems;
    final targetSupplier = _selectedSupplier == 'All' ? 'Combined Suppliers' : _selectedSupplier;
    final dateStr = DateFormat('MMMM d, yyyy - hh:mm a').format(_poDate);
    final targetDelivery = _deliveryTargetController.text.trim().isEmpty ? 'ASAP / Next Delivery Schedule' : _deliveryTargetController.text.trim();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'YANG CHOW RESTAURANT',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0C241F')),
                      ),
                      pw.Text(
                        'Pagsanjan Branch • Inventory & Procurement',
                        style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('64748B')),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('0C241F'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'PURCHASE ORDER',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('PO #: $_poNumber', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColor.fromHex('CBD5E1')),
              pw.SizedBox(height: 10),

              // Supplier & Order Info (Super Clean, No Prepared By)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('F8FAFC'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColor.fromHex('E2E8F0')),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('SUPPLIER / VENDOR:', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                            pw.Text(targetSupplier, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('DELIVERY LOCATION:', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Yang Chow Restaurant (Pagsanjan Branch)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('F1F5F9'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text('TARGET DELIVERY: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0C241F'))),
                          pw.Text(targetDelivery, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('D97706'))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Table Header (Item Name and Order Qty only for super-clean OCR scanning)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('0C241F'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 1, child: pw.Text('#', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 6, child: pw.Text('Item Description', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 3, child: pw.Text('Order Qty & Unit', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              // Table Rows
              ...items.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final itm = entry.value;
                final id = itm['_id'] as String;
                final unit = (itm['unit'] ?? '').toString();
                final orderQty = _qtyControllers[id]?.text.trim() ?? '1';
                final isEven = entry.key % 2 == 0;

                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: isEven ? PdfColor.fromHex('FFFFFF') : PdfColor.fromHex('F8FAFC'),
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('E2E8F0'), width: 0.5)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 1, child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(
                        flex: 6,
                        child: pw.Text(
                          itm['name'] ?? '',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0F172A')),
                        ),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          '$orderQty $unit',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0C241F')),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.Spacer(),

              // Signatures & Notes
              pw.Divider(thickness: 1, color: PdfColor.fromHex('CBD5E1')),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Official Purchase Order - Yang Chow Restaurant', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Supplier Received & Acknowledged By:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.SizedBox(height: 20),
                      pw.Container(width: 160, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 3),
                      pw.Text('Signature over Printed Name', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  // ── Download PDF Directly (No Printer Needed) ──────────────────────────────
  Future<void> _downloadPdfDirectly() async {
    final items = _activeSelectedItems;
    if (items.isEmpty) return;

    final targetSupplier = _selectedSupplier == 'All' ? 'Combined_Suppliers' : _selectedSupplier.replaceAll(' ', '_');
    final pdf = _generatePdfDocument();
    final bytes = await pdf.save();

    final filename = '${_poNumber}_$targetSupplier.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.file_download_done_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('PDF ($filename) ready! You can send it directly to your supplier.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0C241F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Print or Export Official Restaurant PDF Slip ───────────────────────────
  Future<void> _printOrExportPO() async {
    final items = _activeSelectedItems;
    if (items.isEmpty) return;

    final targetSupplier = _selectedSupplier == 'All' ? 'Combined Suppliers' : _selectedSupplier;
    final pdf = _generatePdfDocument();

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${_poNumber}_${targetSupplier.replaceAll(' ', '_')}.pdf',
    );
  }
}
