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
import 'package:yang_chow/utils/app_constants.dart';

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
  final String imageUrl = MenuService.resolveImageUrl(item.customImagePath ?? item.fallbackImagePath);
  final NumberFormat fmt = NumberFormat('#,##0.00', 'en_US');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // ── Food image banner ──────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 240,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),

            // ── Info section ─────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkGrey,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.accentOrange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.category,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Description
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      Text(
                        item.description!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF666666),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Divider(height: 24, thickness: 1),

                    // Price row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Price per item',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppTheme.mediumGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '₱${fmt.format(item.price)}',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
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

            // ── Add to Order List button ─────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(ctx).padding.bottom + 16),
              child: AnimatedTapScale(
                onTap: () {
                  Navigator.pop(ctx);
                  final itemName = item.name;
                  selectedMenuItems[itemName] = (selectedMenuItems[itemName] ?? 0) + 1;
                  onCartUpdated?.call();
                  onAdded();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${item.name} added to your order list!',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: AppTheme.successGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Add to Order List',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
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
  final void Function(
    Map<String, int> items,
    String reservationType,
    String advanceOrderType,
    String date,
    String time,
  ) onConfirm;

  const _OrderTypeSheet({
    required this.cartItems,
    required this.onConfirm,
  });

  @override
  State<_OrderTypeSheet> createState() => _OrderTypeSheetState();
}

class _OrderTypeSheetState extends State<_OrderTypeSheet> {
  String _reservationType = 'Advance Order'; // 'Advance Order' | 'Event Place'
  String _advanceOrderType = 'Dine In';      // 'Dine In' | 'Pick Up'

  void _confirm() {
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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 44, height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            decoration: BoxDecoration(
              color: AppTheme.navColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_available_rounded, color: AppTheme.warmGold, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Set Up Your Order',
                      style: GoogleFonts.lora(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose your preferred reservation type ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Step 1: Order Type ──────────────────────────────────────
                  _sectionLabel('ORDER TYPE'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _typeCard(
                          icon: Icons.shopping_bag_outlined,
                          label: 'Advance Order',
                          subtitle: 'Dine in or pick up',
                          selected: _reservationType == 'Advance Order',
                          onTap: () => setState(() => _reservationType = 'Advance Order'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _typeCard(
                          icon: Icons.celebration_rounded,
                          label: 'Event Place',
                          subtitle: 'Reserve a venue',
                          selected: _reservationType == 'Event Place',
                          onTap: () => setState(() => _reservationType = 'Event Place'),
                        ),
                      ),
                    ],
                  ),

                  // ── Step 2: Advance Order sub-type ─────────────────────────
                  if (_reservationType == 'Advance Order') ...[
                    const SizedBox(height: 24),
                    _sectionLabel('ORDER MODE'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _typeCard(
                            icon: Icons.restaurant_rounded,
                            label: 'Dine In',
                            subtitle: 'Eat at the restaurant',
                            selected: _advanceOrderType == 'Dine In',
                            onTap: () => setState(() => _advanceOrderType = 'Dine In'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _typeCard(
                            icon: Icons.shopping_bag_rounded,
                            label: 'Pick Up',
                            subtitle: 'Take your order away',
                            selected: _advanceOrderType == 'Pick Up',
                            onTap: () => setState(() => _advanceOrderType = 'Pick Up'),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Confirm Button ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 20),
            child: AnimatedTapScale(
              onTap: _confirm,
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
                    const Icon(Icons.check_circle_rounded, color: AppTheme.warmGold, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Confirm Order Setup',
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
          ),
        ],
      ),
    );
  }

  // ── Helper widgets ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.mediumGrey,
          letterSpacing: 1.2,
        ),
      );

  Widget _typeCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.forestGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.forestGreen : AppTheme.cardBorder,
            width: selected ? 2 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.forestGreen.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: selected ? AppTheme.warmGold : AppTheme.mediumGrey),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: selected ? Colors.white70 : AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


