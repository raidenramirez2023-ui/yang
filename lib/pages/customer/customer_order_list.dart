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

void showOrderListModal({
  required BuildContext context,
  required Map<String, int> selectedMenuItems,
  required VoidCallback onProceed,
  VoidCallback? onCartUpdated,
}) {
  final Map<String, List<MenuItem>> allMenu = MenuService.getMenu();
  final List<MenuItem> flatMenu = allMenu.values.expand((e) => e).toList();
  final NumberFormat fmt = NumberFormat('#,##0.00', 'en_US');

  // ── Backward Compatibility Migration ──
  bool needsUpdate = false;
  final migratedItems = <String, int>{};
  
  for (final entry in selectedMenuItems.entries) {
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
    selectedMenuItems.clear();
    selectedMenuItems.addAll(migratedItems);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onCartUpdated?.call();
    });
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          double totalPrice = 0.0;
          selectedMenuItems.forEach((itemName, qty) {
            final match = flatMenu.where((e) => e.name == itemName);
            if (match.isNotEmpty) {
              totalPrice += match.first.price * qty;
            }
          });

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // ── Drag Handle ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // ── Header ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppTheme.goldGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shopping_bag_outlined, color: Colors.black, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Your Order List',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.darkGrey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // ── Item list / empty state ────────────────────────────────
                Expanded(
                  child: selectedMenuItems.isEmpty
                      ? EmptyStateCard(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Your order list is empty',
                          description: 'Browse our menu items and add your favorite dishes to get started.',
                          buttonText: 'Browse Menu',
                          onButtonPressed: () => Navigator.pop(ctx),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          itemCount: selectedMenuItems.length,
                          itemBuilder: (_, index) {
                            final itemName = selectedMenuItems.keys.elementAt(index);
                            final qty = selectedMenuItems[itemName] ?? 0;

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
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Food image
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: imgUrl.isNotEmpty
                                            ? Image.network(imgUrl, fit: BoxFit.cover)
                                            : Container(
                                                color: AppTheme.lightGrey,
                                                child: const Icon(Icons.restaurant, color: Colors.grey),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Name + price
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cartItem.name,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppTheme.darkGrey,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '₱${fmt.format(cartItem.price * qty)} (${qty}x)',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // ── +/− stepper ───────────────────────
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _stepperButton(
                                          icon: qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                          color: qty <= 1 ? AppTheme.errorRed : AppTheme.primaryColor,
                                          onTap: () {
                                            setSheetState(() {
                                              if (qty <= 1) {
                                                selectedMenuItems.remove(itemName);
                                              } else {
                                                selectedMenuItems[itemName] = qty - 1;
                                              }
                                            });
                                            onCartUpdated?.call();
                                          },
                                        ),
                                        Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '$qty',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                        _stepperButton(
                                          icon: Icons.add_rounded,
                                          color: AppTheme.primaryColor,
                                          onTap: () {
                                            setSheetState(() {
                                              selectedMenuItems[itemName] = qty + 1;
                                            });
                                            onCartUpdated?.call();
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // ── Footer Summary & Proceed button ───────────────────────
                if (selectedMenuItems.isNotEmpty)
                  Container(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).padding.bottom + 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Estimated Total',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.mediumGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.warmGold,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '₱${fmt.format(totalPrice)}',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.darkBrownText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AnimatedTapScale(
                          onTap: () {
                            Navigator.pop(ctx);
                            onProceed();
                          },
                          child: Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppTheme.warmGold,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.warmGold.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Proceed to Order / Reservation',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkBrownText,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, color: AppTheme.darkBrownText, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
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
