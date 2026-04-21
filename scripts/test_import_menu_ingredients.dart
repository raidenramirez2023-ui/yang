import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/add_menu_ingredients_to_inventory.dart';

void main() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  debugPrint('Testing Menu Ingredients Import...\n');

  try {
    final importer = MenuIngredientsImporter();

    // First show what will be imported
    debugPrint('=== Checking for Missing Ingredients ===');
    await importer.showMissingIngredients();

    // Then perform the import
    debugPrint('\n=== Starting Import ===');
    await importer.addAllMenuIngredientsToInventory();

    debugPrint('\n=== Import Completed Successfully! ===');
  } catch (e) {
    debugPrint('Import failed: $e');
  }
}
