import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe_model.dart';
import '../models/menu_item.dart';
import 'package:flutter/foundation.dart';

class RecipeService {
  static final RecipeService _instance = RecipeService._internal();
  factory RecipeService() => _instance;
  RecipeService._internal();

  // Hardcoded recipes for menu items - you can move this to database later

  Future<Recipe?> getRecipeForMenuItem(String menuItemName) async {
    try {
      final response = await Supabase.instance.client
          .from('recipe_ingredients')
          .select()
          .eq('menu_item_name', menuItemName);
          
      if ((response as List).isEmpty) {
        return null;
      }
      
      final List<RecipeIngredient> ingredients = (response as List)
          .map((data) => RecipeIngredient.fromMap(data))
          .toList();
          
      return Recipe(
        menuItemName: menuItemName,
        ingredients: ingredients,
      );
    } catch (e) {
      debugPrint('Error getting recipe from Supabase: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getIngredientsForMenuItem(String menuItemName) async {
    final recipe = await getRecipeForMenuItem(menuItemName);
    if (recipe == null) return [];

    try {
      final ingredientsWithStatus = <Map<String, dynamic>>[];

      for (var ingredient in recipe.ingredients) {
        // Create ingredient data without inventory status
        final ingredientData = {
          'name': ingredient.name,
          'required_quantity': ingredient.quantity,
          'unit': ingredient.unit,
          'category': ingredient.category,
        };

        ingredientsWithStatus.add(ingredientData);
      }

      return ingredientsWithStatus;
    } catch (e) {
      debugPrint('Error getting ingredients: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getIngredientsWithInventoryStatus(String menuItemName) async {
    final recipe = await getRecipeForMenuItem(menuItemName);
    if (recipe == null) return [];

    try {
      // Get all items from kitchen_inventory
      final inventoryItems = await Supabase.instance.client
          .from('kitchen_inventory')
          .select('*')
          .order('name');

      final ingredientsWithStatus = <Map<String, dynamic>>[];

      for (var ingredient in recipe.ingredients) {
        // Find matching inventory item
        Map<String, dynamic>? matchingInventoryItem;
        
        for (var inventoryItem in inventoryItems) {
          final inventoryName = inventoryItem['name']?.toString().toLowerCase() ?? '';
          final ingredientName = ingredient.name.toLowerCase();
          
          // Check for exact match or partial match
          if (inventoryName.contains(ingredientName) || 
              ingredientName.contains(inventoryName)) {
            matchingInventoryItem = inventoryItem;
            break;
          }
        }

        // Create ingredient data with inventory status
        final ingredientData = {
          'name': matchingInventoryItem?['name'] ?? ingredient.name,
          'required_quantity': ingredient.quantity,
          'unit': matchingInventoryItem?['unit'] ?? ingredient.unit,
          'category': matchingInventoryItem?['category'] ?? ingredient.category,
          'inventory_quantity': matchingInventoryItem?['quantity'] ?? 0,
          'inventory_unit': matchingInventoryItem?['unit'] ?? 'pcs',
          'stock_status': _calculateStockStatus(
            matchingInventoryItem?['quantity'] as int? ?? 0,
            ingredient.quantity,
          ),
          'is_available': (matchingInventoryItem?['quantity'] as int? ?? 0) > 0,
          'inventory_item': matchingInventoryItem,
        };

        ingredientsWithStatus.add(ingredientData);
      }

      return ingredientsWithStatus;
    } catch (e) {
      debugPrint('Error getting ingredients with inventory status: $e');
      return [];
    }
  }

  Future<void> deductIngredientsFromInventory(String menuItemName, int orderQuantity) async {
    final recipe = await getRecipeForMenuItem(menuItemName);
    if (recipe == null) return;

    try {
      // Get all items from kitchen_inventory
      final inventoryItems = await Supabase.instance.client
          .from('kitchen_inventory')
          .select('*');

      for (var ingredient in recipe.ingredients) {
        // Find matching inventory item
        Map<String, dynamic>? matchingItem;
        for (var item in inventoryItems) {
          final inventoryName = item['name']?.toString().toLowerCase() ?? '';
          final ingredientName = ingredient.name.toLowerCase();
          
          if (inventoryName.contains(ingredientName) || 
              ingredientName.contains(inventoryName)) {
            matchingItem = item;
            break;
          }
        }

        if (matchingItem != null) {
          final int currentQty = (matchingItem['quantity'] as num?)?.toInt() ?? 0;
          // Calculate deduction based on ingredient quantity from recipe and order quantity
          final double ingredientQtyPerUnit = ingredient.quantity;
          final int deduction = (ingredientQtyPerUnit * orderQuantity).round();
          final int newQty = (currentQty - deduction).clamp(0, 999999).toInt();

          await Supabase.instance.client
              .from('kitchen_inventory')
              .update({'quantity': newQty})
              .eq('id', matchingItem['id']);
          
          debugPrint('Auto-Inventory: Deducted $deduction unit of "${matchingItem['name']}" for "$menuItemName" (ordered: $orderQuantity, recipe qty per unit: $ingredientQtyPerUnit). New stock: $newQty');
        } else {
          debugPrint('Auto-Inventory: No matching inventory item found for ingredient "${ingredient.name}"');
        }
      }
    } catch (e) {
      debugPrint('Error during inventory deduction: $e');
    }
  }

  /// Restores deducted ingredients back to kitchen_inventory when an order is purged or cancelled.
  Future<void> restoreIngredientsToInventory(String menuItemName, int orderQuantity) async {
    final recipe = await getRecipeForMenuItem(menuItemName);
    if (recipe == null) return;

    try {
      final inventoryItems = await Supabase.instance.client
          .from('kitchen_inventory')
          .select('*');

      for (var ingredient in recipe.ingredients) {
        Map<String, dynamic>? matchingItem;
        for (var item in inventoryItems) {
          final inventoryName = item['name']?.toString().toLowerCase() ?? '';
          final ingredientName = ingredient.name.toLowerCase();

          if (inventoryName.contains(ingredientName) ||
              ingredientName.contains(inventoryName)) {
            matchingItem = item;
            break;
          }
        }

        if (matchingItem != null) {
          final int currentQty = (matchingItem['quantity'] as num?)?.toInt() ?? 0;
          final double ingredientQtyPerUnit = ingredient.quantity;
          final int toRestore = (ingredientQtyPerUnit * orderQuantity).round();
          final int newQty = currentQty + toRestore;

          await Supabase.instance.client
              .from('kitchen_inventory')
              .update({'quantity': newQty})
              .eq('id', matchingItem['id']);

          debugPrint('Auto-Inventory Restore: Restored $toRestore of "${matchingItem['name']}" for purged "$menuItemName". New stock: $newQty');
        }
      }
    } catch (e) {
      debugPrint('Error restoring inventory ingredients: $e');
    }
  }

  Future<String?> checkInventoryAvailability(List<CartItem> cart) async {
    try {
      final supabase = Supabase.instance.client;
      // Get all items from kitchen_inventory
      final inventoryItems = await supabase
          .from('kitchen_inventory')
          .select('*');

      final List<CartItem> activeCart = cart.where((c) => c.quantity > 0).toList();
      if (activeCart.isEmpty) return null;

      final Set<String> itemNames = activeCart.map((c) => c.item.name).toSet();

      final recipeDataResponse = await supabase
          .from('recipe_ingredients')
          .select()
          .inFilter('menu_item_name', itemNames.toList());

      final Map<String, List<Map<String, dynamic>>> recipesByItem = {};
      for (final row in (recipeDataResponse as List? ?? [])) {
        final mName = row['menu_item_name'] as String;
        recipesByItem.putIfAbsent(mName, () => []).add(row as Map<String, dynamic>);
      }

      // Aggregate ingredient demands across all items in the cart
      // Map: inventoryItemId -> Map with metadata & total required
      final Map<dynamic, Map<String, dynamic>> ingredientUsage = {};

      for (final cartItem in activeCart) {
        final ingredients = recipesByItem[cartItem.item.name] ?? [];

        if (ingredients.isEmpty) {
          // Direct inventory match fallback for items without recipe (e.g. bottled drinks)
          final lowerName = cartItem.item.name.toLowerCase().trim();
          Map<String, dynamic>? matchingItem;
          for (final item in inventoryItems) {
            final invName = item['name']?.toString().toLowerCase().trim() ?? '';
            if (invName == lowerName || invName.contains(lowerName) || lowerName.contains(invName)) {
              matchingItem = item;
              break;
            }
          }
          if (matchingItem != null) {
            final itemMap = matchingItem;
            final invId = itemMap['id'];
            ingredientUsage.putIfAbsent(invId, () => {
              'inventoryItem': itemMap,
              'requiredQty': 0.0,
              'sources': <String>{},
              'unit': itemMap['unit'] ?? 'pcs',
              'name': itemMap['name'] ?? cartItem.item.name,
            });
            ingredientUsage[invId]!['requiredQty'] = (ingredientUsage[invId]!['requiredQty'] as double) + cartItem.quantity.toDouble();
            (ingredientUsage[invId]!['sources'] as Set<String>).add(cartItem.item.name);
          }
          continue;
        }

        for (final ing in ingredients) {
          final String ingName = ing['name']?.toString().trim() ?? '';
          if (ingName.isEmpty) continue;

          // Find matching inventory item (using exact-first fuzzy matching)
          Map<String, dynamic>? matchingItem;
          double bestMatchScore = 0;

          for (final item in inventoryItems) {
            final inventoryName = item['name']?.toString().toLowerCase().trim() ?? '';
            final ingredientName = ingName.toLowerCase();

            if (inventoryName == ingredientName) {
              matchingItem = item;
              bestMatchScore = 1.0;
              break;
            } else if (inventoryName.contains(ingredientName) || 
                       ingredientName.contains(inventoryName)) {
              if (bestMatchScore < 0.5) {
                matchingItem = item;
                bestMatchScore = 0.5;
              }
            }
          }

          if (matchingItem != null) {
            final itemMap = matchingItem;
            final invId = itemMap['id'];
            final double ingredientQtyPerUnit = (ing['quantity'] as num?)?.toDouble() ?? 1.0;
            final double reqQty = ingredientQtyPerUnit * cartItem.quantity;

            ingredientUsage.putIfAbsent(invId, () => {
              'inventoryItem': itemMap,
              'requiredQty': 0.0,
              'sources': <String>{},
              'unit': ing['unit'] ?? itemMap['unit'] ?? 'pcs',
              'name': itemMap['name'] ?? ingName,
            });
            ingredientUsage[invId]!['requiredQty'] = (ingredientUsage[invId]!['requiredQty'] as double) + reqQty;
            (ingredientUsage[invId]!['sources'] as Set<String>).add(cartItem.item.name);
          }
        }
      }

      // Check aggregated requirements against current inventory stock
      for (final usage in ingredientUsage.values) {
        final matchingItem = usage['inventoryItem'] as Map<String, dynamic>;
        final num currentStock = (matchingItem['quantity'] as num?) ?? 0;
        final double totalRequired = usage['requiredQty'] as double;
        final Set<String> sources = usage['sources'] as Set<String>;
        final String name = usage['name'] as String;
        final String unit = usage['unit'] as String;

        if (currentStock <= 0) {
          final sourcesStr = sources.join(', ');
          return 'No stock available for "$name" (needed by: $sourcesStr). Current stock: 0.';
        }

        if (totalRequired > currentStock) {
          final sourcesStr = sources.join(', ');
          return 'Insufficient stock for "$name". Total needed: ${totalRequired.round()} $unit across ($sourcesStr), but only ${currentStock.toInt()} available.';
        }
      }

      return null; // All good
    } catch (e) {
      debugPrint('Error during online inventory check, attempting offline fallback: $e');
      // When network is unavailable, do not hard-block staff from completing orders
      return null;
    }
  }

  String _calculateStockStatus(int inventoryQuantity, double requiredQuantity) {
    if (inventoryQuantity == 0) return 'OUT OF STOCK';
    if (inventoryQuantity < requiredQuantity) return 'INSUFFICIENT';
    if (inventoryQuantity < requiredQuantity * 2) return 'LOW STOCK';
    return 'AVAILABLE';
  }
}