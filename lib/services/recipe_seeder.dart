import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'recipe_service.dart';

class RecipeSeeder {
  static Future<void> seedRecipesToDatabase(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Hardcoded recipes have been removed. Please add recipes through the Admin Menu Management page.')),
      );
    } catch (e) {
      debugPrint('Error seeding recipes: $e');
    }
  }
}
