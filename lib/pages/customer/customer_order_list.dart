// ─────────────────────────────────────────────────────────────────────────────
// customer_order_list.dart
//
// Contains all Pre-order Cart UI widgets for the Customer Dashboard:
//   - showMenuItemSheet()   → slide-up panel with item info + "Add to Order List"
//   - showOrderListModal()  → cart bottom sheet listing selected items
//   - buildCartIcon()       → badged cart icon for the AppBar
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:yang_chow/models/menu_item.dart';
import 'package:yang_chow/services/menu_service.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/widgets/customer/customer_ui_components.dart';

// ─── Cart Icon (with badge) ──────────────────────────────────────────────────

Widget buildCartIcon({
  required Map<String, int> selectedMenuItems,
  required VoidCallback onPressed,
}) {
  final int uniqueItems = selectedMenuItems.length;

  return AnimatedTapScale(
    onTap: onPressed,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
            tooltip: 'Order List',
            onPressed: onPressed,
          ),
        ),
        if (uniqueItems > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.navColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                '$uniqueItems',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
  );
}

// ─── Menu Item Detail Sheet (slide-up, replaces the popup dialog) ────────────

void showMenuItemSheet({
  required BuildContext context,
  required MenuItem item,
  required Map<String, int> selectedMenuItems,
  required VoidCallback onAdded,
  VoidCallback? onCartUpdated,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DishCustomizationSheet(
      item: item,
      selectedMenuItems: selectedMenuItems,
      onAdded: onAdded,
      onCartUpdated: onCartUpdated,
    ),
  );
}

class _DishCustomizationSheet extends StatefulWidget {
  final MenuItem item;
  final Map<String, int> selectedMenuItems;
  final VoidCallback onAdded;
  final VoidCallback? onCartUpdated;

  const _DishCustomizationSheet({
    Key? key,
    required this.item,
    required this.selectedMenuItems,
    required this.onAdded,
    this.onCartUpdated,
  }) : super(key: key);

  @override
  State<_DishCustomizationSheet> createState() => _DishCustomizationSheetState();
}

class _DishCustomizationSheetState extends State<_DishCustomizationSheet> {
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');
  int _quantity = 1;

  double get _totalPrice => widget.item.price * _quantity;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = MenuService.resolveImageUrl(
      widget.item.customImagePath ?? widget.item.fallbackImagePath,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // ── Scrollable Dish Info Content ──────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Banner with Floating Badges
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                height: 210,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _imagePlaceholder(),
                              )
                            : _imagePlaceholder(),
                        // Gradient Overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.1),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.55),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Category Tag
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14332E).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD9A441).withOpacity(0.6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFD9A441), size: 13),
                                const SizedBox(width: 5),
                                Text(
                                  widget.item.category.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFD9A441),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Close Button
                        Positioned(
                          top: 10,
                          right: 10,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Item Name & Exact Database Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.name,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                            ),
                            if (widget.item.description != null && widget.item.description!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                widget.item.description!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14332E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD9A441).withOpacity(0.5)),
                        ),
                        child: Text(
                          '₱${_fmt.format(widget.item.price)}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFD9A441),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Sticky Bottom Action Bar with Quantity Stepper & Price ────────
          Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Quantity Counter
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, size: 18),
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                        color: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        constraints: const BoxConstraints(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$_quantity',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        onPressed: () => setState(() => _quantity++),
                        color: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Add to Cart Button with Computed Price
                Expanded(
                  child: AnimatedTapScale(
                    onTap: () {
                      Navigator.pop(context);
                      final itemName = widget.item.name;
                      widget.selectedMenuItems[itemName] = (widget.selectedMenuItems[itemName] ?? 0) + _quantity;
                      widget.onCartUpdated?.call();
                      widget.onAdded();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF86EFAC), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Added $_quantity x ${widget.item.name} • ₱${_fmt.format(_totalPrice)}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF14332E),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF14332E).withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFFD9A441), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Add to Order • ₱${_fmt.format(_totalPrice)}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
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

// ─── Order List (Cart) Modal ─────────────────────────────────────────────────

class CustomerOrderListPage extends StatefulWidget {
  final Map<String, int> selectedMenuItems;
  /// Called once the customer finishes the Order Type Sheet.
  /// [items]            – the checked cart subset
  /// [reservationType]  – 'Event Place' | 'Advance Order'
  /// [advanceOrderType] – 'Dine In' | 'Pick Up'  (only relevant for Advance Order)
  /// [date]             – formatted 'MMMM d, yyyy'
  /// [time]             – formatted 'h:mm AM/PM'
  final void Function(
    Map<String, int> items,
    String reservationType,
    String advanceOrderType,
    String date,
    String time,
  ) onProceed;
  final VoidCallback? onCartUpdated;

  const CustomerOrderListPage({
    Key? key,
    required this.selectedMenuItems,
    required this.onProceed,
    this.onCartUpdated,
  }) : super(key: key);

  @override
  State<CustomerOrderListPage> createState() => _CustomerOrderListPageState();
}

class _CustomerOrderListPageState extends State<CustomerOrderListPage> {
  late Set<String> _checkedItems;
  late Map<String, List<MenuItem>> allMenu;
  late List<MenuItem> flatMenu;
  final NumberFormat fmt = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _checkedItems = Set<String>.from(widget.selectedMenuItems.keys);
    allMenu = MenuService.getMenu();
    flatMenu = allMenu.values.expand((e) => e).toList();

    // ── Backward Compatibility Migration ──
    bool needsUpdate = false;
    final migratedItems = <String, int>{};
    
    for (final entry in widget.selectedMenuItems.entries) {
      if (flatMenu.any((e) => e.name == entry.key)) {
        migratedItems[entry.key] = (migratedItems[entry.key] ?? 0) + entry.value;
      } else {
        try {
          final item = flatMenu.firstWhere((e) => e.id == entry.key);
          migratedItems[item.name] = (migratedItems[item.name] ?? 0) + entry.value;
          needsUpdate = true;
        } catch (_) {
          needsUpdate = true;
        }
      }
    }

    if (needsUpdate) {
      widget.selectedMenuItems.clear();
      widget.selectedMenuItems.addAll(migratedItems);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCartUpdated?.call();
      });
    }
  }

  double get _totalPrice {
    double total = 0.0;
    widget.selectedMenuItems.forEach((itemName, qty) {
      if (_checkedItems.contains(itemName)) {
        final match = flatMenu.where((e) => e.name == itemName);
        if (match.isNotEmpty) {
          total += match.first.price * qty;
        }
      }
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.navColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Your Order List',
          style: GoogleFonts.lora(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: widget.selectedMenuItems.isEmpty
          ? Center(
              child: EmptyStateCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Your order list is empty',
                description: 'Browse our menu items and add your favorite dishes to get started.',
                buttonText: 'Browse Menu',
                onButtonPressed: () => Navigator.pop(context),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              itemCount: widget.selectedMenuItems.length,
              itemBuilder: (context, index) {
                final itemName = widget.selectedMenuItems.keys.elementAt(index);
                final qty = widget.selectedMenuItems[itemName] ?? 0;

                MenuItem? cartItem;
                try {
                  cartItem = flatMenu.firstWhere((e) => e.name == itemName);
                } catch (_) {
                  return const SizedBox.shrink();
                }

                final imgUrl = MenuService.resolveImageUrl(
                  cartItem.customImagePath ?? cartItem.fallbackImagePath,
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.cardBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Dark Green Card Header with checkbox ──
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: AppTheme.forestGreen,
                          child: Row(
                            children: [
                              Transform.scale(
                                scale: 1.1,
                                child: Checkbox(
                                  value: _checkedItems.contains(itemName),
                                  activeColor: AppTheme.warmGold,
                                  checkColor: AppTheme.darkBrownText,
                                  side: const BorderSide(color: Colors.white54, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        _checkedItems.add(itemName);
                                      } else {
                                        _checkedItems.remove(itemName);
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                cartItem.category.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.warmGold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const Spacer(),
                              // Gold price badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.warmGold,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '₱${fmt.format(cartItem.price * qty)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.darkBrownText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Card Body ──
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // Food image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: imgUrl.isNotEmpty
                                      ? Image.network(imgUrl, fit: BoxFit.cover)
                                      : Container(
                                          color: AppTheme.lightGrey,
                                          child: const Icon(Icons.restaurant, color: Colors.grey),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Name + unit price
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cartItem.name,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppTheme.darkGrey,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '₱${fmt.format(cartItem.price)} each',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.mediumGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ── +/− stepper ──
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _stepperButton(
                                    icon: qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                    color: qty <= 1 ? AppTheme.errorRed : AppTheme.forestGreen,
                                    onTap: () {
                                      setState(() {
                                        if (qty <= 1) {
                                          widget.selectedMenuItems.remove(itemName);
                                          _checkedItems.remove(itemName);
                                        } else {
                                          widget.selectedMenuItems[itemName] = qty - 1;
                                        }
                                      });
                                      widget.onCartUpdated?.call();
                                    },
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.forestGreen.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.forestGreen.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      '$qty',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.forestGreen,
                                      ),
                                    ),
                                  ),
                                  _stepperButton(
                                    icon: Icons.add_rounded,
                                    color: AppTheme.forestGreen,
                                    onTap: () {
                                      setState(() {
                                        widget.selectedMenuItems[itemName] = qty + 1;
                                      });
                                      widget.onCartUpdated?.call();
                                    },
                                  ),
                                ],
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
      bottomNavigationBar: widget.selectedMenuItems.isNotEmpty
          ? Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Summary row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESTIMATED TOTAL',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.mediumGrey,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${fmt.format(_totalPrice)}',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.forestGreen,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ITEMS SELECTED',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.mediumGrey,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.warmGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.warmGold.withOpacity(0.5)),
                            ),
                            child: Text(
                              '${_checkedItems.length} / ${widget.selectedMenuItems.length}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.darkBrownText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // CTA Button
                  AnimatedTapScale(
                    onTap: () {
                      if (_checkedItems.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please select at least one item to proceed.',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                        return;
                      }

                      final Map<String, int> selectedSubset = {};
                      for (var key in _checkedItems) {
                        if (widget.selectedMenuItems.containsKey(key)) {
                          selectedSubset[key] = widget.selectedMenuItems[key]!;
                        }
                      }

                      // Open Order Type Sheet instead of proceeding directly
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _OrderTypeSheet(
                          cartItems: selectedSubset,
                          parentCart: widget.selectedMenuItems,
                          onCartUpdated: widget.onCartUpdated,
                          onConfirm: widget.onProceed,
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppTheme.forestGreen,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.forestGreen.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.event_available_rounded, color: AppTheme.warmGold, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Proceed to Reservation type',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_rounded, color: AppTheme.warmGold, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

// ─── Internal helpers ────────────────────────────────────────────────────────

Widget _imagePlaceholder() => Container(
      height: 240,
      color: const Color(0xFFF5F5F5),
      child: const Center(child: Icon(Icons.fastfood_rounded, size: 72, color: Colors.grey)),
    );

Widget _stepperButton({
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return AnimatedTapScale(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    ),
  );
}

// ─── Order Type Sheet ─────────────────────────────────────────────────────────
// Shown when customer taps "Proceed to Checkout" in the cart.
// Asks: Event Place or Advance Order? Dine In or Pick Up? Date? Time?
// On confirm, calls onConfirm with all scheduling details.

class _OrderTypeSheet extends StatefulWidget {
  final Map<String, int> cartItems;
  final Map<String, int>? parentCart;
  final VoidCallback? onCartUpdated;
  final void Function(
    Map<String, int> items,
    String reservationType,
    String advanceOrderType,
    String date,
    String time,
  ) onConfirm;

  const _OrderTypeSheet({
    required this.cartItems,
    this.parentCart,
    this.onCartUpdated,
    required this.onConfirm,
  });

  @override
  State<_OrderTypeSheet> createState() => _OrderTypeSheetState();
}

class _OrderTypeSheetState extends State<_OrderTypeSheet> {
  String _reservationType = 'Advance Order'; // 'Advance Order' | 'Event Place'
  String _advanceOrderType = 'Dine In';      // 'Dine In' | 'Pick Up'

  void _confirm() {
    if (widget.parentCart != null) {
      for (final key in widget.cartItems.keys) {
        widget.parentCart!.remove(key);
      }
      widget.onCartUpdated?.call();
    }
    Navigator.pop(context); // close sheet
    Navigator.pop(context); // close cart page
    widget.onConfirm(
      widget.cartItems,
      _reservationType,
      _advanceOrderType,
      '', // date set on reservation page
      '', // time set on reservation page
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 380;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final int totalSteps = _reservationType == 'Advance Order' ? 2 : 1;
    final int currentStep = _reservationType == 'Advance Order' ? 2 : 1;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle ────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 2),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C241F),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('📝', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Up Your Order',
                        style: GoogleFonts.inter(
                          fontSize: isSmall ? 17 : 19,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tell us how you want your order handled',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Step pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C241F).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Step $currentStep / $totalSteps',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0C241F),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Row(
              children: List.generate(totalSteps, (i) {
                final active = i < currentStep;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
                    height: 3,
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF0C241F) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 4),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1, height: 20),

          // ── Body ────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── STEP 1: ORDER TYPE ───────────────────────────────
                  _sectionLabel('1. What type of order?'),
                  const SizedBox(height: 10),
                  _selectionRow(
                    options: [
                      _OptionData(
                        emoji: '🛍️',
                        label: 'Advance Order',
                        description: 'Pre-order food for dine-in or pick-up',
                        value: 'Advance Order',
                      ),
                      _OptionData(
                        emoji: '🎉',
                        label: 'Event Place',
                        description: 'Book a venue for a special occasion',
                        value: 'Event Place',
                      ),
                    ],
                    selected: _reservationType,
                    onSelect: (v) => setState(() => _reservationType = v),
                  ),

                  // ── STEP 2: ORDER MODE (Advance Order only) ─────────────
                  if (_reservationType == 'Advance Order') ...[
                    const SizedBox(height: 20),
                    _sectionLabel('2. How will you receive it?'),
                    const SizedBox(height: 10),
                    _selectionRow(
                      options: [
                        _OptionData(
                          emoji: '🍽️',
                          label: 'Dine In',
                          description: 'Eat at the restaurant with table service',
                          value: 'Dine In',
                        ),
                        _OptionData(
                          emoji: '🥡',
                          label: 'Pick Up',
                          description: 'We\'ll have it ready when you arrive',
                          value: 'Pick Up',
                        ),
                      ],
                      selected: _advanceOrderType,
                      onSelect: (v) => setState(() => _advanceOrderType = v),
                    ),
                  ],

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Confirm Button ───────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 20),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            ),
            child: AnimatedTapScale(
              onTap: _confirm,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C241F),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0C241F).withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFFD9A441), size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper: Section label ───────────────────────────────────────────────

  Widget _sectionLabel(String label) => Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF374151),
          letterSpacing: 0.1,
        ),
      );

  // ── Helper: Selection row ─────────────────────────────────────────────

  Widget _selectionRow({
    required List<_OptionData> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Column(
      children: options.map((opt) {
        final isSelected = selected == opt.value;
        return GestureDetector(
          onTap: () => onSelect(opt.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0C241F) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFFD9A441) : const Color(0xFFE5E7EB),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0C241F).withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Emoji container
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.10)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(opt.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt.label,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFF111827),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        opt.description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.55)
                              : const Color(0xFF6B7280),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Radio indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFFD9A441) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? const Color(0xFFD9A441) : const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Option Data Model ──────────────────────────────────────────────────
class _OptionData {
  final String emoji;
  final String label;
  final String description;
  final String value;

  const _OptionData({
    required this.emoji,
    required this.label,
    required this.description,
    required this.value,
  });
}


