import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe_model.dart';
import 'package:flutter/foundation.dart';

class RecipeService {
  static final RecipeService _instance = RecipeService._internal();
  factory RecipeService() => _instance;
  RecipeService._internal();

  // Hardcoded recipes for menu items - you can move this to database later
  static const Map<String, Map<String, dynamic>> _recipeDatabase = {
    // Yangchow Family Bundles
    'YangChow 1': {
      'menu_item_name': 'YangChow 1',
      'ingredients': [
        {'name': 'Chicken', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Pork', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Rice', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Groceries'},
        {'name': 'Soy Sauce', 'quantity': 1.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Vegetables'},
      ],
    },
    'YangChow 2': {
      'menu_item_name': 'YangChow 2',
      'ingredients': [
        {'name': 'Beef', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Noodles', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Groceries'},
        {'name': 'Soy Sauce', 'quantity': 1.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Vegetables'},
        {'name': 'Eggs', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
      ],
    },
    'YangChow 3': {
      'menu_item_name': 'YangChow 3',
      'ingredients': [
        {'name': 'Seafood', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Rice', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Vegetables'},
        {'name': 'Soy Sauce', 'quantity': 1.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'YangChow 4': {
      'menu_item_name': 'YangChow 4',
      'ingredients': [
        {'name': 'Chicken', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Pork', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Beef', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Seafood', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Rice', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Vegetables'},
      ],
    },
    'Overload Meal': {
      'menu_item_name': 'Overload Meal',
      'ingredients': [
        {'name': 'Chicken', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Pork', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Rice', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },

    // Vegetables
    'Broccoli Leaves with Oyster Sauce': {
      'menu_item_name': 'Broccoli Leaves with Oyster Sauce',
      'ingredients': [
        {'name': 'Sea Cucumber', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Broccoli Flower', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Ginger', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Soy Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Beef Broth', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Rice Wine', 'quantity': 1.0, 'unit': 'bot', 'category': 'Groceries'},
        {'name': 'White Pepper', 'quantity': 1.0, 'unit': 'pack', 'category': 'Groceries'},
        {'name': 'Potato Starch', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Sesame Oil', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Broccoli Flower with Oyster Sauce': {
      'menu_item_name': 'Broccoli Flower with Oyster Sauce',
      'ingredients': [
        {'name': 'Oyster', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Flour', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Broccoli Flower', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Taiwan Pechay with Oyster Sauce': {
      'menu_item_name': 'Taiwan Pechay with Oyster Sauce',
      'ingredients': [
        {'name': 'Taiwan Pechay', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Spinach/Polanchay Stir Fried': {
      'menu_item_name': 'Spinach/Polanchay Stir Fried',
      'ingredients': [
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Braised Sea Cucumber with Broccoli Flower': {
      'menu_item_name': 'Braised Sea Cucumber with Broccoli Flower',
      'ingredients': [
        {'name': 'Sea Cucumber', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Broccoli Flower', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Lohanchay': {
      'menu_item_name': 'Lohanchay',
      'ingredients': [
        {'name': 'Cabbage', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Chopsuey Guisado': {
      'menu_item_name': 'Chopsuey Guisado',
      'ingredients': [
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Onion', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Chinese Kangkong with Garlic': {
      'menu_item_name': 'Chinese Kangkong with Garlic',
      'ingredients': [
        {'name': 'Kangkong', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },

    // Special Noodles
    'YC Special Noodles': {
      'menu_item_name': 'YC Special Noodles',
      'ingredients': [
        {'name': 'Noodles', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Eggs', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
      ],
    },

    // Soup
    'Chicken Corn Soup': {
      'menu_item_name': 'Chicken Corn Soup',
      'ingredients': [
        {'name': 'Cream Corn', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Chicken', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Eggs', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
      ],
    },
    'Hot & Sour Soup': {
      'menu_item_name': 'Hot & Sour Soup',
      'ingredients': [
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Tofu', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vinegar', 'quantity': 1.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Hototay Soup': {
      'menu_item_name': 'Hototay Soup',
      'ingredients': [
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Carrots', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Vinegar', 'quantity': 1.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Minced Beef with Egg White Soup': {
      'menu_item_name': 'Minced Beef with Egg White Soup',
      'ingredients': [
        {'name': 'Noodles', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Beef', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },
    'Nido Soup with Quail Egg': {
      'menu_item_name': 'Nido Soup with Quail Egg',
      'ingredients': [
        {'name': 'Noodles', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Quail Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },
    'Spinach Seafood Soup': {
      'menu_item_name': 'Spinach Seafood Soup',
      'ingredients': [
        {'name': 'Mixed Seafood', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Chicken Stock', 'quantity': 1.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Crab Meat Corn Soup': {
      'menu_item_name': 'Crab Meat Corn Soup',
      'ingredients': [
        {'name': 'Corn', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Chicken', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Eggs', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
      ],
    },

    // Seafood
    'Salt & Pepper Squid': {
      'menu_item_name': 'Salt & Pepper Squid',
      'ingredients': [
        {'name': 'Squid', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Chicken Stock', 'quantity': 1.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Broccoli Flower with Squid': {
      'menu_item_name': 'Broccoli Flower with Squid',
      'ingredients': [
        {'name': 'Slice Squid 5x200', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 1.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Broccoli Flower with Shrimp': {
      'menu_item_name': 'Broccoli Flower with Shrimp',
      'ingredients': [
        {'name': 'Shrimp Marinated 10x100', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 1.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Steamed Fish Fillet with Oyster Sauce': {
      'menu_item_name': 'Steamed Fish Fillet with Oyster Sauce',
      'ingredients': [
        {'name': 'Fish', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Ginger', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Fish Fillet with Salt & Pepper': {
      'menu_item_name': 'Fish Fillet with Salt & Pepper',
      'ingredients': [
        {'name': 'Fish', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Ginger', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 1.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Sweet and Sour Fish Fillet': {
      'menu_item_name': 'Sweet and Sour Fish Fillet',
      'ingredients': [
        {'name': 'Fish', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Ginger', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Sweet and Sour Sauce', 'quantity': 1.0, 'unit': 'bot', 'category': 'Sauces'},
      ],
    },
    'Fish Fillet with Tausi Sauce': {
      'menu_item_name': 'Fish Fillet with Tausi Sauce',
      'ingredients': [
        {'name': 'Fish', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Spices', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Tausi Sauce', 'quantity': 1.0, 'unit': 'gram', 'category': 'Sauces'},
      ],
    },
    'Fish Fillet with Broccoli Flower': {
      'menu_item_name': 'Fish Fillet with Broccoli Flower',
      'ingredients': [
        {'name': 'Fish', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Onion', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Broccoli Flower', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Fish Fillet with Sweet Corn': {
      'menu_item_name': 'Fish Fillet with Sweet Corn',
      'ingredients': [
        {'name': 'Fish', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Cream Corn', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Hot Shrimp Salad': {
      'menu_item_name': 'Hot Shrimp Salad',
      'ingredients': [
        {'name': 'Shrimp Marinated 10x100', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Soy Sauce', 'quantity': 1.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Camaron Rebusado': {
      'menu_item_name': 'Camaron Rebusado',
      'ingredients': [
        {'name': 'Camaron', 'quantity': 1.0, 'unit': 'gram', 'category': 'Sauces'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Shrimp with Scramble Egg': {
      'menu_item_name': 'Shrimp with Scramble Egg',
      'ingredients': [
        {'name': 'Shrimp Marinated 10x100', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },

    // Roast and Soy Specialties
    'Lechon Macau': {
      'menu_item_name': 'Lechon Macau',
      'ingredients': [
        {'name': 'Lechon Macau', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Roasting'},
        {'name': 'Spices', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },
    'Roast Pork Asado': {
      'menu_item_name': 'Roast Pork Asado',
      'ingredients': [
        {'name': 'Roast Pork Asado', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Roasting'},
        {'name': 'Asado Sauce', 'quantity': 1.0, 'unit': 'bot', 'category': 'Sauces'},
        {'name': 'Sugar', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },
    'Roast Chicken': {
      'menu_item_name': 'Roast Chicken',
      'ingredients': [
        {'name': 'Chicken Marinated (Whole chicken)', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Spices', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },
    'Cold Cuts 3 Kinds (Asado, Lechon Macau, Roast Chicken)': {
      'menu_item_name': 'Cold Cuts 3 Kinds (Asado, Lechon Macau, Roast Chicken)',
      'ingredients': [
        {'name': 'Roast Pork Asado', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Roasting'},
        {'name': 'Lechon Macau', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Roasting'},
        {'name': 'Chicken Marinated (Whole chicken)', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
      ],
    },
    'Cold Cut 5 Kinds (Asado, Lechon Macau, Roast Chicken, Seaweeds, Century Egg)': {
      'menu_item_name': 'Cold Cut 5 Kinds (Asado, Lechon Macau, Roast Chicken, Seaweeds, Century Egg)',
      'ingredients': [
        {'name': 'Roast Pork Asado', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Roasting'},
        {'name': 'Lechon Macau', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Roasting'},
        {'name': 'Chicken Marinated (Whole chicken)', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Century Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
      ],
    },
    'Soyed Taufo': {
      'menu_item_name': 'Soyed Taufo',
      'ingredients': [
        {'name': 'Tofu', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Panda Soy Sauce', 'quantity': 1.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },

    // Pork
    'Sweet and Sour Pork': {
      'menu_item_name': 'Sweet and Sour Pork',
      'ingredients': [
        {'name': 'Sweet and Sour Pork 5x200', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Sweet and Sour Sauce', 'quantity': 1.0, 'unit': 'bot', 'category': 'Sauces'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Spareribs with OK Sauce': {
      'menu_item_name': 'Spareribs with OK Sauce',
      'ingredients': [
        {'name': 'Spicy Spareribs 5x300', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Lumpiang Shanghai': {
      'menu_item_name': 'Lumpiang Shanghai',
      'ingredients': [
        {'name': 'Lumpia Wrapper', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Siomai Meat (Lumpiang Shanghai)', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      ],
    },
    'Patatim with Cuapao': {
      'menu_item_name': 'Patatim with Cuapao',
      'ingredients': [
        {'name': 'Patatim', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Roasting'},
        {'name': 'Cuapao', 'quantity': 1.0, 'unit': 'order', 'category': 'Davids'},
      ],
    },
    'Spareribs Ampalaya with Tausi': {
      'menu_item_name': 'Spareribs Ampalaya with Tausi',
      'ingredients': [
        {'name': 'Spicy Spareribs 5x300', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Ampalaya', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Tausi', 'quantity': 1.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Spareribs with Salt and Pepper': {
      'menu_item_name': 'Spareribs with Salt and Pepper',
      'ingredients': [
        {'name': 'Spicy Spareribs 5x300', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Bell Pepper', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Minced Pork with Lettuce': {
      'menu_item_name': 'Minced Pork with Lettuce',
      'ingredients': [
        {'name': 'Slice Pork 10x100', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Lettuce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Kangkong with Lechon Macau': {
      'menu_item_name': 'Kangkong with Lechon Macau',
      'ingredients': [
        {'name': 'Lechon Macau', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Roasting'},
        {'name': 'Vinegar', 'quantity': 1.0, 'unit': 'bot', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },

    // Noodles
    'Pancit Canton': {
      'menu_item_name': 'Pancit Canton',
      'ingredients': [
        {'name': 'Pancit Canton/200Grams', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Pre-mix'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Panda Soy Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Seafood Canton': {
      'menu_item_name': 'Seafood Canton',
      'ingredients': [
        {'name': 'Pancit Canton/200Grams', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Pre-mix'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Panda Soy Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Slice Squid 5x200', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      ],
    },
    'Sliced Beef Hofan': {
      'menu_item_name': 'Sliced Beef Hofan',
      'ingredients': [
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Hofan', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },
    'Bihon Guisado': {
      'menu_item_name': 'Bihon Guisado',
      'ingredients': [
        {'name': 'Bihon', 'quantity': 1.0, 'unit': 'pack', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Birthday Noodles': {
      'menu_item_name': 'Birthday Noodles',
      'ingredients': [
        {'name': 'Egg Noodles', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Crispy Noodle Mixed Meat': {
      'menu_item_name': 'Crispy Noodle Mixed Meat',
      'ingredients': [
        {'name': 'Pancit Canton/200Grams', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Pre-mix'},
        {'name': 'Mixed Meat', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Crispy Noodle Mixed Seafood': {
      'menu_item_name': 'Crispy Noodle Mixed Seafood',
      'ingredients': [
        {'name': 'Pancit Canton/200Grams', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Pre-mix'},
        {'name': 'Mixed Seafood', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Bihon and Canton Mixed Guisado': {
      'menu_item_name': 'Bihon and Canton Mixed Guisado',
      'ingredients': [
        {'name': 'Bihon', 'quantity': 1.0, 'unit': 'pack', 'category': 'Groceries'},
        {'name': 'Pancit Canton/200Grams', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Pre-mix'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Pancit Canton with Lechon Macau': {
      'menu_item_name': 'Pancit Canton with Lechon Macau',
      'ingredients': [
        {'name': 'Pancit Canton/200Grams', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Pre-mix'},
        {'name': 'Lechon Macau', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Roasting'},
      ],
    },

    // Mami or Noodles
    'Roast Pork Asado Noodles': {
      'menu_item_name': 'Roast Pork Asado Noodles',
      'ingredients': [
        {'name': 'Mami Noodles', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Roast Pork Asado', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Roasting'},
        {'name': 'Panda Soy Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Beef Brisket Noodles': {
      'menu_item_name': 'Beef Brisket Noodles',
      'ingredients': [
        {'name': 'Egg Noodles', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Wanton Noodles': {
      'menu_item_name': 'Wanton Noodles',
      'ingredients': [
        {'name': 'Wonton', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Beef Brisket & Wonton Noodles': {
      'menu_item_name': 'Beef Brisket & Wonton Noodles',
      'ingredients': [
        {'name': 'Wonton', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      ],
    },
    'Wanton Soup (6pcs)': {
      'menu_item_name': 'Wanton Soup (6pcs)',
      'ingredients': [
        {'name': 'Wanton/22Grams', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Pre-mix'},
        {'name': 'Soup Stock', 'quantity': 1.0, 'unit': 'pack', 'category': 'Groceries'},
      ],
    },
    'Fishball Noodles': {
      'menu_item_name': 'Fishball Noodles',
      'ingredients': [
        {'name': 'Fish Ball', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Egg Noodles', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Squidball Noodles': {
      'menu_item_name': 'Squidball Noodles',
      'ingredients': [
        {'name': 'Squid Ball', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Egg Noodles', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Lobsterball Noodles': {
      'menu_item_name': 'Lobsterball Noodles',
      'ingredients': [
        {'name': 'Lobster Ball', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Egg Noodles', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },

    // Hot Pot Specialties
    'Minced Pork with Eggplant in Hot Pot': {
      'menu_item_name': 'Minced Pork with Eggplant in Hot Pot',
      'ingredients': [
        {'name': 'Premium Seafood', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Premium Broth', 'quantity': 1.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Fish Fillet with Taufo in Hot Pot': {
      'menu_item_name': 'Fish Fillet with Taufo in Hot Pot',
      'ingredients': [
        {'name': 'Mixed Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Tofu', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Hot Pot Broth', 'quantity': 1.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Lechon Kawali in Hot Pot': {
      'menu_item_name': 'Lechon Kawali in Hot Pot',
      'ingredients': [
        {'name': 'Lechon Macau', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Roasting'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Hot Pot Broth', 'quantity': 1.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Seafood Taufo in Hot Pot': {
      'menu_item_name': 'Seafood Taufo in Hot Pot',
      'ingredients': [
        {'name': 'Mixed Seafood', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Hot Pot Broth', 'quantity': 1.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Beef Brisket with Raddish in Hot Pot': {
      'menu_item_name': 'Beef Brisket with Raddish in Hot Pot',
      'ingredients': [
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Hot Pot Broth', 'quantity': 1.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Roast Pork Asado with Taufo in Hot Pot': {
      'menu_item_name': 'Roast Pork Asado with Taufo in Hot Pot',
      'ingredients': [
        {'name': 'Roast Pork Asado', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Roasting'},
        {'name': 'Tofu', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Hot Pot Broth', 'quantity': 1.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },

    // Fried Rice or Rice
    'Yang Chow Fried Rice': {
      'menu_item_name': 'Yang Chow Fried Rice',
      'ingredients': [
        {'name': 'YC Rice', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Beef Fried Rice': {
      'menu_item_name': 'Beef Fried Rice',
      'ingredients': [
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'YC Rice', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Chicken with Salted Fish (Fried Rice)': {
      'menu_item_name': 'Chicken with Salted Fish (Fried Rice)',
      'ingredients': [
        {'name': 'YC Rice', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Salted Fish', 'quantity': 1.0, 'unit': 'bot', 'category': 'Sauces'},
      ],
    },
    'Garlic Fried Rice': {
      'menu_item_name': 'Garlic Fried Rice',
      'ingredients': [
        {'name': 'YC Rice', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Garlic', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Pineapple Fried Rice': {
      'menu_item_name': 'Pineapple Fried Rice',
      'ingredients': [
        {'name': 'YC Rice', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Pineapple Chunks', 'quantity': 1.0, 'unit': 'bot', 'category': 'Groceries'},
      ],
    },
    'Steamed Rice (Platter)': {
      'menu_item_name': 'Steamed Rice (Platter)',
      'ingredients': [
        {'name': 'YC Rice', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Steamed Rice (1 Cup)': {
      'menu_item_name': 'Steamed Rice (1 Cup)',
      'ingredients': [
        {'name': 'YC Rice', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },

    // Dimsum
    'Siomai with Shrimp': {
      'menu_item_name': 'Siomai with Shrimp',
      'ingredients': [
        {'name': 'Shrimp Marinated 10x100', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Wonton Wrapper', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
      ],
    },
    'Quail Egg Siomai': {
      'menu_item_name': 'Quail Egg Siomai',
      'ingredients': [
        {'name': 'Quail Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Siomai Wrapper', 'quantity': 1.0, 'unit': 'pack', 'category': 'Groceries'},
      ],
    },
    'Wanton Dumplings': {
      'menu_item_name': 'Wanton Dumplings',
      'ingredients': [
        {'name': 'Wanton Meat', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Wanton Wrapper', 'quantity': 1.0, 'unit': 'pack', 'category': 'Groceries'},
      ],
    },
    'Shark\'s Fin Dumpling': {
      'menu_item_name': 'Shark\'s Fin Dumpling',
      'ingredients': [
        {'name': 'Sharksfin Meat', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Wanton Wrapper', 'quantity': 1.0, 'unit': 'pack', 'category': 'Groceries'},
      ],
    },
    'Asado Siopao': {
      'menu_item_name': 'Asado Siopao',
      'ingredients': [
        {'name': 'Asado Pao', 'quantity': 1.0, 'unit': 'order', 'category': 'Davids'},
      ],
    },
    'Bola-Bola Siopao': {
      'menu_item_name': 'Bola-Bola Siopao',
      'ingredients': [
        {'name': 'Bola Pao', 'quantity': 1.0, 'unit': 'order', 'category': 'Davids'},
      ],
    },
    'Tausi Spareribs': {
      'menu_item_name': 'Tausi Spareribs',
      'ingredients': [
        {'name': 'Tausi Sauce', 'quantity': 1.0, 'unit': 'gram', 'category': 'Sauces'},
        {'name': 'Spicy Spareribs 5x300', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      ],
    },
    'Cuapao / Mantau': {
      'menu_item_name': 'Cuapao / Mantau',
      'ingredients': [
        {'name': 'Cuapao', 'quantity': 1.0, 'unit': 'order', 'category': 'Davids'},
      ],
    },
    'Chicken Feet': {
      'menu_item_name': 'Chicken Feet',
      'ingredients': [
        {'name': 'Chicken Feet', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Davids'},
      ],
    },
    'Hakaw': {
      'menu_item_name': 'Hakaw',
      'ingredients': [
        {'name': 'Hakaw', 'quantity': 1.0, 'unit': 'order', 'category': 'Davids'},
      ],
    },
    'Spinach Dumpling': {
      'menu_item_name': 'Spinach Dumpling',
      'ingredients': [
        {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables '},
        {'name': 'Siomai Wrapper', 'quantity': 1.0, 'unit': 'pack', 'category': 'Groceries'},
      ],
    },
    'Special Siopao': {
      'menu_item_name': 'Special Siopao',
      'ingredients': [
        {'name': 'Asado Pao', 'quantity': 1.0, 'unit': 'order', 'category': 'Davids'},
      ],
    },

    // Congee
    'Pork Century Egg Congee': {
      'menu_item_name': 'Pork Century Egg Congee',
      'ingredients': [
        {'name': 'Lugaw', 'quantity': 1.0, 'unit': 'pack', 'category': 'Roasting'},
        {'name': 'Century Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Ginger', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Pork Liver Congee': {
      'menu_item_name': 'Pork Liver Congee',
      'ingredients': [
        {'name': 'Lugaw', 'quantity': 1.0, 'unit': 'pack', 'category': 'Roasting'},
        {'name': 'Liver Marinated', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Ginger', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Seafood Congee': {
      'menu_item_name': 'Seafood Congee',
      'ingredients': [
        {'name': 'Lugaw', 'quantity': 1.0, 'unit': 'pack', 'category': 'Roasting'},
        {'name': 'Mixed Seafood', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Ginger', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Sliced Fish Congee': {
      'menu_item_name': 'Sliced Fish Congee',
      'ingredients': [
        {'name': 'Lugaw', 'quantity': 1.0, 'unit': 'pack', 'category': 'Roasting'},
        {'name': 'Fish Cake', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Ginger', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Beef Balls Congee': {
      'menu_item_name': 'Beef Balls Congee',
      'ingredients': [
        {'name': 'Lugaw', 'quantity': 1.0, 'unit': 'pack', 'category': 'Roasting'},
        {'name': 'Ginger', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Sliced Chicken Congee': {
      'menu_item_name': 'Sliced Chicken Congee',
      'ingredients': [
        {'name': 'Lugaw', 'quantity': 1.0, 'unit': 'pack', 'category': 'Roasting'},
        {'name': 'Slice Chicken 5x200', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Ginger', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      ],
    },
    'Century Egg': {
      'menu_item_name': 'Century Egg',
      'ingredients': [
        {'name': 'Lugaw', 'quantity': 1.0, 'unit': 'pack', 'category': 'Roasting'},
        {'name': 'Century Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Ginger', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Fresh Egg': {
      'menu_item_name': 'Fresh Egg',
      'ingredients': [
        {'name': 'Lugaw', 'quantity': 1.0, 'unit': 'pack', 'category': 'Roasting'},
        {'name': 'Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
      ],
    },

    // Chicken
    'Buttered Chicken': {
      'menu_item_name': 'Buttered Chicken',
      'ingredients': [
        {'name': 'Buttered Chicken 5x350Grams', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      ],
    },
    'YC Fried Chicken': {
      'menu_item_name': 'YC Fried Chicken',
      'ingredients': [
        {'name': 'Chicken Marinated (Whole chicken)', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Flour', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },
    'Sweet and Sour Chicken': {
      'menu_item_name': 'Sweet and Sour Chicken',
      'ingredients': [
        {'name': 'Chicken Marinated (Whole chicken)', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Sweet and Sour Sauce', 'quantity': 1.0, 'unit': 'bot', 'category': 'Sauces'},
      ],
    },
    'Fried Chicken with Salted Egg Yolk': {
      'menu_item_name': 'Fried Chicken with Salted Egg Yolk',
      'ingredients': [
        {'name': 'Chicken Marinated (Whole chicken)', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Salted Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
      ],
    },
    'Lemon Chicken': {
      'menu_item_name': 'Lemon Chicken',
      'ingredients': [
        {'name': 'Chicken Marinated (Whole chicken)', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Lemon Sauce', 'quantity': 1.0, 'unit': 'bot', 'category': 'Sauces'},
      ],
    },
    'Sliced Chicken with Cashew Nuts and Quail Egg': {
      'menu_item_name': 'Sliced Chicken with Cashew Nuts and Quail Egg',
      'ingredients': [
        {'name': 'Chicken Marinated (Whole chicken)', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Peanuts', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Quail Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
      ],
    },

    // Beef
    'Beef with Broccoli Leaves (Kaylan)': {
      'menu_item_name': 'Beef with Broccoli Leaves (Kaylan)',
      'ingredients': [
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Broccoli Flower', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Bell Pepper', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Beef with Broccoli Flower': {
      'menu_item_name': 'Beef with Broccoli Flower',
      'ingredients': [
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Broccoli Flower', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Beef with Ampalaya':
    {
      'menu_item_name': 'Beef with Ampalaya',
      'ingredients': [
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Ampalaya', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Beef Steak Chinese Style': {
      'menu_item_name': 'Beef Steak Chinese Style',
      'ingredients': [
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Beef with Black Pepper': {
      'menu_item_name': 'Beef with Black Pepper',
      'ingredients': [
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Black Pepper', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Beef with Green Pepper': {
      'menu_item_name': 'Beef with Green Pepper',
      'ingredients': [
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Bell Pepper', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Beef with Scramble Egg': {
      'menu_item_name': 'Beef with Scramble Egg',
      'ingredients': [
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Slice Beef Mango': {
      'menu_item_name': 'Slice Beef Mango',
      'ingredients': [
        {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Mango', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },

    // Appetizer
    'Jelly Fish with Century Egg': {
      'menu_item_name': 'Jelly Fish Century Egg',
      'ingredients': [
        {'name': 'Jelly Fish', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Century Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Sesame Seeds', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'}, 
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Jelly Fish': {
      'menu_item_name': 'Jelly Fish',
      'ingredients': [
        {'name': 'Jelly Fish', 'quantity': 1.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Sesame Seeds', 'quantity': 1.0, 'unit': 'gram', 'category': 'Vegetables'},  
        {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      ],
    },
    'Calamares': {
      'menu_item_name': 'Calamares',
      'ingredients': [
        {'name': 'Slice Squid 5x200', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
        {'name': 'Flour', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },

    // Drinks
    'Natures Spring 350ML': {
      'menu_item_name': 'Natures Spring 350ML',
      'ingredients': [
        {'name': 'Nature Spring 350ML', 'quantity': 1.0, 'unit': 'box', 'category': 'Drinks'},
      ],
    },
    'Lipton Iced Tea Lemon Can': {
      'menu_item_name': 'Lipton Iced Tea Lemon Can',
      'ingredients': [
        {'name': 'Lipton Iced Tea', 'quantity': 1.0, 'unit': 'can', 'category': 'Drinks'},
      ],
    },
    '7UP Can': {
      'menu_item_name': '7UP Can',
      'ingredients': [
        {'name': '7up', 'quantity': 1.0, 'unit': 'can', 'category': 'Drinks'},
      ],
    },
    'Pepsi Regular Bottle': {
      'menu_item_name': 'Pepsi Regular Bottle',
      'ingredients': [
        {'name': 'Pepsi Regular', 'quantity': 1.0, 'unit': 'bot', 'category': 'Drinks'},
      ],
    },
    'Pepsi Max Can': {
      'menu_item_name': 'Pepsi Max Can',
      'ingredients': [
        {'name': 'Pepsi Max Can', 'quantity': 1.0, 'unit': 'can', 'category': 'Drinks'},
      ],
    },
    'Mirinda Can': {
      'menu_item_name': 'Mirinda Can',
      'ingredients': [
        {'name': 'Mirinda', 'quantity': 1.0, 'unit': 'can', 'category': 'Drinks'},
      ],
    },
    'Mountain Dew Can': {
      'menu_item_name': 'Mountain Dew Can',
      'ingredients': [
        {'name': 'Mountain Dew', 'quantity': 1.0, 'unit': 'can', 'category': 'Drinks'},
      ],
    },
    'Mug Root Beer Can': {
      'menu_item_name': 'Mug Root Beer Can',
      'ingredients': [
        {'name': 'Mug Root Beer', 'quantity': 1.0, 'unit': 'can', 'category': 'Drinks'},
      ],
    },
    'San Mig Light Bottle': {
      'menu_item_name': 'San Mig Light Bottle',
      'ingredients': [
        {'name': 'San Mig Light', 'quantity': 1.0, 'unit': 'bot', 'category': 'Drinks'},
      ],
    },
    '7UP 1.5 Liter': {
      'menu_item_name': '7UP 1.5 Liter',
      'ingredients': [
        {'name': '7up (1.5L)', 'quantity': 1.0, 'unit': 'bot', 'category': 'Drinks'},
      ],
    },
    'Mirinda 1.5 Liter': {
      'menu_item_name': 'Mirinda 1.5 Liter',
      'ingredients': [
        {'name': 'Mirinda (1.5L)', 'quantity': 1.0, 'unit': 'bot', 'category': 'Drinks'},
      ],
    },
    'Mountain Dew 1.5 Liter': {
      'menu_item_name': 'Mountain Dew 1.5 Liter',
      'ingredients': [
        {'name': 'Mountain Dew (1.5L)', 'quantity': 1.0, 'unit': 'bot', 'category': 'Drinks'},
      ],
    },
    'Pepsi Regular 1.5 Liter': {
      'menu_item_name': 'Pepsi Regular 1.5 Liter',
      'ingredients': [
        {'name': 'Pepsi Regular (1.5L)', 'quantity': 1.0, 'unit': 'bot', 'category': 'Drinks'},
      ],
    },
    'Pepsi Max 1.5 Liter': {
      'menu_item_name': 'Pepsi Max 1.5 Liter',
      'ingredients': [
        {'name': 'Pepsi Max (1.5L)', 'quantity': 1.0, 'unit': 'bot', 'category': 'Drinks'},
      ],
    },
  };

  Future<Recipe?> getRecipeForMenuItem(String menuItemName) async {
    try {
      // First try to get from database (if you implement recipes table in future)
      // For now, use hardcoded recipes
      final recipeData = _recipeDatabase[menuItemName];
      
      if (recipeData == null) {
        // Return a default recipe if no specific recipe found
        return Recipe(
          menuItemName: menuItemName,
          ingredients: [
            RecipeIngredient(
              name: 'Mixed Ingredients',
              quantity: 1.0,
              unit: 'serving',
              category: 'Mixed',
            ),
          ],
          instructions: 'Standard preparation',
        );
      }

      return Recipe.fromMap(recipeData);
    } catch (e) {
      debugPrint('Error getting recipe: $e');
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
          // Calculate deduction - always deduct only 1 unit per ingredient, regardless of order quantity
          final int deduction = 1;
          final int newQty = (currentQty - deduction).clamp(0, 999999).toInt();

          await Supabase.instance.client
              .from('kitchen_inventory')
              .update({'quantity': newQty})
              .eq('id', matchingItem['id']);
          
          debugPrint('Auto-Inventory: Deducted $deduction unit of "${matchingItem['name']}" for "$menuItemName" (ordered: $orderQuantity). New stock: $newQty');
        } else {
          debugPrint('Auto-Inventory: No matching inventory item found for ingredient "${ingredient.name}"');
        }
      }
    } catch (e) {
      debugPrint('Error during inventory deduction: $e');
    }
  }

  String _calculateStockStatus(int inventoryQuantity, double requiredQuantity) {
    if (inventoryQuantity == 0) return 'OUT OF STOCK';
    if (inventoryQuantity < requiredQuantity) return 'INSUFFICIENT';
    if (inventoryQuantity < requiredQuantity * 2) return 'LOW STOCK';
    return 'AVAILABLE';
  }
}
