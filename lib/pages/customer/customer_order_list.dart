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

// ─── Cart Icon (with badge) ──────────────────────────────────────────────────

Widget buildCartIcon({
  required Map<String, int> selectedMenuItems,
  required VoidCallback onPressed,
}) {
  final int uniqueItems = selectedMenuItems.length;

  return Stack(
    alignment: Alignment.center,
    children: [
      IconButton(
        icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 24),
        tooltip: 'Order List',
        onPressed: onPressed,
      ),
      if (uniqueItems > 0)
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Text(
              '$uniqueItems',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
    ],
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
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Food image ──────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                    // Name
                    Text(
                      item.name,
                      style: GoogleFonts.lora(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),

                    // Description
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        item.description!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                          height: 1.6,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Price row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF888888),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '₱${fmt.format(item.price)}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Add to Order List button ─────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(ctx).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final itemName = item.name;
                    selectedMenuItems[itemName] = (selectedMenuItems[itemName] ?? 0) + 1;
                    onCartUpdated?.call();
                    onAdded();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${item.name} added to your order list!',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
                  label: const Text(
                    'Add to Order List',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
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
  // Convert any old item.id keys to item.name to fix blank lists on old carts.
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
        // Unidentifiable key, discard
        needsUpdate = true;
      }
    }
  }

  if (needsUpdate) {
    selectedMenuItems.clear();
    selectedMenuItems.addAll(migratedItems);
    // Call next frame to avoid build state issues
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
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // ── Handle ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Header ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Order List',
                        style: GoogleFonts.lora(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // ── Item list / empty state ────────────────────────────────
                Expanded(
                  child: selectedMenuItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text(
                                'Your order list is empty',
                                style: TextStyle(fontSize: 17, color: Colors.grey, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap any menu item to add it here.',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              color: Colors.grey.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    // Food image
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 54,
                                        height: 54,
                                        child: imgUrl.isNotEmpty
                                            ? Image.network(imgUrl, fit: BoxFit.cover)
                                            : const Icon(Icons.fastfood),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Name + price
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cartItem.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '₱${fmt.format(cartItem.price)} each',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // ── +/− stepper ───────────────────────
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Minus / Remove button
                                        _stepperButton(
                                          icon: qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                          color: qty <= 1 ? Colors.red.shade400 : AppTheme.primaryColor,
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

                                        // Quantity label
                                        Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '$qty',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),

                                        // Plus button
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

                // ── Proceed button ─────────────────────────────────────────
                Container(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).padding.bottom + 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onProceed();
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                      label: const Text(
                        'Proceed to Set Event / Order',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                    ),
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
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color),
    ),
  );
}

