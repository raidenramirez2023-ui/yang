import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class MenuIngredientsImporter {
  static final MenuIngredientsImporter _instance = MenuIngredientsImporter._internal();
  factory MenuIngredientsImporter() => _instance;
  MenuIngredientsImporter._internal();

  // All ingredients from menu items with their categories and default units
  static const List<Map<String, dynamic>> _menuIngredients = [
    // From Family Bundle A
    {'name': 'Chicken', 'category': 'Fresh', 'unit': 'kilo'},
    {'name': 'Pork', 'category': 'Fresh', 'unit': 'kilo'},
    {'name': 'Rice', 'category': 'Groceries', 'unit': 'kilo'},
    {'name': 'Soy Sauce', 'category': 'Sauces', 'unit': 'ml'},
    {'name': 'Vegetables', 'category': 'Vegetables', 'unit': 'kilo'},
    
    // From Family Bundle B
    {'name': 'Beef', 'category': 'Fresh', 'unit': 'kilo'},
    {'name': 'Noodles', 'category': 'Groceries', 'unit': 'kilo'},
    {'name': 'Eggs', 'category': 'Fresh', 'unit': 'pcs'},
    
    // From Family Bundle C
    {'name': 'Seafood', 'category': 'Fresh', 'unit': 'kilo'},
    {'name': 'Garlic', 'category': 'Fresh', 'unit': 'gram'},
    
    // From Family Bundle D (additional quantities, already covered above)
    
    // From Vegetables dishes
    {'name': 'Onion', 'category': 'Vegetables', 'unit': 'gram'},
    {'name': 'Bihon Noodles', 'category': 'Groceries', 'unit': 'gram'},
    {'name': 'Salt', 'category': 'Groceries', 'unit': 'gram'},
    {'name': 'Cooking Oil', 'category': 'Groceries', 'unit': 'ml'},
    {'name': 'Century Egg', 'category': 'Groceries', 'unit': 'pcs'},
    {'name': 'Ginger', 'category': 'Fresh', 'unit': 'gram'},
    {'name': 'Jelly Fish', 'category': 'Fresh', 'unit': 'gram'},
    
    // From Special Noodles
    {'name': 'Canton Noodles', 'category': 'Groceries', 'unit': 'gram'},
    {'name': 'Wonton Noodles', 'category': 'Groceries', 'unit': 'gram'},
    {'name': 'Wonton', 'category': 'Groceries', 'unit': 'pcs'},
    {'name': 'Sotanghon', 'category': 'Groceries', 'unit': 'gram'},
    {'name': 'Rice Noodles', 'category': 'Groceries', 'unit': 'gram'},
    
    // From Soups
    {'name': 'Corn', 'category': 'Vegetables', 'unit': 'gram'},
    {'name': 'Tofu', 'category': 'Fresh', 'unit': 'gram'},
    {'name': 'Vinegar', 'category': 'Sauces', 'unit': 'ml'},
    {'name': 'Mixed Seafood', 'category': 'Fresh', 'unit': 'gram'},
    {'name': 'Chicken Stock', 'category': 'Groceries', 'unit': 'ml'},
    {'name': 'Water', 'category': 'Groceries', 'unit': 'ml'},
    
    // From Seafood dishes
    {'name': 'Shrimp', 'category': 'Fresh', 'unit': 'gram'},
    {'name': 'Fish', 'category': 'Fresh', 'unit': 'gram'},
    {'name': 'Oyster', 'category': 'Fresh', 'unit': 'gram'},
    {'name': 'Tiger Prawns', 'category': 'Fresh', 'unit': 'gram'},
    {'name': 'Squid', 'category': 'Fresh', 'unit': 'gram'},
    
    // From Roast and Soy Specialties
    {'name': 'Duck', 'category': 'Fresh', 'unit': 'pcs'},
    {'name': 'Spices', 'category': 'Groceries', 'unit': 'gram'},
    {'name': 'Lemon', 'category': 'Fresh', 'unit': 'pcs'},
    {'name': 'Butter', 'category': 'Groceries', 'unit': 'gram'},
    {'name': 'Chicken Feet', 'category': 'Fresh', 'unit': 'gram'},
    {'name': 'Chili', 'category': 'Fresh', 'unit': 'gram'},
    {'name': 'Sugar', 'category': 'Groceries', 'unit': 'gram'},
    
    // From Pork dishes
    {'name': 'Mantau', 'category': 'Groceries', 'unit': 'pcs'},
    {'name': 'Flour', 'category': 'Groceries', 'unit': 'gram'},
    {'name': 'Lumpia Wrapper', 'category': 'Groceries', 'unit': 'pcs'},
    
    // From Noodles
    {'name': 'Lo Mein Noodles', 'category': 'Groceries', 'unit': 'gram'},
    {'name': 'Mami Noodles', 'category': 'Groceries', 'unit': 'gram'},
    {'name': 'Beef Stock', 'category': 'Groceries', 'unit': 'ml'},
    
    // From Hot Pot
    {'name': 'Hot Pot Broth', 'category': 'Groceries', 'unit': 'ml'},
    {'name': 'Mixed Vegetables', 'category': 'Vegetables', 'unit': 'gram'},
    {'name': 'Mixed Meat', 'category': 'Fresh', 'unit': 'gram'},
    {'name': 'Premium Seafood', 'category': 'Fresh', 'unit': 'gram'},
    {'name': 'Premium Broth', 'category': 'Groceries', 'unit': 'ml'},
    
    // From Dimsum
    {'name': 'Wonton Wrapper', 'category': 'Groceries', 'unit': 'pcs'},
    {'name': 'Bamboo Shoots', 'category': 'Vegetables', 'unit': 'gram'},
    {'name': 'Pork Leg', 'category': 'Fresh', 'unit': 'gram'},
    
    // From Chicken dishes
    {'name': 'Peanuts', 'category': 'Groceries', 'unit': 'gram'},
    
    // From Beef dishes
    {'name': 'Broccoli', 'category': 'Vegetables', 'unit': 'gram'},
    {'name': 'Black Pepper', 'category': 'Groceries', 'unit': 'gram'},
    
    // From Appetizers
    {'name': 'Lumpia Wrapper', 'category': 'Groceries', 'unit': 'pcs'},
  ];

  // Get unique ingredients (remove duplicates)
  List<Map<String, dynamic>> get _uniqueIngredients {
    final uniqueNames = <String>{};
    final uniqueIngredients = <Map<String, dynamic>>[];
    
    for (var ingredient in _menuIngredients) {
      final name = ingredient['name'] as String;
      if (!uniqueNames.contains(name)) {
        uniqueNames.add(name);
        uniqueIngredients.add(ingredient);
      }
    }
    
    return uniqueIngredients;
  }

  Future<void> addAllMenuIngredientsToInventory() async {
    try {
      debugPrint('Starting to add menu ingredients to inventory...');
      
      // Get current inventory items
      final currentInventory = await Supabase.instance.client
          .from('inventory')
          .select('name, category, unit');
      
      final currentInventoryNames = currentInventory
          .map((item) => item['name']?.toString().toLowerCase() ?? '')
          .toSet();
      
      final uniqueIngredients = _uniqueIngredients;
      int addedCount = 0;
      int skippedCount = 0;
      
      for (var ingredient in uniqueIngredients) {
        final ingredientName = ingredient['name'] as String;
        final normalizedName = ingredientName.toLowerCase().trim();
        
        // Check if ingredient already exists (case-insensitive)
        bool exists = false;
        for (var existingName in currentInventoryNames) {
          if (existingName.contains(normalizedName) || normalizedName.contains(existingName)) {
            exists = true;
            break;
          }
        }
        
        if (exists) {
          debugPrint('Skipped (already exists): $ingredientName');
          skippedCount++;
          continue;
        }
        
        // Determine appropriate storage room based on category
        String storageRoom = _getStorageRoomForCategory(ingredient['category'] as String);
        
        // Add to inventory with 0 quantity
        await Supabase.instance.client.from('inventory').insert({
          'name': ingredientName.trim(),
          'category': ingredient['category'],
          'quantity': 0, // Start with 0 quantity
          'unit': ingredient['unit'],
          'storage_room': storageRoom,
          'supplier': 'Menu Ingredient Auto-Import',
          'created_by': 'pagsanjaninv@gmail.com',
          'created_at': DateTime.now().toIso8601String(),
        });
        
        debugPrint('Added: $ingredientName (${ingredient['category']})');
        addedCount++;
      }
      
      debugPrint('\n=== Import Summary ===');
      debugPrint('Total unique ingredients processed: ${uniqueIngredients.length}');
      debugPrint('Successfully added: $addedCount');
      debugPrint('Skipped (already exist): $skippedCount');
      debugPrint('Import completed successfully!');
      
    } catch (e) {
      debugPrint('Error adding menu ingredients to inventory: $e');
      rethrow;
    }
  }

  String _getStorageRoomForCategory(String category) {
    switch (category) {
      case 'Fresh':
        return 'Chiller';
      case 'Vegetables':
        return 'Chiller';
      case 'Groceries':
        return 'Dry Storage';
      case 'Sauces':
        return 'Dry Storage';
      default:
        return 'Dry Storage';
    }
  }

  // Method to get ingredients that are missing from inventory
  Future<List<Map<String, dynamic>>> getMissingIngredients() async {
    try {
      final currentInventory = await Supabase.instance.client
          .from('inventory')
          .select('name');
      
      final currentInventoryNames = currentInventory
          .map((item) => item['name']?.toString().toLowerCase() ?? '')
          .toSet();
      
      final uniqueIngredients = _uniqueIngredients;
      final missingIngredients = <Map<String, dynamic>>[];
      
      for (var ingredient in uniqueIngredients) {
        final ingredientName = ingredient['name'] as String;
        final normalizedName = ingredientName.toLowerCase().trim();
        
        bool exists = false;
        for (var existingName in currentInventoryNames) {
          if (existingName.contains(normalizedName) || normalizedName.contains(existingName)) {
            exists = true;
            break;
          }
        }
        
        if (!exists) {
          missingIngredients.add(ingredient);
        }
      }
      
      return missingIngredients;
    } catch (e) {
      debugPrint('Error getting missing ingredients: $e');
      return [];
    }
  }

  // Method to display missing ingredients before adding
  Future<void> showMissingIngredients() async {
    final missing = await getMissingIngredients();
    
    if (missing.isEmpty) {
      debugPrint('All menu ingredients are already in the inventory!');
      return;
    }
    
    debugPrint('\n=== Missing Ingredients (${missing.length}) ===');
    for (var ingredient in missing) {
      debugPrint('- ${ingredient['name']} (${ingredient['category']}) - ${ingredient['unit']}');
    }
  }
}
