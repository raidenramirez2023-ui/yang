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
          
      if (response == null || (response as List).isEmpty) {
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

  Future<String?> checkInventoryAvailability(List<CartItem> cart) async {
    try {
      final supabase = Supabase.instance.client;
      // Get all items from kitchen_inventory
      final inventoryItems = await supabase
          .from('kitchen_inventory')
          .select('*');

      for (final cartItem in cart) {
        final recipeDataResponse = await supabase
            .from('recipe_ingredients')
            .select()
            .eq('menu_item_name', cartItem.item.name);
            
        if (recipeDataResponse == null || (recipeDataResponse as List).isEmpty) continue;

        final List ingredients = recipeDataResponse as List;
        for (final ing in ingredients) {
          final String ingName = ing['name'];
          
          // Find matching inventory item (using exact-first fuzzy matching)
          Map<String, dynamic>? matchingItem;
          double bestMatchScore = 0;
          
          for (final item in inventoryItems) {
            final inventoryName = item['name']?.toString().toLowerCase() ?? '';
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
            final num currentStock = (matchingItem['quantity'] as num?) ?? 0;
            
            // Calculate required ingredient quantity based on recipe and order quantity
            final double ingredientQtyPerUnit = ing['quantity']?.toDouble() ?? 1.0;
            final double requiredQty = ingredientQtyPerUnit * cartItem.quantity;
            
            // Check if required quantity exceeds current stock
            if (requiredQty > currentStock) {
              final String itemName = cartItem.item.name;
              return 'No stock available for $itemName. Need ${requiredQty.round()} ${ing['unit']} of ${ing['name']} but only ${currentStock.toInt()} available.';
            }
            
            // Check if stock is zero - no stock available
            if (currentStock <= 0) {
              final String itemName = cartItem.item.name;
              return 'No stock available for $itemName. No ${ing['name']} available.';
            }
          }
        }
      }

      return null; // All good
    } catch (e) {
      debugPrint('Error during inventory check: $e');
      return 'Inventory check failed: $e';
    }
  }

  String _calculateStockStatus(int inventoryQuantity, double requiredQuantity) {
    if (inventoryQuantity == 0) return 'OUT OF STOCK';
    if (inventoryQuantity < requiredQuantity) return 'INSUFFICIENT';
    if (inventoryQuantity < requiredQuantity * 2) return 'LOW STOCK';
    return 'AVAILABLE';
  }
}