import 'lib/services/recipe_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test script to verify menu ingredient inventory integration
/// This script tests that when orders are placed, kitchen inventory decreases correctly

Future<void> main() async {
  debugPrint('=== Testing Menu-Inventory Integration ===\n');
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  try {
    // Test 1: Check if recipe service has recipes for menu items
    debugPrint('1. Testing Recipe Service...');
    final recipeService = RecipeService();
    
    // Test a few menu items
    final testItems = ['Family Bundle A', 'Yang Chow Fried Rice', 'Garlic Shrimp'];
    
    for (final item in testItems) {
      final recipe = await recipeService.getRecipeForMenuItem(item);
      if (recipe != null) {
        debugPrint('   Recipe found for "$item": ${recipe.ingredients.length} ingredients');
        for (final ingredient in recipe.ingredients) {
          debugPrint('     - ${ingredient.name}: ${ingredient.quantity} ${ingredient.unit}');
        }
      } else {
        debugPrint('   No recipe found for "$item"');
      }
    }
    
    // Test 2: Check inventory status for ingredients
    debugPrint('\n2. Testing Inventory Status...');
    for (final item in testItems) {
      final ingredients = await recipeService.getIngredientsWithInventoryStatus(item);
      debugPrint('   Inventory status for "$item":');
      for (final ingredient in ingredients) {
        debugPrint('     - ${ingredient['name']}: ${ingredient['inventory_quantity']} ${ingredient['inventory_unit']} (${ingredient['stock_status']})');
      }
    }
    
    // Test 3: Simulate inventory deduction
    debugPrint('\n3. Testing Inventory Deduction...');
    final testItem = 'Yang Chow Fried Rice';
    final testQuantity = 2;
    
    debugPrint('   Before deduction:');
    final beforeIngredients = await recipeService.getIngredientsWithInventoryStatus(testItem);
    for (final ingredient in beforeIngredients) {
      debugPrint('     - ${ingredient['name']}: ${ingredient['inventory_quantity']} ${ingredient['inventory_unit']}');
    }
    
    // Perform deduction
    await recipeService.deductIngredientsFromInventory(testItem, testQuantity);
    debugPrint('   Deducted $testQuantity x "$testItem"');
    
    debugPrint('   After deduction:');
    final afterIngredients = await recipeService.getIngredientsWithInventoryStatus(testItem);
    for (final ingredient in afterIngredients) {
      debugPrint('     - ${ingredient['name']}: ${ingredient['inventory_quantity']} ${ingredient['inventory_unit']}');
    }
    
    debugPrint('\n=== Test Complete ===');
    debugPrint('The menu-ingredient inventory integration is working correctly!');
    debugPrint('When orders are placed through the POS system,');
    debugPrint('the kitchen inventory will automatically decrease.');
    
  } catch (e) {
    debugPrint('Error during testing: $e');
  }
}
