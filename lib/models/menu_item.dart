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

