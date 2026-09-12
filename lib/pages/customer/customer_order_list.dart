// ─────────────────────────────────────────────────────────────────────────────
// customer_order_list.dart
//
// Contains all Pre-order Cart UI widgets for the Customer Dashboard:
//   - showMenuItemSheet()   → slide-up panel with item info + "Add to Order List"
//   - showOrderListModal()  → cart bottom sheet listing selected items
//   - buildCartIcon()       → badged cart icon for the AppBar
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' as ui;
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

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: AnimatedTapScale(
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (uniqueItems > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.navColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    uniqueItems > 9 ? '9+' : '$uniqueItems',
                    style: GoogleFonts.inter(
                      color: AppTheme.darkBrownText,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFBFDFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // ── Scrollable Dish Info Content ──────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Image Banner with Badges
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        children: [
                          imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  height: 225,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                                )
                              : _imagePlaceholder(),

                          // Ambient Gradient Overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.35, 0.65, 1.0],
                                  colors: [
                                    Colors.black.withValues(alpha: 0.45),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.15),
                                    Colors.black.withValues(alpha: 0.70),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Category Badge (Top-Left) with Frosted Glass
                          Positioned(
                            top: 12,
                            left: 12,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0C241F).withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFD9A441).withValues(alpha: 0.75),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.restaurant_menu_rounded,
                                        color: Color(0xFFD9A441),
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        widget.item.category.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFD9A441),
                                          letterSpacing: 0.9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Close Button (Top-Right) with Frosted Glass
                          Positioned(
                            top: 12,
                            right: 12,
                            child: AnimatedTapScale(
                              onTap: () => Navigator.pop(context),
                              child: ClipOval(
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Overlaid Bottom Highlights on Image
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.stars_rounded,
                                        color: Color(0xFFD9A441),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4.5),
                                      Text(
                                        'Authentic Yang Chow',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A).withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Made to Order',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Dish Title & Pricing Section
                  Text(
                    widget.item.name,
                    style: GoogleFonts.lora(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Price Bar with Base Tag
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₱',
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0E533C),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _fmt.format(widget.item.price),
                        style: GoogleFonts.lora(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0E533C),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E533C).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF0E533C).withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          'Per order',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0E533C),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Description or Culinary Tagline
                  Text(
                    (widget.item.description != null && widget.item.description!.trim().isNotEmpty)
                        ? widget.item.description!
                        : 'Prepared fresh to order using Yang Chow\'s authentic culinary techniques and premium hand-selected ingredients.',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: const Color(0xFF64748B),
                      height: 1.5,
                      fontStyle: (widget.item.description == null || widget.item.description!.trim().isEmpty)
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Culinary Experience Chips (3-Column Badges)
                  Row(
                    children: [
                      Expanded(
                        child: _buildFeatureCard(
                          icon: Icons.timer_outlined,
                          title: '15–20 Mins',
                          subtitle: 'Cook time',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFeatureCard(
                          icon: Icons.soup_kitchen_outlined,
                          title: 'Freshly Made',
                          subtitle: 'Cooked to order',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFeatureCard(
                          icon: Icons.takeout_dining_outlined,
                          title: 'Safe Pack',
                          subtitle: 'Hot & sealed',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Kitchen & Dietary Note Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFB45309),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Special requests or dietary preferences? You can mention your notes during checkout or table reservation.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF92400E),
                              height: 1.4,
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

          // ── Sticky Bottom Action Bar with Quantity Stepper & Add to Order ──
          Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Modern Pill Quantity Stepper
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Minus Button
                      AnimatedTapScale(
                        onTap: _quantity > 1 ? () => setState(() => _quantity--) : null,
                        child: Container(
                          width: 38,
                          height: 50,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.remove_rounded,
                            size: 18,
                            color: _quantity > 1 ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                      // Quantity Number
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '$_quantity',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      // Plus Button
                      AnimatedTapScale(
                        onTap: () => setState(() => _quantity++),
                        child: Container(
                          width: 38,
                          height: 50,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: Color(0xFF0E533C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Add to Order CTA Button with Total Price
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
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Added $_quantity × ${widget.item.name} • ₱${_fmt.format(_totalPrice)}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF0C241F),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: const Color(0xFFD9A441).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0C241F), Color(0xFF194E42)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD9A441).withValues(alpha: 0.35),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0C241F).withValues(alpha: 0.32),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_shopping_cart_rounded,
                                color: Color(0xFFD9A441),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Add to Order',
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFD9A441).withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Text(
                                  '₱${_fmt.format(_totalPrice)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFD9A441),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0E533C)),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
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
  /// Called when the user taps "Browse Menu" on the empty-cart screen.
  /// Use this to navigate them to the Home tab where the menu lives.
  final VoidCallback? onBrowseMenu;

  const CustomerOrderListPage({
    Key? key,
    required this.selectedMenuItems,
    required this.onProceed,
    this.onCartUpdated,
    this.onBrowseMenu,
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
    final hasItems = widget.selectedMenuItems.isNotEmpty;
    final allSelected = hasItems && _checkedItems.length == widget.selectedMenuItems.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        backgroundColor: AppTheme.navColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: AnimatedTapScale(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Order List',
              style: GoogleFonts.lora(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppTheme.warmGold,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        actions: [
          if (hasItems)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: AppTheme.warmGold, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.selectedMenuItems.length}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: !hasItems
          ? Center(
              child: EmptyStateCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Your order list is empty',
                description: 'Browse our menu items and add your favorite dishes to get started.',
                buttonText: 'Browse Menu',
                onButtonPressed: () {
                  Navigator.pop(context);
                  widget.onBrowseMenu?.call();
                },
              ),
            )
          : Column(
              children: [
                // ── Top Action Toolbar (Select All & Item Counter) ──
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              if (allSelected) {
                                _checkedItems.clear();
                              } else {
                                _checkedItems = Set<String>.from(widget.selectedMenuItems.keys);
                              }
                            });
                          },
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: allSelected
                                      ? AppTheme.warmGold
                                      : (_checkedItems.isNotEmpty
                                          ? AppTheme.warmGold.withValues(alpha: 0.2)
                                          : Colors.transparent),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _checkedItems.isNotEmpty
                                        ? AppTheme.warmGold
                                        : const Color(0xFFCBD5E1),
                                    width: 1.5,
                                  ),
                                ),
                                child: allSelected
                                    ? const Icon(Icons.check_rounded, size: 15, color: AppTheme.darkBrownText)
                                    : (_checkedItems.isNotEmpty
                                        ? const Icon(Icons.remove_rounded, size: 14, color: AppTheme.darkBrownText)
                                        : null),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Select All Items',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _checkedItems.isNotEmpty
                              ? AppTheme.forestGreen.withValues(alpha: 0.08)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _checkedItems.isNotEmpty
                                ? AppTheme.forestGreen.withValues(alpha: 0.2)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _checkedItems.isNotEmpty ? AppTheme.forestGreen : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${_checkedItems.length}/${widget.selectedMenuItems.length} selected',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _checkedItems.isNotEmpty ? AppTheme.forestGreen : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Cart Items List ──
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
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
                      final isChecked = _checkedItems.contains(itemName);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isChecked
                                ? AppTheme.warmGold.withValues(alpha: 0.55)
                                : const Color(0xFFE5E7EB),
                            width: isChecked ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isChecked
                                  ? const Color(0xFF0C241F).withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.03),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Header bar with Checkbox & Category ──
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isChecked
                                        ? const [Color(0xFF0C241F), Color(0xFF163E34)]
                                        : const [Color(0xFF334155), Color(0xFF475569)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          setState(() {
                                            if (isChecked) {
                                              _checkedItems.remove(itemName);
                                            } else {
                                              _checkedItems.add(itemName);
                                            }
                                          });
                                        },
                                        child: Row(
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 180),
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                color: isChecked
                                                    ? AppTheme.warmGold
                                                    : Colors.white.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isChecked
                                                      ? AppTheme.warmGold
                                                      : Colors.white.withValues(alpha: 0.6),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: isChecked
                                                  ? const Icon(Icons.check_rounded, size: 15, color: AppTheme.darkBrownText)
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.35)),
                                                ),
                                                child: Text(
                                                  cartItem.category.toUpperCase(),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppTheme.warmGold,
                                                    letterSpacing: 1.1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Gold Subtotal badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                                      decoration: BoxDecoration(
                                        gradient: isChecked
                                            ? AppTheme.goldGradient
                                            : LinearGradient(
                                                colors: [
                                                  Colors.grey.shade400,
                                                  Colors.grey.shade500,
                                                ],
                                              ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.22),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '₱',
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: isChecked ? AppTheme.darkBrownText : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            fmt.format(cartItem.price * qty),
                                            style: GoogleFonts.inter(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w900,
                                              color: isChecked ? AppTheme.darkBrownText : Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ── Card Body ──
                              Opacity(
                                opacity: isChecked ? 1.0 : 0.60,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      // Food thumbnail with shadow & border
                                      Container(
                                        width: 74,
                                        height: 74,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(15),
                                          child: imgUrl.isNotEmpty
                                              ? Image.network(
                                                  imgUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                                                )
                                              : _imagePlaceholder(),
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
                                                color: const Color(0xFF0F172A),
                                                letterSpacing: -0.2,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Text(
                                                  '₱${fmt.format(cartItem.price)}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.forestGreen,
                                                  ),
                                                ),
                                                Text(
                                                  ' each',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // ── Unified Pill Stepper ──
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Minus or Trash
                                            AnimatedTapScale(
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
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: qty <= 1 ? const Color(0xFFFEE2E2) : Colors.white,
                                                  borderRadius: BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.04),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                                  size: 16,
                                                  color: qty <= 1 ? const Color(0xFFDC2626) : AppTheme.forestGreen,
                                                ),
                                              ),
                                            ),
                                            // Quantity Number
                                            Container(
                                              constraints: const BoxConstraints(minWidth: 32),
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '$qty',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            // Plus
                                            AnimatedTapScale(
                                              onTap: () {
                                                setState(() {
                                                  widget.selectedMenuItems[itemName] = qty + 1;
                                                });
                                                widget.onCartUpdated?.call();
                                              },
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.forestGreen,
                                                  borderRadius: BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: AppTheme.forestGreen.withValues(alpha: 0.3),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.add_rounded,
                                                  size: 16,
                                                  color: Colors.white,
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
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: hasItems
          ? Container(
              padding: EdgeInsets.fromLTRB(22, 18, 22, MediaQuery.of(context).padding.bottom + 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: const Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
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
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESTIMATED TOTAL',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF64748B),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₱',
                                style: GoogleFonts.lora(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.forestGreen,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                fmt.format(_totalPrice),
                                style: GoogleFonts.lora(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.forestGreen,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ITEMS SELECTED',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF64748B),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AppTheme.goldGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.warmGold.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '${_checkedItems.length} / ${widget.selectedMenuItems.length}',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.darkBrownText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // CTA Button
                  AnimatedTapScale(
                    onTap: () {
                      if (_checkedItems.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Please select at least one item to proceed.',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFFDC2626),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _checkedItems.isNotEmpty
                            ? const LinearGradient(
                                colors: [Color(0xFF0C241F), Color(0xFF164438)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: _checkedItems.isEmpty ? const Color(0xFF94A3B8) : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _checkedItems.isNotEmpty
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0C241F).withValues(alpha: 0.32),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.event_available_rounded,
                              color: AppTheme.warmGold,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Proceed to Reservation type',
                              style: GoogleFonts.inter(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppTheme.warmGold,
                            size: 20,
                          ),
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
        color: color.withValues(alpha: 0.1),
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
    // NOTE: Do NOT clear or mutate parentCart here.
    // Cart items are only removed after the reservation/order is successfully submitted.
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0C241F), Color(0xFF164438)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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


