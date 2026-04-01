class RecipeIngredient {
  final String name;
  final double quantity;
  final String unit;
  final String? category;
  final int? inventoryItemId; // Reference to actual inventory item

  RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.category,
    this.inventoryItemId,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      name: map['name'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      category: map['category'],
      inventoryItemId: map['inventory_item_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'inventory_item_id': inventoryItemId,
    };
  }
}

class Recipe {
  final String menuItemName;
  final List<RecipeIngredient> ingredients;
  final String? instructions;

  Recipe({
    required this.menuItemName,
    required this.ingredients,
    this.instructions,
  });

  factory Recipe.fromMap(Map<String, dynamic> map) {
    final ingredientsList = (map['ingredients'] as List<dynamic>?)
        ?.map((ingredient) => RecipeIngredient.fromMap(ingredient))
        .toList() ?? [];

    return Recipe(
      menuItemName: map['menu_item_name'] ?? '',
      ingredients: ingredientsList,
      instructions: map['instructions'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menu_item_name': menuItemName,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
      'instructions': instructions,
    };
  }
}
