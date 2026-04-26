import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import 'menu_service.dart';

/// Service to handle menu-based reservation pricing
class MenuReservationService {
  static final MenuReservationService _instance = MenuReservationService._internal();
  
  MenuReservationService._internal();

  factory MenuReservationService() {
    return _instance;
  }

  /// Calculate total price based on selected menu items and quantities
  double calculateMenuTotalPrice(Map<String, int> selectedItems) {
    try {
      final menu = MenuService.getMenu();
      double totalPrice = 0.0;

      selectedItems.forEach((itemName, quantity) {
        // Find the item in the menu
        MenuItem? foundItem;
        for (final category in menu.values) {
          try {
            foundItem = category.firstWhere(
              (menuItem) => menuItem.name == itemName,
            );
            break; // Found the item, exit category loop
          } catch (e) {
            // Item not found in this category, continue to next
            continue;
          }
        }
        
        // Use found item or create default with 0 price
        final item = foundItem ?? MenuItem(
          name: itemName,
          price: 0.0,
          category: 'Unknown',
          fallbackImagePath: '',
          color: Colors.grey,
        );
        
        totalPrice += item.price * quantity;
      });

      debugPrint('Menu pricing calculation:');
      debugPrint('Selected items: $selectedItems');
      debugPrint('Total menu price: ${totalPrice.toStringAsFixed(2)}');
      
      return totalPrice;
    } catch (e) {
      debugPrint('Error calculating menu price: $e');
      return 0.0;
    }
  }

  /// Calculate payment amount (100% for advance orders, 50% for others)
  double calculateMenuDepositAmount(double totalMenuPrice, {String? reservationType}) {
    if (reservationType == 'Advance Order') {
      return totalMenuPrice; // 100% for Advance Orders
    }
    return totalMenuPrice * 0.5; // 50% for Event Place / others
  }

  /// Get menu pricing breakdown for display
  Map<String, dynamic> getMenuPricingBreakdown(Map<String, int> selectedItems, {String? reservationType}) {
    final menu = MenuService.getMenu();
    final List<Map<String, dynamic>> itemBreakdown = [];
    double totalPrice = 0.0;

    selectedItems.forEach((itemName, quantity) {
      // Find the item in the menu
      MenuItem? foundItem;
      for (final category in menu.values) {
        try {
          foundItem = category.firstWhere(
            (menuItem) => menuItem.name == itemName,
          );
          break; // Found the item, exit category loop
        } catch (e) {
          // Item not found in this category, continue to next
          continue;
        }
      }
      
      // Use found item or create default with 0 price
      final item = foundItem ?? MenuItem(
        name: itemName,
        price: 0.0,
        category: 'Unknown',
        fallbackImagePath: '',
        color: Colors.grey,
      );
      
      final itemTotal = item.price * quantity;
      totalPrice += itemTotal;
      
      itemBreakdown.add({
        'name': item.name,
        'category': item.category,
        'price': item.price,
        'quantity': quantity,
        'total': itemTotal,
        'imagePath': item.customImagePath ?? item.fallbackImagePath,
      });
    });

    final depositAmount = calculateMenuDepositAmount(totalPrice, reservationType: reservationType);
    final double depositPercent = (reservationType == 'Advance Order') ? 100.0 : 50.0;

    return {
      'items': itemBreakdown,
      'totalPrice': totalPrice,
      'depositAmount': depositAmount,
      'depositPercentage': depositPercent,
      'remainingBalance': totalPrice - depositAmount,
      'itemCount': selectedItems.values.fold(0, (sum, qty) => sum + qty),
    };
  }

  /// Get selected items summary for reservation
  String getSelectedItemsSummary(Map<String, int> selectedItems) {
    if (selectedItems.isEmpty) return 'No items selected';
    
    final summary = selectedItems.entries.map((entry) {
      final quantity = entry.value;
      final name = entry.key;
      return '$quantity x $name';
    }).join(', ');
    
    return summary;
  }

  /// Validate menu selection
  String? validateMenuSelection(Map<String, int> selectedItems) {
    if (selectedItems.isEmpty) {
      return 'Please select at least one menu item';
    }
    
    // Check if all quantities are positive
    for (final entry in selectedItems.entries) {
      if (entry.value <= 0) {
        return 'Quantity must be greater than 0 for ${entry.key}';
      }
    }
    
    // Check if items exist in menu
    final menu = MenuService.getMenu();
    final allMenuItems = menu.values.expand((items) => items).map((item) => item.name).toSet();
    
    for (final itemName in selectedItems.keys) {
      if (!allMenuItems.contains(itemName)) {
        return 'Item "$itemName" not found in menu';
      }
    }
    
    return null; // No validation errors
  }

  /// Get suggested menu items based on guest count
  List<MenuItem> getSuggestedMenuItems(int guestCount) {
    final menu = MenuService.getMenu();
    final List<MenuItem> suggestions = [];
    
    // Calculate approximate items needed (1.5 items per guest)
    final totalItemsNeeded = (guestCount * 1.5).ceil();
    
    // Get popular items from different categories
    final categories = ['Yangchow Family Bundles', 'Seafood', 'Pork', 'Chicken', 'Vegetables', 'Special Noodles'];
    
    for (final category in categories) {
      if (menu.containsKey(category) && menu[category]!.isNotEmpty) {
        // Get first 2 items from each category
        final categoryItems = menu[category]!.take(2).toList();
        suggestions.addAll(categoryItems);
        
        if (suggestions.length >= totalItemsNeeded) {
          break;
        }
      }
    }
    
    return suggestions.take(totalItemsNeeded).toList();
  }

  /// Calculate estimated total cost per guest
  double calculateCostPerGuest(double totalMenuPrice, int guestCount) {
    if (guestCount <= 0) return 0.0;
    return totalMenuPrice / guestCount;
  }


  /// Get menu items grouped by category for selection UI
  Map<String, List<MenuItem>> getMenuItemsByCategory() {
    return MenuService.getMenu();
  }

  /// Format menu price for display
  String formatMenuPrice(double price) {
    return 'PHP ${price.toStringAsFixed(2)}';
  }
}
