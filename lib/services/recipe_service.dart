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
    'Family Bundle A': {
      'menu_item_name': 'Family Bundle A',
      'ingredients': [
        {'name': 'Chicken', 'quantity': 2.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Pork', 'quantity': 1.5, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Rice', 'quantity': 3.0, 'unit': 'kilos', 'category': 'Groceries'},
        {'name': 'Soy Sauce', 'quantity': 500.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Vegetables', 'quantity': 2.0, 'unit': 'kilos', 'category': 'Vegetables'},
      ],
    },
    'Family Bundle B': {
      'menu_item_name': 'Family Bundle B',
      'ingredients': [
        {'name': 'Beef', 'quantity': 2.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Noodles', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Groceries'},
        {'name': 'Soy Sauce', 'quantity': 400.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Vegetables', 'quantity': 1.5, 'unit': 'kilos', 'category': 'Vegetables'},
        {'name': 'Eggs', 'quantity': 12.0, 'unit': 'pcs', 'category': 'Fresh'},
      ],
    },
    'Family Bundle C': {
      'menu_item_name': 'Family Bundle C',
      'ingredients': [
        {'name': 'Seafood', 'quantity': 3.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Rice', 'quantity': 4.0, 'unit': 'kilos', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 2.5, 'unit': 'kilos', 'category': 'Vegetables'},
        {'name': 'Soy Sauce', 'quantity': 600.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Garlic', 'quantity': 500.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Family Bundle D': {
      'menu_item_name': 'Family Bundle D',
      'ingredients': [
        {'name': 'Chicken', 'quantity': 3.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Pork', 'quantity': 2.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Beef', 'quantity': 1.5, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Seafood', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Rice', 'quantity': 5.0, 'unit': 'kilos', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 3.0, 'unit': 'kilos', 'category': 'Vegetables'},
      ],
    },
    'Overload Meal': {
      'menu_item_name': 'Overload Meal',
      'ingredients': [
        {'name': 'Chicken', 'quantity': 300.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Pork', 'quantity': 200.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Rice', 'quantity': 500.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 200.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },

    // Vegetables
    'Chopsuey': {
      'menu_item_name': 'Chopsuey',
      'ingredients': [
        {'name': 'Vegetables', 'quantity': 400.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Soy Sauce', 'quantity': 100.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Garlic', 'quantity': 50.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Onion', 'quantity': 100.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },
    'Hot Salad': {
      'menu_item_name': 'Hot Salad',
      'ingredients': [
        {'name': 'Vegetables', 'quantity': 350.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Soy Sauce', 'quantity': 80.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Garlic', 'quantity': 30.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Bihon Guisado': {
      'menu_item_name': 'Bihon Guisado',
      'ingredients': [
        {'name': 'Bihon Noodles', 'quantity': 300.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 200.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Soy Sauce', 'quantity': 90.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Garlic', 'quantity': 40.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Fresh Egg': {
      'menu_item_name': 'Fresh Egg',
      'ingredients': [
        {'name': 'Eggs', 'quantity': 2.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Salt', 'quantity': 5.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Cooking Oil', 'quantity': 20.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Century Egg': {
      'menu_item_name': 'Century Egg',
      'ingredients': [
        {'name': 'Century Egg', 'quantity': 2.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Ginger', 'quantity': 20.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 30.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Jelly Fish Century Egg': {
      'menu_item_name': 'Jelly Fish Century Egg',
      'ingredients': [
        {'name': 'Jelly Fish', 'quantity': 200.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Century Egg', 'quantity': 2.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Soy Sauce', 'quantity': 60.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },

    // Special Noodles
    'Yang Chow Fried Noodles': {
      'menu_item_name': 'Yang Chow Fried Noodles',
      'ingredients': [
        {'name': 'Noodles', 'quantity': 400.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 200.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Soy Sauce', 'quantity': 120.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Eggs', 'quantity': 2.0, 'unit': 'pcs', 'category': 'Fresh'},
      ],
    },
    'Pancit Canton': {
      'menu_item_name': 'Pancit Canton',
      'ingredients': [
        {'name': 'Canton Noodles', 'quantity': 350.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 150.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Soy Sauce', 'quantity': 100.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Pork', 'quantity': 150.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Big Bowl Noodles': {
      'menu_item_name': 'Big Bowl Noodles',
      'ingredients': [
        {'name': 'Noodles', 'quantity': 500.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Chicken', 'quantity': 200.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 250.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },
    'Big Bowl Wonton Noodles': {
      'menu_item_name': 'Big Bowl Wonton Noodles',
      'ingredients': [
        {'name': 'Wonton Noodles', 'quantity': 450.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Wonton', 'quantity': 8.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Chicken', 'quantity': 180.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Sotanghon Bihon': {
      'menu_item_name': 'Sotanghon Bihon',
      'ingredients': [
        {'name': 'Sotanghon', 'quantity': 200.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Bihon', 'quantity': 200.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 180.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Soy Sauce', 'quantity': 80.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Wanton Noodles': {
      'menu_item_name': 'Wanton Noodles',
      'ingredients': [
        {'name': 'Wanton Noodles', 'quantity': 400.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Wanton', 'quantity': 6.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Chicken', 'quantity': 150.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Beef Fried Rice Noodles': {
      'menu_item_name': 'Beef Fried Rice Noodles',
      'ingredients': [
        {'name': 'Beef', 'quantity': 200.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Rice Noodles', 'quantity': 300.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 150.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Soy Sauce', 'quantity': 90.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },

    // Soup
    'Corn Soup': {
      'menu_item_name': 'Corn Soup',
      'ingredients': [
        {'name': 'Corn', 'quantity': 200.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Chicken', 'quantity': 150.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Eggs', 'quantity': 2.0, 'unit': 'pcs', 'category': 'Fresh'},
      ],
    },
    'Wonton Soup': {
      'menu_item_name': 'Wonton Soup',
      'ingredients': [
        {'name': 'Wonton', 'quantity': 10.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Chicken', 'quantity': 200.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 100.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },
    'Hot Sour Soup': {
      'menu_item_name': 'Hot Sour Soup',
      'ingredients': [
        {'name': 'Vegetables', 'quantity': 250.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Tofu', 'quantity': 150.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vinegar', 'quantity': 80.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Special Soup': {
      'menu_item_name': 'Special Soup',
      'ingredients': [
        {'name': 'Mixed Seafood', 'quantity': 200.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 180.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Chicken Stock', 'quantity': 500.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Noodle Soup': {
      'menu_item_name': 'Noodle Soup',
      'ingredients': [
        {'name': 'Noodles', 'quantity': 300.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Beef', 'quantity': 180.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 120.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },
    'Plain Congee': {
      'menu_item_name': 'Plain Congee',
      'ingredients': [
        {'name': 'Rice', 'quantity': 300.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Water', 'quantity': 1000.0, 'unit': 'ml', 'category': 'Groceries'},
        {'name': 'Ginger', 'quantity': 30.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Beef Congee': {
      'menu_item_name': 'Beef Congee',
      'ingredients': [
        {'name': 'Rice', 'quantity': 250.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Beef', 'quantity': 150.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Ginger', 'quantity': 40.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },

    // Seafood
    'Garlic Shrimp': {
      'menu_item_name': 'Garlic Shrimp',
      'ingredients': [
        {'name': 'Shrimp', 'quantity': 300.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Garlic', 'quantity': 100.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 80.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Steamed Fish': {
      'menu_item_name': 'Steamed Fish',
      'ingredients': [
        {'name': 'Fish', 'quantity': 400.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Ginger', 'quantity': 50.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 100.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Big Fried Oyster': {
      'menu_item_name': 'Big Fried Oyster',
      'ingredients': [
        {'name': 'Oyster', 'quantity': 350.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Flour', 'quantity': 100.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Eggs', 'quantity': 2.0, 'unit': 'pcs', 'category': 'Fresh'},
      ],
    },
    'Tiger Prawns Oyster': {
      'menu_item_name': 'Tiger Prawns Oyster',
      'ingredients': [
        {'name': 'Tiger Prawns', 'quantity': 400.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Oyster', 'quantity': 200.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Garlic', 'quantity': 80.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Jelly Fish': {
      'menu_item_name': 'Jelly Fish',
      'ingredients': [
        {'name': 'Jelly Fish', 'quantity': 280.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vinegar', 'quantity': 60.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Garlic', 'quantity': 40.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Calamares': {
      'menu_item_name': 'Calamares',
      'ingredients': [
        {'name': 'Squid', 'quantity': 300.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Flour', 'quantity': 120.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Eggs', 'quantity': 2.0, 'unit': 'pcs', 'category': 'Fresh'},
      ],
    },

    // Roast and Soy Specialties
    'Roast Duck': {
      'menu_item_name': 'Roast Duck',
      'ingredients': [
        {'name': 'Duck', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 200.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Spices', 'quantity': 50.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },
    'Soy Chicken': {
      'menu_item_name': 'Soy Chicken',
      'ingredients': [
        {'name': 'Chicken', 'quantity': 1.0, 'unit': 'kilos', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 300.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Garlic', 'quantity': 100.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Lemon Chicken': {
      'menu_item_name': 'Lemon Chicken',
      'ingredients': [
        {'name': 'Chicken', 'quantity': 800.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Lemon', 'quantity': 2.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Flour', 'quantity': 200.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },
    'Buttered Chicken': {
      'menu_item_name': 'Buttered Chicken',
      'ingredients': [
        {'name': 'Chicken', 'quantity': 700.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Butter', 'quantity': 150.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Garlic', 'quantity': 80.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Chicken Feet': {
      'menu_item_name': 'Chicken Feet',
      'ingredients': [
        {'name': 'Chicken Feet', 'quantity': 400.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 120.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Chili', 'quantity': 30.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Red Pork Asado': {
      'menu_item_name': 'Red Pork Asado',
      'ingredients': [
        {'name': 'Pork', 'quantity': 500.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 150.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Sugar', 'quantity': 100.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },

    // Pork
    'Sweet & Sour Pork': {
      'menu_item_name': 'Sweet & Sour Pork',
      'ingredients': [
        {'name': 'Pork', 'quantity': 400.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vinegar', 'quantity': 100.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Sugar', 'quantity': 80.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 200.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },
    'Pork Asado': {
      'menu_item_name': 'Pork Asado',
      'ingredients': [
        {'name': 'Pork', 'quantity': 500.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 150.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Sugar', 'quantity': 100.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },
    'Cuapao Mantau': {
      'menu_item_name': 'Cuapao Mantau',
      'ingredients': [
        {'name': 'Pork', 'quantity': 300.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Mantau', 'quantity': 4.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Soy Sauce', 'quantity': 80.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Asado Siopao': {
      'menu_item_name': 'Asado Siopao',
      'ingredients': [
        {'name': 'Pork', 'quantity': 400.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Flour', 'quantity': 500.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Sugar', 'quantity': 100.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },
    'Big Bowl Siopao': {
      'menu_item_name': 'Big Bowl Siopao',
      'ingredients': [
        {'name': 'Pork', 'quantity': 350.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Flour', 'quantity': 400.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Soy Sauce', 'quantity': 90.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Lumpiang Shanghai': {
      'menu_item_name': 'Lumpiang Shanghai',
      'ingredients': [
        {'name': 'Pork', 'quantity': 300.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Lumpia Wrapper', 'quantity': 20.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 150.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },

    // Noodles
    'Lo Mein': {
      'menu_item_name': 'Lo Mein',
      'ingredients': [
        {'name': 'Lo Mein Noodles', 'quantity': 350.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 200.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Soy Sauce', 'quantity': 100.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Sotanghon': {
      'menu_item_name': 'Sotanghon',
      'ingredients': [
        {'name': 'Sotanghon', 'quantity': 300.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Chicken', 'quantity': 150.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 120.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },

    // Mami or Noodles
    'Beef Mami': {
      'menu_item_name': 'Beef Mami',
      'ingredients': [
        {'name': 'Mami Noodles', 'quantity': 300.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Beef', 'quantity': 200.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Beef Stock', 'quantity': 400.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Chicken Mami': {
      'menu_item_name': 'Chicken Mami',
      'ingredients': [
        {'name': 'Mami Noodles', 'quantity': 280.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Chicken', 'quantity': 180.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Chicken Stock', 'quantity': 350.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },

    // Hot Pot Specialties
    'Seafood Hot Pot': {
      'menu_item_name': 'Seafood Hot Pot',
      'ingredients': [
        {'name': 'Mixed Seafood', 'quantity': 500.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 300.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Hot Pot Broth', 'quantity': 800.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Vegetable Hot Pot': {
      'menu_item_name': 'Vegetable Hot Pot',
      'ingredients': [
        {'name': 'Mixed Vegetables', 'quantity': 600.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Tofu', 'quantity': 200.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Hot Pot Broth', 'quantity': 600.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Big Bowl Hot Pot': {
      'menu_item_name': 'Big Bowl Hot Pot',
      'ingredients': [
        {'name': 'Mixed Meat', 'quantity': 400.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 250.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Hot Pot Broth', 'quantity': 700.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'MPE Hot Pot': {
      'menu_item_name': 'MPE Hot Pot',
      'ingredients': [
        {'name': 'Premium Seafood', 'quantity': 450.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 280.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Premium Broth', 'quantity': 750.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },

    // Fried Rice or Rice
    'Yang Chow Fried Rice': {
      'menu_item_name': 'Yang Chow Fried Rice',
      'ingredients': [
        {'name': 'Rice', 'quantity': 400.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Eggs', 'quantity': 2.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 150.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },
    'Plain Rice': {
      'menu_item_name': 'Plain Rice',
      'ingredients': [
        {'name': 'Rice', 'quantity': 300.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Water', 'quantity': 450.0, 'unit': 'ml', 'category': 'Groceries'},
      ],
    },
    'Chinese Style Fried Rice': {
      'menu_item_name': 'Chinese Style Fried Rice',
      'ingredients': [
        {'name': 'Rice', 'quantity': 350.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Soy Sauce', 'quantity': 80.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Eggs', 'quantity': 2.0, 'unit': 'pcs', 'category': 'Fresh'},
      ],
    },
    'Overload Meal Rice': {
      'menu_item_name': 'Overload Meal Rice',
      'ingredients': [
        {'name': 'Rice', 'quantity': 500.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Mixed Meat', 'quantity': 300.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 200.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },

    // Dimsum
    'Siomai': {
      'menu_item_name': 'Siomai',
      'ingredients': [
        {'name': 'Pork', 'quantity': 250.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Shrimp', 'quantity': 100.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Wonton Wrapper', 'quantity': 20.0, 'unit': 'pcs', 'category': 'Groceries'},
      ],
    },
    'Hakaw': {
      'menu_item_name': 'Hakaw',
      'ingredients': [
        {'name': 'Shrimp', 'quantity': 300.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Bamboo Shoots', 'quantity': 80.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Wonton Wrapper', 'quantity': 15.0, 'unit': 'pcs', 'category': 'Groceries'},
      ],
    },
    'Patatim Cuapao': {
      'menu_item_name': 'Patatim Cuapao',
      'ingredients': [
        {'name': 'Pork Leg', 'quantity': 400.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Mantau', 'quantity': 4.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Soy Sauce', 'quantity': 120.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },

    // Congee
    'Plain Lugaw': {
      'menu_item_name': 'Plain Lugaw',
      'ingredients': [
        {'name': 'Rice', 'quantity': 250.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Water', 'quantity': 800.0, 'unit': 'ml', 'category': 'Groceries'},
        {'name': 'Ginger', 'quantity': 30.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Century Egg Congee': {
      'menu_item_name': 'Century Egg Congee',
      'ingredients': [
        {'name': 'Rice', 'quantity': 200.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Century Egg', 'quantity': 2.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Ginger', 'quantity': 40.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Corn Noodle Congee': {
      'menu_item_name': 'Corn Noodle Congee',
      'ingredients': [
        {'name': 'Rice', 'quantity': 180.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Corn', 'quantity': 150.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Noodles', 'quantity': 100.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },

    // Chicken
    'Chicken Adobo': {
      'menu_item_name': 'Chicken Adobo',
      'ingredients': [
        {'name': 'Chicken', 'quantity': 600.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 150.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Vinegar', 'quantity': 100.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Kung Pao Chicken': {
      'menu_item_name': 'Kung Pao Chicken',
      'ingredients': [
        {'name': 'Chicken', 'quantity': 500.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Peanuts', 'quantity': 80.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Chili', 'quantity': 40.0, 'unit': 'gram', 'category': 'Fresh'},
      ],
    },
    'Yang Chow Fried Chicken': {
      'menu_item_name': 'Yang Chow Fried Chicken',
      'ingredients': [
        {'name': 'Chicken', 'quantity': 550.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Flour', 'quantity': 150.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Spices', 'quantity': 60.0, 'unit': 'gram', 'category': 'Groceries'},
      ],
    },

    // Beef
    'Beef Broccoli': {
      'menu_item_name': 'Beef Broccoli',
      'ingredients': [
        {'name': 'Beef', 'quantity': 400.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Broccoli', 'quantity': 300.0, 'unit': 'gram', 'category': 'Vegetables'},
        {'name': 'Soy Sauce', 'quantity': 120.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Beef Steak': {
      'menu_item_name': 'Beef Steak',
      'ingredients': [
        {'name': 'Beef', 'quantity': 450.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Soy Sauce', 'quantity': 140.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Lemon', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Fresh'},
      ],
    },
    'Beef Black Pepper': {
      'menu_item_name': 'Beef Black Pepper',
      'ingredients': [
        {'name': 'Beef', 'quantity': 400.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Black Pepper', 'quantity': 30.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Soy Sauce', 'quantity': 100.0, 'unit': 'ml', 'category': 'Sauces'},
      ],
    },
    'Beef Fried Rice': {
      'menu_item_name': 'Beef Fried Rice',
      'ingredients': [
        {'name': 'Beef', 'quantity': 200.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Rice', 'quantity': 400.0, 'unit': 'gram', 'category': 'Groceries'},
        {'name': 'Eggs', 'quantity': 2.0, 'unit': 'pcs', 'category': 'Fresh'},
        {'name': 'Vegetables', 'quantity': 100.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },

    // Appetizer
    'Lumpia Shanghai': {
      'menu_item_name': 'Lumpia Shanghai',
      'ingredients': [
        {'name': 'Pork', 'quantity': 200.0, 'unit': 'gram', 'category': 'Fresh'},
        {'name': 'Lumpia Wrapper', 'quantity': 15.0, 'unit': 'pcs', 'category': 'Groceries'},
        {'name': 'Vegetables', 'quantity': 100.0, 'unit': 'gram', 'category': 'Vegetables'},
      ],
    },
    'Soy Sauce': {
      'menu_item_name': 'Soy Sauce',
      'ingredients': [
        {'name': 'Soy Sauce', 'quantity': 100.0, 'unit': 'ml', 'category': 'Sauces'},
        {'name': 'Garlic', 'quantity': 20.0, 'unit': 'gram', 'category': 'Fresh'},
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
