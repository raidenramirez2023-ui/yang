import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/menu_item.dart';
import '../utils/app_constants.dart';
import 'offline_pos_service.dart';



class MenuService {

  static final SupabaseClient _supabase = Supabase.instance.client;



  static List<String> _cachedCategories = [];

  static Map<String, List<MenuItem>> _cachedMenu = {};

  static bool _isLoaded = false;



  static List<String> get categories => _cachedCategories.isNotEmpty ? _cachedCategories : _defaultCategories;

  /// Returns whether a category is restricted to POS only (hidden from customer views)
  static bool isPosOnlyCategory(String category) {
    return category.trim().toLowerCase() == 'drinks';
  }

  /// Returns whether an item name belongs to the 'Drinks' category
  static bool isDrinkItem(String itemName) {
    if (itemName.trim().isEmpty) return false;
    final clean = itemName.trim().toLowerCase();

    // 1. Check loaded menu
    final menu = getMenu();
    for (final entry in menu.entries) {
      if (entry.key.trim().toLowerCase() == 'drinks') {
        for (final item in entry.value) {
          final itemClean = item.name.trim().toLowerCase();
          if (clean == itemClean ||
              clean.startsWith(itemClean) ||
              itemClean.startsWith(clean)) {
            return true;
          }
        }
      }
    }

    // 2. Known standard drinks keywords fallback
    const knownDrinks = [
      '7up',
      'mirinda',
      'mountain dew',
      'mug root beer',
      'nature spring',
      'pepsi',
      'red horse',
      'san mig',
      'iced tea',
      'coke',
      'sprite',
      'royal',
      'water',
      'beer',
      'soda',
      'juice',
      'gulaman',
    ];
    for (final kd in knownDrinks) {
      if (clean.contains(kd)) return true;
    }

    return false;
  }

  /// Categories for customer-facing views (excludes POS-only categories like Drinks)
  static List<String> get customerCategories =>
      categories.where((cat) => !isPosOnlyCategory(cat)).toList();

  /// Filters a menu map to exclude POS-only categories and items
  static Map<String, List<MenuItem>> filterCustomerMenu(Map<String, List<MenuItem>> rawMenu) {
    final Map<String, List<MenuItem>> filtered = {};
    rawMenu.forEach((category, items) {
      if (!isPosOnlyCategory(category)) {
        filtered[category] = items.where((item) => !isPosOnlyCategory(item.category)).toList();
      }
    });
    return filtered;
  }

  /// Menu items for customer-facing views (excludes POS-only categories like Drinks)
  static Map<String, List<MenuItem>> getCustomerMenu() {
    return filterCustomerMenu(getMenu());
  }

  /// Returns category -> list of GroupedMenuItem for Customer-facing views
  static Map<String, List<GroupedMenuItem>> getGroupedCustomerMenu() {
    final raw = getCustomerMenu();
    final Map<String, List<GroupedMenuItem>> grouped = {};
    raw.forEach((cat, items) {
      grouped[cat] = GroupedMenuItem.groupItems(items);
    });
    return grouped;
  }

  /// Returns category -> list of GroupedMenuItem for POS view (includes Drinks)
  static Map<String, List<GroupedMenuItem>> getGroupedPosMenu() {
    final raw = getMenu();
    final Map<String, List<GroupedMenuItem>> grouped = {};
    raw.forEach((cat, items) {
      grouped[cat] = GroupedMenuItem.groupItems(items);
    });
    return grouped;
  }

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



      if (response.isEmpty) {

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



      // Cache locally for offline POS usage
      final rawList = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      OfflinePosService().cacheMenuItems(rawList);

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

      // Attempt to load from offline cache
      try {
        final cached = await OfflinePosService().getCachedMenu();
        if (cached.isNotEmpty) {
          debugPrint('[MenuService] Successfully loaded menu from offline cache (${cached.length} categories).');
          _cachedMenu = cached;
          _cachedCategories = cached.keys.toList();
          _isLoaded = true;
          return _cachedMenu;
        }
      } catch (cacheErr) {
        debugPrint('[MenuService] Offline cache read failed: $cacheErr');
      }

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
  /// Automatically converts Unsplash webpage URLs to raw direct image URLs.
  static String resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';

    // Auto-convert Unsplash webpage URLs (e.g., https://unsplash.com/photos/title-ID) to direct image URLs
    if (path.contains('unsplash.com/photos/')) {
      try {
        final uri = Uri.parse(path);
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          final lastSegment = segments.last;
          final parts = lastSegment.split('-');
          final photoId = parts.last;
          return 'https://images.unsplash.com/photo-$photoId?auto=format&fit=crop&w=800&q=80';
        }
      } catch (_) {}
    }

    if (path.startsWith('http')) return path;

    if (path.startsWith('assets/images/')) {
      return AppConstants.imageUrl(path.replaceFirst('assets/images/', ''));
    }

    return AppConstants.imageUrl(path);
  }



  static const List<String> _defaultCategories = [

    'Yangchow Family Bundles',
    'Dimsum',
    'Congee',
    'Appetizer',
    'Mami or Noodles',
    'Soup',
    'Special Noodles',
    'Fried Rice or Rice',
    'Noodles',
    'Roast and Soy Specialties',
    'Beef',
    'Pork',
    'Chicken',
    'Seafood',
    'Hot Pot Specialties',
    'Vegetables',
    'Drinks',
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