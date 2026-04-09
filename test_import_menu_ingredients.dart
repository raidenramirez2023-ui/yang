import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/services/add_menu_ingredients_to_inventory.dart';

void main() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  print('Testing Menu Ingredients Import...\n');

  try {
    final importer = MenuIngredientsImporter();

    // First show what will be imported
    print('=== Checking for Missing Ingredients ===');
    await importer.showMissingIngredients();

    // Then perform the import
    print('\n=== Starting Import ===');
    await importer.addAllMenuIngredientsToInventory();

    print('\n=== Import Completed Successfully! ===');
  } catch (e) {
    print('Import failed: $e');
  }
}
