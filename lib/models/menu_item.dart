import 'package:flutter/material.dart';

class MenuItem {
  String name;
  double price;
  final String category;
  String? customImagePath;
  final String fallbackImagePath;
  final Color color;

  MenuItem({
    required this.name,
    required this.price,
    required this.category,
    required this.fallbackImagePath,
    required this.color,
    this.customImagePath,
  });
}

class CartItem {
  final MenuItem item;
  int quantity;

  CartItem(this.item, this.quantity);

  String get name => item.name;
  double get price => item.price;
}
