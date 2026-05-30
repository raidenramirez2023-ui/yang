import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item.dart';
import '../utils/app_constants.dart';

class MenuService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static List<String> _cachedCategories = [];
  static Map<String, List<MenuItem>> _cachedMenu = {};
  static bool _isLoaded = false;

  static List<String> get categories => _cachedCategories.isNotEmpty ? _cachedCategories : _defaultCategories;

  static Map<String, List<MenuItem>> getMenu() {
    if (_isLoaded && _cachedMenu.isNotEmpty) {
      return _cachedMenu;
    }
    return _getDefaultMenu();
  }

  static Future<Map<String, List<MenuItem>>> fetchMenu() async {
    try {
      // Use a timestamp filter to force a unique URL and bypass aggressive browser caching on Flutter Web
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _supabase
          .from('menu_items')
          .select()
          .neq('name', 'cache_bypass_$timestamp')
          .order('name', ascending: true);

      if (response == null || (response as List).isEmpty) {
        debugPrint('Supabase menu_items table is empty or blocked by RLS. Returning empty menu.');
        _cachedMenu = {};
        _cachedCategories = [];
        _isLoaded = true;
        return _cachedMenu;
      }

      final List<dynamic> rows = response as List<dynamic>;
      final Map<String, List<MenuItem>> tempMenu = {};
      final Set<String> tempCategories = {};

      for (final row in rows) {
        final item = MenuItem.fromJson(row as Map<String, dynamic>);
        final cat = item.category;
        tempCategories.add(cat);
        if (!tempMenu.containsKey(cat)) {
          tempMenu[cat] = [];
        }
        tempMenu[cat]!.add(item);
      }

      final List<String> sortedCategories = tempCategories.toList();
      sortedCategories.sort((a, b) {
        final idxA = _defaultCategories.indexOf(a);
        final idxB = _defaultCategories.indexOf(b);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });

      _cachedCategories = sortedCategories;
      _cachedMenu = tempMenu;
      _isLoaded = true;
      return _cachedMenu;
    } catch (e, stackTrace) {
      debugPrint('Error fetching menu from Supabase: $e');
      debugPrint(stackTrace.toString());
      _cachedMenu = {};
      _cachedCategories = [];
      _isLoaded = true;
      return _cachedMenu;
    }
  }

  static Future<void> refreshMenu() async {
    _isLoaded = false;
    await fetchMenu();
  }

  static Future<void> createMenuItem(MenuItem item) async {
    try {
      final json = item.toJson();
      json.remove('id');
      await _supabase.from('menu_items').insert(json);
      await refreshMenu();
    } catch (e) {
      debugPrint('Error creating menu item: $e');
      rethrow;
    }
  }

  static Future<void> updateMenuItem(MenuItem item) async {
    if (item.id == null) {
      throw Exception('Cannot update menu item without an ID');
    }
    try {
      await _supabase.from('menu_items').update(item.toJson()).eq('id', item.id!);
      await refreshMenu();
    } catch (e) {
      debugPrint('Error updating menu item: $e');
      rethrow;
    }
  }

  static Future<void> deleteMenuItem(MenuItem item) async {
    if (item.id == null) {
      throw Exception('Cannot delete menu item without an ID');
    }
    try {
      // First, delete associated recipe ingredients to prevent orphan records
      await _supabase.from('recipe_ingredients').delete().eq('menu_item_name', item.name);
      
      // Then, delete the menu item itself and verify it was actually deleted
      final deletedRows = await _supabase.from('menu_items').delete().eq('id', item.id!).select();
      
      if (deletedRows.isEmpty) {
        throw Exception('Delete failed! Check your Supabase RLS (Row Level Security) policies for DELETE access.');
      }
      
      await refreshMenu();
    } catch (e) {
      debugPrint('Error deleting menu item: $e');
      rethrow;
    }
  }

  /// Converts any image path (local 'assets/images/FILENAME', filename, or URL) to its Supabase public URL.
  /// Paths that are already URLs (http/https) are returned unchanged.
  static String resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('assets/images/')) {
      return AppConstants.imageUrl(path.replaceFirst('assets/images/', ''));
    }
    return AppConstants.imageUrl(path);
  }

  static const List<String> _defaultCategories = [
    'Yangchow Family Bundles',
    'Vegetables',
    'Special Noodles',
    'Soup',
    'Seafood',
    'Roast and Soy Specialties',
    'Pork',
    'Noodles',
    'Mami or Noodles',
    'Hot Pot Specialties',
    'Fried Rice or Rice',
    'Dimsum',
    'Congee',
    'Chicken',
    'Beef',
    'Appetizer',
  ];

  static Map<String, List<MenuItem>> _getDefaultMenu() {
    final Map<String, List<MenuItem>> menu = {for (var cat in _defaultCategories) cat: []};
    return menu;
  }

  static int getTotalMenuItemsCount() {
    final menu = getMenu();
    return menu.values.fold(0, (sum, list) => sum + list.length);
  }
}