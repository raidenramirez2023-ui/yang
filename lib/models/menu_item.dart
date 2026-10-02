import 'package:flutter/material.dart';

class MenuItem {
  final String? id;
  String name;
  double price;
  final String category;
  String? customImagePath;
  final String fallbackImagePath;
  final Color color;
  final String? description;

  MenuItem({
    this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.fallbackImagePath,
    required this.color,
    this.customImagePath,
    this.description,
  });

  static Color _parseColor(dynamic colorVal) {
    if (colorVal == null) return Colors.orange;
    if (colorVal is int) return Color(colorVal);
    if (colorVal is String) {
      String hex = colorVal.trim().replaceAll('#', '');
      if (hex.isEmpty) return Colors.orange;
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      if (hex.length == 8) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) return Color(parsed);
      }
    }
    return Colors.orange;
  }

  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? '',
      fallbackImagePath: json['fallbackimagepath'] as String? ?? json['fallback_image_path'] as String? ?? '',
      customImagePath: json['customimagepath'] as String? ?? json['custom_image_path'] as String?,
      color: _parseColor(json['color']),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'name': name,
      'price': price,
      'category': category,
      'fallbackimagepath': fallbackImagePath,
      'customimagepath': customImagePath,
      'color': _colorToHex(color),
      'description': description,
    };
    if (id != null) {
      data['id'] = id!;
    }
    return data;
  }
}

class CartItem {
  final MenuItem item;
  int quantity;

  CartItem(this.item, this.quantity);

  String get name => item.name;
  double get price => item.price;
}

/// Represents a dish that may have multiple portion/serving sizes (e.g. Regular & Large, Half & Whole)
class GroupedMenuItem {
  final String baseName;
  final String category;
  final String? description;
  final String? customImagePath;
  final String fallbackImagePath;
  final Color color;
  final List<MenuItem> variants;

  GroupedMenuItem({
    required this.baseName,
    required this.category,
    required this.variants,
    this.description,
    this.customImagePath,
    required this.fallbackImagePath,
    required this.color,
  });

  bool get hasVariants => variants.length > 1;

  MenuItem get primaryItem => variants.isNotEmpty
      ? variants.first
      : MenuItem(
          name: baseName,
          price: 0,
          category: category,
          fallbackImagePath: fallbackImagePath,
          color: color,
        );

  double get minPrice {
    if (variants.isEmpty) return 0.0;
    return variants.map((e) => e.price).reduce((a, b) => a < b ? a : b);
  }

  double get maxPrice {
    if (variants.isEmpty) return 0.0;
    return variants.map((e) => e.price).reduce((a, b) => a > b ? a : b);
  }

  String get priceRangeDisplay {
    if (variants.isEmpty) return '₱0.00';
    if (!hasVariants || minPrice == maxPrice) {
      return '₱${minPrice.toStringAsFixed(2)}';
    }
    return '₱${minPrice.toStringAsFixed(2)} - ₱${maxPrice.toStringAsFixed(2)}';
  }

  /// Extracts the variant label from a dish name:
  /// "Yang Chow Fried Rice (Large)" -> "Large"
  /// "YC Fried Chicken (Half)" -> "Half"
  /// "Lechon Macau (1/4 Kilo)" -> "1/4 Kilo"
  /// "Siomai with Shrimp" -> ""
  static String extractVariantLabel(String fullName) {
    final match = RegExp(r'\(([^)]+)\)\s*$').firstMatch(fullName.trim());
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!.trim();
    }
    return '';
  }

  /// Extracts the base dish name without the parenthesized variant.
  /// E.g. "Yang Chow Fried Rice (Large)" -> "Yang Chow Fried Rice"
  static String extractBaseName(String fullName) {
    return fullName.replaceAll(RegExp(r'\s*\([^)]+\)\s*$'), '').trim();
  }

  /// Groups a list of MenuItem into a List<GroupedMenuItem>
  static List<GroupedMenuItem> groupItems(List<MenuItem> items) {
    final Map<String, List<MenuItem>> grouped = {};
    for (final item in items) {
      final base = extractBaseName(item.name);
      grouped.putIfAbsent(base, () => []).add(item);
    }

    final List<GroupedMenuItem> result = [];
    for (final entry in grouped.entries) {
      final baseName = entry.key;
      final list = entry.value;
      list.sort((a, b) => a.price.compareTo(b.price));

      final first = list.first;
      final itemWithImg = list.firstWhere(
        (it) => it.customImagePath != null && it.customImagePath!.trim().isNotEmpty,
        orElse: () => first,
      );
      final itemWithDesc = list.firstWhere(
        (it) => it.description != null && it.description!.trim().isNotEmpty,
        orElse: () => first,
      );

      result.add(GroupedMenuItem(
        baseName: baseName,
        category: first.category,
        variants: list,
        description: itemWithDesc.description,
        customImagePath: itemWithImg.customImagePath,
        fallbackImagePath: itemWithImg.fallbackImagePath,
        color: first.color,
      ));
    }
    return result;
  }
}


