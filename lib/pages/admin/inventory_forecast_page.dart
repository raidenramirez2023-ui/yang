import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:yang_chow/utils/file_download.dart';
import 'package:yang_chow/utils/global_messenger.dart';

class InventoryForecastPage extends StatefulWidget {
  const InventoryForecastPage({super.key});

  @override
  State<InventoryForecastPage> createState() => _InventoryForecastPageState();
}

class _InventoryForecastPageState extends State<InventoryForecastPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  String _selectedCategory = 'All';
  String _selectedDemandSource = 'All'; // 'All', 'POS Walk-in', 'Kitchen Request'
  String _selectedTimeFilter = 'Daily';
  String _selectedDailyMonth = 'January';
  String _selectedDailyDay = '1';
  String _selectedWeeklyMonth = 'January';
  String _selectedWeekFilter = 'Week 1';
  String _selectedMonthFilter = 'January';
  String _selectedYearFilter = DateTime.now().year.toString();
  String _selectedViewMode = 'Chart'; // 'Chart', 'Feed', 'Deficit'
  int _demandQueueCurrentPage = 1;
  int _stockDeficitCurrentPage = 1;
  String _demandQueueSearchQuery = '';
  bool _demandQueueTableView = true;
  String _stockDeficitSearchQuery = '';
  bool _stockDeficitTableView = true;
  int _topItemsCount = 8;
  bool _leaderboardTableView = false;
  static const int _forecastItemsPerPage = 15;

  List<Map<String, dynamic>> _forecastItems = [];
  bool _isLoading = true;
  StreamSubscription? _requestsSubscription;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _advanceSubscription;
  StreamSubscription? _reservationsSubscription;
  StreamSubscription? _inventorySubscription;
  Timer? _pollingTimer;

  final List<String> demandSourceFilters = [
    'All',
    'POS Walk-in',
    'Kitchen Request',
    'Advance Order',
    'Catering Reservation',
  ];
  final List<String> timeFilters = ['Daily', 'Weekly', 'Monthly', 'Annually'];
  final List<String> dayFilters = List.generate(31, (index) => (index + 1).toString());
  final List<String> weekFilters = ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5'];
  final List<String> monthFilters = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final List<String> yearFilters = [
    '2024',
    '2025',
    '2026',
    '2027',
    '2028',
    '2029',
    '2030',
  ];

  List<String> categories = ['All'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDailyMonth = monthFilters[now.month - 1];
    _selectedDailyDay = now.day.toString();
    _selectedWeeklyMonth = monthFilters[now.month - 1];
    final currentWeekNum = ((now.day - 1) ~/ 7) + 1;
    _selectedWeekFilter = 'Week ${currentWeekNum.clamp(1, 5)}';
    _selectedMonthFilter = monthFilters[now.month - 1];

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    // Initial load
    _fetchForecastData();
    _loadDynamicCategories();

    // Live update streams & background silent poll
    _subscribeToKitchenRequests();
    _subscribeToOrders();
    _subscribeToAdvanceOrders();
    _subscribeToReservations();
    _subscribeToInventory();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _fetchForecastData(silent: true);
    });
  }

  /// Fetch distinct categories directly from database (inventory + menu_items)
  Future<void> _loadDynamicCategories() async {
    final Map<String, String> dbCategories = {};
    try {
      final invResponse = await Supabase.instance.client
          .from('inventory')
          .select('category');
      for (final row in invResponse) {
        final cat = (row['category'] as String?)?.trim();
        if (cat != null && cat.isNotEmpty) {
          dbCategories.putIfAbsent(cat.toLowerCase(), () => cat);
        }
      }
    } catch (_) {}

    try {
      final menuResponse = await Supabase.instance.client
          .from('menu_items')
          .select('category');
      for (final row in menuResponse) {
        final cat = (row['category'] as String?)?.trim();
        if (cat != null && cat.isNotEmpty) {
          dbCategories.putIfAbsent(cat.toLowerCase(), () => cat);
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        final list = dbCategories.values.toList()..sort();
        categories = ['All', ...list];
        if (!categories.any((c) => c.toLowerCase() == _selectedCategory.toLowerCase())) {
          _selectedCategory = 'All';
        }
      });
    }
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _ordersSubscription?.cancel();
    _advanceSubscription?.cancel();
    _reservationsSubscription?.cancel();
    _inventorySubscription?.cancel();
    _pollingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _subscribeToKitchenRequests() {
    try {
      _requestsSubscription = Supabase.instance.client
          .from('kitchen_requests')
          .stream(primaryKey: ['id'])
          .listen((_) {
            if (mounted) _fetchForecastData(silent: true);
          }, onError: (e) {
            debugPrint('Kitchen requests realtime stream fallback: $e');
          });
    } catch (_) {}
  }

  void _subscribeToOrders() {
    try {
      _ordersSubscription = Supabase.instance.client
          .from('orders')
          .stream(primaryKey: ['id'])
          .listen((_) {
            if (mounted) _fetchForecastData(silent: true);
          }, onError: (e) {
            debugPrint('Orders realtime stream fallback: $e');
          });
    } catch (_) {}
  }

  void _subscribeToAdvanceOrders() {
    try {
      _advanceSubscription = Supabase.instance.client
          .from('advance_orders')
          .stream(primaryKey: ['id'])
          .listen((_) {
            if (mounted) _fetchForecastData(silent: true);
          }, onError: (e) {
            debugPrint('Advance orders realtime stream fallback: $e');
          });
    } catch (_) {}
  }

  void _subscribeToReservations() {
    try {
      _reservationsSubscription = Supabase.instance.client
          .from('reservations')
          .stream(primaryKey: ['id'])
          .listen((_) {
            if (mounted) _fetchForecastData(silent: true);
          }, onError: (e) {
            debugPrint('Reservations realtime stream fallback: $e');
          });
    } catch (_) {}
  }

  void _subscribeToInventory() {
    try {
      _inventorySubscription = Supabase.instance.client
          .from('inventory')
          .stream(primaryKey: ['id'])
          .listen((_) {
            if (mounted) {
              _fetchForecastData(silent: true);
              _loadDynamicCategories();
            }
          }, onError: (e) {
            debugPrint('Inventory realtime stream fallback: $e');
          });
    } catch (_) {}
  }

  // ── Fetch Full Demand & Consumption Pipeline for Accurate Forecasting ─────
  Future<void> _fetchForecastData({bool silent = false}) async {
    if (!silent && _forecastItems.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final inventoryResponse = await Supabase.instance.client
          .from('inventory')
          .select()
          .order('name');

      // 1. Fetch kitchen demand tickets (full active history)
      final kitchenResponse = await Supabase.instance.client
          .from('kitchen_requests')
          .select()
          .order('created_at', ascending: false)
          .limit(1000);

      // 2. Fetch recipe ingredients for BOM ingredient explosion
      List<Map<String, dynamic>> recipesResponse = [];
      try {
        final recData = await Supabase.instance.client
            .from('recipe_ingredients')
            .select();
        recipesResponse = List<Map<String, dynamic>>.from(recData);
      } catch (e) {
        debugPrint('Recipe ingredients fetch fallback: $e');
      }

      // 3. Fetch POS walk-in orders & order items (full annual history)
      List<Map<String, dynamic>> ordersResponse = [];
      List<Map<String, dynamic>> orderItemsResponse = [];
      try {
        final ordData = await Supabase.instance.client
            .from('orders')
            .select('id, created_at, total_amount, payment_status, refund_status')
            .order('created_at', ascending: false)
            .limit(1000);
        ordersResponse = List<Map<String, dynamic>>.from(ordData);

        if (ordersResponse.isNotEmpty) {
          final orderIds = ordersResponse.map((o) => o['id']).where((id) => id != null).toSet().toList();
          const chunkSize = 100;
          for (int i = 0; i < orderIds.length; i += chunkSize) {
            final chunk = orderIds.sublist(
              i,
              (i + chunkSize) > orderIds.length ? orderIds.length : (i + chunkSize),
            );
            try {
              final itemsChunk = await Supabase.instance.client
                  .from('order_items')
                  .select('order_id, item_name, quantity')
                  .inFilter('order_id', chunk);
              orderItemsResponse.addAll(List<Map<String, dynamic>>.from(itemsChunk));
            } catch (err) {
              debugPrint('Error fetching order items chunk: $err');
            }
          }
        }
      } catch (e) {
        debugPrint('Orders fetch fallback: $e');
      }

      // 4. Fetch Advance Orders (scheduled pre-orders)
      List<Map<String, dynamic>> advanceResponse = [];
      try {
        final advData = await Supabase.instance.client
            .from('advance_orders')
            .select()
            .order('created_at', ascending: false)
            .limit(1000);
        advanceResponse = List<Map<String, dynamic>>.from(advData);
      } catch (e) {
        debugPrint('Advance orders fetch fallback: $e');
      }

      // 5. Fetch Catering Reservations (banquet & event bookings)
      List<Map<String, dynamic>> reservationsResponse = [];
      try {
        final resData = await Supabase.instance.client
            .from('reservations')
            .select()
            .order('created_at', ascending: false)
            .limit(1000);
        reservationsResponse = List<Map<String, dynamic>>.from(resData);
      } catch (e) {
        debugPrint('Reservations fetch fallback: $e');
      }

      // 6. Fetch Menu Items to dynamically resolve dish/drink categories
      final Map<String, String> menuCategoryMap = {};
      try {
        final menuRows = await Supabase.instance.client
            .from('menu_items')
            .select('name, category');
        for (final row in menuRows) {
          final name = (row['name'] as String?)?.trim().toLowerCase() ?? '';
          final cat = (row['category'] as String?)?.trim() ?? '';
          if (name.isNotEmpty && cat.isNotEmpty) {
            menuCategoryMap[name] = cat;
          }
        }
      } catch (e) {
        debugPrint('Menu items category lookup fallback: $e');
      }

      final calculated = _calculateForecast(
        inventory: List<Map<String, dynamic>>.from(inventoryResponse),
        kitchenRequests: List<Map<String, dynamic>>.from(kitchenResponse),
        recipes: recipesResponse,
        orders: ordersResponse,
        orderItems: orderItemsResponse,
        advanceOrders: advanceResponse,
        reservations: reservationsResponse,
        menuCategoryMap: menuCategoryMap,
      );

      if (mounted) {
        setState(() {
          _forecastItems = calculated;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading forecast: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, int> _extractMenuItems(dynamic raw) {
    final Map<String, int> result = {};
    if (raw == null) return result;

    if (raw is String) {
      try {
        final trimmed = raw.trim();
        if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
            (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
          raw = jsonDecode(trimmed);
        }
      } catch (_) {}
    }

    if (raw is Map) {
      raw.forEach((k, v) {
        final name = k.toString().trim();
        int qty = 1;
        if (v is num) {
          qty = v.toInt();
        } else if (v is Map) {
          final q = v['quantity'] ?? v['qty'] ?? v['count'];
          qty = (q is num) ? q.toInt() : (int.tryParse(q?.toString() ?? '') ?? 1);
        } else {
          qty = int.tryParse(v.toString()) ?? 1;
        }
        if (name.isNotEmpty && qty > 0) {
          result[name] = (result[name] ?? 0) + qty;
        }
      });
    } else if (raw is List) {
      for (var item in raw) {
        if (item is Map) {
          final name = (item['item_name'] ?? item['name'] ?? item['dish'] ?? '').toString().trim();
          final q = item['quantity'] ?? item['qty'] ?? item['count'];
          final qty = (q is num) ? q.toInt() : (int.tryParse(q?.toString() ?? '') ?? 1);
          if (name.isNotEmpty && qty > 0) {
            result[name] = (result[name] ?? 0) + qty;
          }
        } else if (item is String) {
          final name = item.trim();
          if (name.isNotEmpty) {
            result[name] = (result[name] ?? 0) + 1;
          }
        }
      }
    }
    return result;
  }

  static String _normalizeDishName(String name) {
    String s = name.toLowerCase().replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    s = s.replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static const Map<String, List<Map<String, dynamic>>> _fallbackRecipes = {
    'beef with broccoli': [
      {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Broccoli Flower', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
    ],
    'beef with broccoli flower': [
      {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Broccoli Flower', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
    ],
    'beef with broccoli leaves (kaylan)': [
      {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Broccoli Flower', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      {'name': 'Bell Pepper', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
    ],
    'beef steak chinese style': [
      {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'White Onion', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
    ],
    'beef with ampalaya': [
      {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Ampalaya', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
    ],
    'beef with black pepper': [
      {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Black Pepper', 'quantity': 1.0, 'unit': 'gram', 'category': 'Groceries'},
      {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
    ],
    'beef with green pepper': [
      {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Bell Pepper', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Vegetables'},
      {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
    ],
    'beef with scramble egg': [
      {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Fresh Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
      {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
    ],
    'slice beef mango': [
      {'name': 'Slice Beef 5x120', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Mango', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
      {'name': 'Panda Oyster Sauce', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
    ],
    'bola-bola siopao': [
      {'name': 'Bola Pao', 'quantity': 1.0, 'unit': 'order', 'category': 'Davids'},
    ],
    'asado siopao': [
      {'name': 'Asado Pao', 'quantity': 1.0, 'unit': 'order', 'category': 'Davids'},
    ],
    'special siopao': [
      {'name': 'Asado Pao', 'quantity': 1.0, 'unit': 'order', 'category': 'Davids'},
    ],
    'shark\'s fin dumpling': [
      {'name': 'Sharksfin Meat', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Wonton Wrapper', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
    ],
    'wonton dumplings': [
      {'name': 'Wonton Meat', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Wonton Wrapper', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
    ],
    'spinach dumpling': [
      {'name': 'Siomai Wrapper', 'quantity': 1.0, 'unit': 'pack', 'category': 'Groceries'},
      {'name': 'Vegetables', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
    ],
    'hakaw': [
      {'name': 'Hakaw', 'quantity': 1.0, 'unit': 'order', 'category': 'Davids'},
    ],
    'siomai with shrimp': [
      {'name': 'Shrimp Marinated 10x100', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Siomai Meat Mix', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Siomai Wrapper', 'quantity': 1.0, 'unit': 'pack', 'category': 'Groceries'},
    ],
    'quail egg siomai': [
      {'name': 'Quail Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
      {'name': 'Siomai Meat Mix', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Siomai Wrapper', 'quantity': 1.0, 'unit': 'pack', 'category': 'Groceries'},
    ],
    'chicken feet': [
      {'name': 'Chicken Feet', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Davids'},
    ],
    'buchi': [
      {'name': 'Buchi', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Davids'},
    ],
    'cuapao / mantau': [
      {'name': 'Cuapao', 'quantity': 1.0, 'unit': 'order', 'category': 'Davids'},
    ],
    'tausi spareribs': [
      {'name': 'Spicy Spareribs 5x300', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Tausi Sauce', 'quantity': 1.0, 'unit': 'gram', 'category': 'Sauces'},
    ],
    'sweet and sour pork': [
      {'name': 'Sweet and Sour Pork 5x200', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Fresh'},
      {'name': 'Sweet and Sour Sauce', 'quantity': 1.0, 'unit': 'bot', 'category': 'Sauces'},
    ],
    'yang chow fried rice': [
      {'name': 'YC Rice', 'quantity': 1.0, 'unit': 'kilo', 'category': 'Groceries'},
      {'name': 'Fresh Egg', 'quantity': 1.0, 'unit': 'pcs', 'category': 'Groceries'},
    ],
  };

  static bool _matchesCategoryFilter(Map<String, dynamic> item, String selectedCategory) {
    if (selectedCategory.trim().toLowerCase() == 'all') return true;
    final sel = selectedCategory.trim().toLowerCase();

    final supplyCat = (item['category'] ?? '').toString().trim().toLowerCase();
    final menuCat = (item['menuCategory'] ?? '').toString().trim().toLowerCase();

    return supplyCat == sel || menuCat == sel;
  }

  List<Map<String, dynamic>> _calculateForecast({
    required List<Map<String, dynamic>> inventory,
    required List<Map<String, dynamic>> kitchenRequests,
    required List<Map<String, dynamic>> recipes,
    required List<Map<String, dynamic>> orders,
    required List<Map<String, dynamic>> orderItems,
    required List<Map<String, dynamic>> advanceOrders,
    required List<Map<String, dynamic>> reservations,
    required Map<String, String> menuCategoryMap,
  }) {
    List<Map<String, dynamic>> forecast = [];

    // Map inventory by exact name & lowercase name
    final Map<String, Map<String, dynamic>> inventoryMap = {};
    final Map<String, Map<String, dynamic>> inventoryLowerMap = {};
    for (var item in inventory) {
      final name = (item['name'] ?? '').toString();
      inventoryMap[name] = item;
      inventoryLowerMap[name.toLowerCase().trim()] = item;
    }

    // Group recipes by menu_item_name (lowercase) & normalized name
    final Map<String, List<Map<String, dynamic>>> recipesByMenu = {};
    final Map<String, List<Map<String, dynamic>>> recipesByNormalizedName = {};
    for (var r in recipes) {
      final rawMenuName = (r['menu_item_name'] ?? '').toString().trim();
      final menuName = rawMenuName.toLowerCase();
      if (menuName.isNotEmpty) {
        recipesByMenu.putIfAbsent(menuName, () => []).add(r);
        final norm = _normalizeDishName(rawMenuName);
        if (norm.isNotEmpty) {
          recipesByNormalizedName.putIfAbsent(norm, () => []).add(r);
        }
      }
    }

    // Normalized menu category map
    final Map<String, String> normalizedMenuCategoryMap = {};
    menuCategoryMap.forEach((name, cat) {
      final norm = _normalizeDishName(name);
      if (norm.isNotEmpty) {
        normalizedMenuCategoryMap[norm] = cat;
      }
    });

    // Helper to resolve dish menu category
    String resolveMenuCategory(String menuItemName) {
      final clean = menuItemName.trim().toLowerCase();
      if (menuCategoryMap.containsKey(clean) && menuCategoryMap[clean]!.isNotEmpty) {
        return menuCategoryMap[clean]!;
      }

      final norm = _normalizeDishName(menuItemName);
      if (norm.isNotEmpty && normalizedMenuCategoryMap.containsKey(norm) && normalizedMenuCategoryMap[norm]!.isNotEmpty) {
        return normalizedMenuCategoryMap[norm]!;
      }

      for (final entry in menuCategoryMap.entries) {
        if (entry.key.contains(clean) || clean.contains(entry.key)) {
          return entry.value;
        }
      }

      for (final entry in normalizedMenuCategoryMap.entries) {
        if (entry.key.contains(norm) || norm.contains(entry.key)) {
          return entry.value;
        }
      }

      return '';
    }

    // Helper to find matching recipes with normalized, partial, and fallback resolution
    List<Map<String, dynamic>>? findMatchingRecipes(String menuItemName) {
      final clean = menuItemName.trim().toLowerCase();
      if (clean.isEmpty) return null;

      // 1. Direct lowercase match in database recipes
      if (recipesByMenu.containsKey(clean) && recipesByMenu[clean]!.isNotEmpty) {
        return recipesByMenu[clean];
      }

      // 2. Normalized match (strips parentheticals like (2pcs), (4pcs), punctuation)
      final norm = _normalizeDishName(menuItemName);
      if (norm.isNotEmpty && recipesByNormalizedName.containsKey(norm) && recipesByNormalizedName[norm]!.isNotEmpty) {
        return recipesByNormalizedName[norm];
      }

      // 3. Database recipe prefix / substring match
      for (final entry in recipesByMenu.entries) {
        final key = entry.key;
        if (key.startsWith(clean) || clean.startsWith(key) || key.contains(clean) || clean.contains(key)) {
          return entry.value;
        }
      }

      // 4. Normalized substring match
      for (final entry in recipesByNormalizedName.entries) {
        final key = entry.key;
        if (key.startsWith(norm) || norm.startsWith(key) || key.contains(norm) || norm.contains(key)) {
          return entry.value;
        }
      }

      // 5. Fallback standard restaurant recipes
      if (_fallbackRecipes.containsKey(clean)) {
        return _fallbackRecipes[clean];
      }
      if (norm.isNotEmpty && _fallbackRecipes.containsKey(norm)) {
        return _fallbackRecipes[norm];
      }
      for (final entry in _fallbackRecipes.entries) {
        if (entry.key.contains(clean) || clean.contains(entry.key) || entry.key.contains(norm) || norm.contains(entry.key)) {
          return entry.value;
        }
      }

      return null;
    }

    // Helper to dynamically resolve direct category (drinks, retail, beverages)
    String resolveDirectCategory(Map<String, dynamic> invItem, String menuLower, String menuCat) {
      final invCat = (invItem['category'] ?? '').toString().trim();
      if (invCat.isNotEmpty) return invCat;

      if (menuCat.trim().isNotEmpty) return menuCat.trim();

      final mappedCat = menuCategoryMap[menuLower];
      if (mappedCat != null && mappedCat.trim().isNotEmpty) return mappedCat.trim();

      for (final entry in menuCategoryMap.entries) {
        if (entry.key.contains(menuLower) || menuLower.contains(entry.key)) {
          return entry.value.trim();
        }
      }
      return 'Drinks';
    }

    // 1. Process Kitchen Requests
    for (var transaction in kitchenRequests) {
      final itemName = (transaction['item_name'] ?? '').toString();
      final inventoryItem = inventoryMap[itemName] ?? inventoryLowerMap[itemName.toLowerCase().trim()];

      if (inventoryItem == null) continue;

      final currentStock = (inventoryItem['quantity'] as num?)?.toDouble() ?? 0.0;
      final unit = (transaction['unit'] ?? inventoryItem['unit'] ?? 'pcs').toString();
      final requestQuantity = (transaction['quantity_needed'] as num?)?.toDouble() ?? 0.0;
      final priority = (transaction['priority'] ?? 'Medium').toString();
      final storageRoom = (inventoryItem['storage_room'] ?? 'Dry Storage').toString();
      final status = (transaction['status'] ?? 'Approved').toString();

      forecast.add({
        'name': inventoryItem['name'] ?? itemName,
        'category': inventoryItem['category'] ?? 'Uncategorized',
        'menuCategory': '',
        'menuItem': '',
        'currentStock': currentStock,
        'unit': unit,
        'requestQuantity': requestQuantity,
        'priority': priority,
        'status': status,
        'storage_room': storageRoom,
        'riskColor': _getPriorityColor(priority),
        'riskIcon': _getPriorityIcon(priority),
        'requestId': transaction['id'],
        'requestedBy': transaction['requested_by'] ?? 'Chef / Kitchen',
        'createdAt': transaction['created_at'],
        'notes': transaction['notes'] ?? '',
        'demandSource': 'Kitchen Request',
        'supplier': inventoryItem['supplier'] ?? 'Unassigned',
      });
    }

    // 2. Process POS Walk-in Sales (Exploded through recipes into raw ingredients)
    final Map<String, Map<String, dynamic>> ordersById = {};
    for (var ord in orders) {
      ordersById[ord['id'].toString()] = ord;
    }

    for (var oi in orderItems) {
      final orderId = oi['order_id']?.toString() ?? '';
      final ord = ordersById[orderId];
      final refundStatus = (ord?['refund_status'] ?? '').toString().toLowerCase();
      final paymentStatus = (ord?['payment_status'] ?? '').toString().toLowerCase();
      // Skip refunded or cancelled orders
      if (refundStatus == 'full_refund' || paymentStatus == 'refunded' || paymentStatus == 'cancelled') continue;

      final menuItemName = (oi['item_name'] ?? '').toString().trim();
      final orderQty = (oi['quantity'] as num?)?.toInt() ?? 1;
      final createdAt = ord?['created_at']?.toString() ?? DateTime.now().toIso8601String();

      final menuLower = menuItemName.toLowerCase();
      final matchedRecipes = findMatchingRecipes(menuItemName);

      if (matchedRecipes != null && matchedRecipes.isNotEmpty) {
        // Explode menu dish into ingredients
        for (var rec in matchedRecipes) {
          final ingName = (rec['name'] ?? '').toString().trim();
          if (ingName.isEmpty) continue;

          final ingLower = ingName.toLowerCase();
          final invItem = inventoryLowerMap[ingLower] ??
              inventory.firstWhere(
                (inv) {
                  final invName = (inv['name'] ?? '').toString().toLowerCase().trim();
                  return invName.isNotEmpty && (invName == ingLower || invName.contains(ingLower) || ingLower.contains(invName));
                },
                orElse: () => {},
              );

          final unitReq = (rec['quantity'] as num?)?.toDouble() ?? 1.0;
          final totalNeeded = unitReq * orderQty;
          final currentStock = (invItem['quantity'] as num?)?.toDouble() ?? 0.0;
          final unit = (invItem['unit'] ?? rec['unit'] ?? 'pcs').toString();
          final priority = currentStock <= 0 ? 'Urgent' : (currentStock < totalNeeded ? 'High' : 'Normal');
          final storage = (invItem['storage_room'] ?? 'Kitchen Line').toString();

          final supplyCategory = (invItem['category'] ?? rec['category'] ?? 'Groceries').toString().trim();
          final dishCategory = resolveMenuCategory(menuItemName);

          forecast.add({
            'name': invItem['name'] ?? ingName,
            'category': supplyCategory.isNotEmpty ? supplyCategory : (dishCategory.isNotEmpty ? dishCategory : 'Groceries'),
            'menuCategory': dishCategory,
            'menuItem': menuItemName,
            'currentStock': currentStock,
            'unit': unit,
            'requestQuantity': totalNeeded,
            'priority': priority,
            'status': 'Fulfilled',
            'storage_room': storage,
            'riskColor': _getPriorityColor(priority),
            'riskIcon': _getPriorityIcon(priority),
            'requestId': orderId,
            'requestedBy': 'POS Walk-in Counter',
            'createdAt': createdAt,
            'notes': 'POS: $menuItemName (Qty: $orderQty)',
            'demandSource': 'POS Walk-in',
            'supplier': invItem['supplier'] ?? 'Unassigned',
          });
        }
      } else {
        // Direct item match (e.g. beverages, drinks, retail items)
        final invItem = inventoryLowerMap[menuLower] ??
            inventory.firstWhere(
              (inv) {
                final invName = (inv['name'] ?? '').toString().toLowerCase().trim();
                return invName.isNotEmpty && (menuLower.contains(invName) || invName.contains(menuLower));
              },
              orElse: () => {},
            );

        final dishCategory = resolveMenuCategory(menuItemName);
        final directCategory = resolveDirectCategory(invItem, menuLower, dishCategory);
        final currentStock = (invItem['quantity'] as num?)?.toDouble() ?? 0.0;
        final unit = (invItem['unit'] ?? 'pcs').toString();
        final totalNeeded = orderQty.toDouble();
        final priority = currentStock <= 0 ? 'Urgent' : (currentStock < totalNeeded ? 'High' : 'Normal');
        final storage = (invItem['storage_room'] ?? 'Bar / Counter').toString();

        forecast.add({
          'name': invItem['name'] ?? menuItemName,
          'category': directCategory,
          'menuCategory': dishCategory.isNotEmpty ? dishCategory : directCategory,
          'menuItem': menuItemName,
          'currentStock': currentStock,
          'unit': unit,
          'requestQuantity': totalNeeded,
          'priority': priority,
          'status': 'Fulfilled',
          'storage_room': storage,
          'riskColor': _getPriorityColor(priority),
          'riskIcon': _getPriorityIcon(priority),
          'requestId': orderId,
          'requestedBy': 'POS Walk-in Counter',
          'createdAt': createdAt,
          'notes': 'POS Direct Item (Qty: $orderQty)',
          'demandSource': 'POS Walk-in',
          'supplier': invItem['supplier'] ?? 'Unassigned',
        });
      }
    }

    // 3. Process Advance Orders (Exploded through recipes into raw ingredients)
    for (var adv in advanceOrders) {
      final advStatus = (adv['status'] ?? '').toString().toLowerCase();
      final refundStatus = (adv['refund_status'] ?? '').toString().toLowerCase();
      final paymentStatus = (adv['payment_status'] ?? '').toString().toLowerCase();
      if (advStatus == 'cancelled' || refundStatus == 'full_refund' || paymentStatus == 'cancelled') continue;

      final advId = adv['id']?.toString() ?? '';
      final customerName = (adv['customer_name'] ?? 'Advance Customer').toString();
      String createdAt = adv['created_at']?.toString() ?? DateTime.now().toIso8601String();
      if (adv['order_date'] != null && adv['order_date'].toString().trim().isNotEmpty) {
        createdAt = adv['order_date'].toString().trim();
      }
      final menuItems = _extractMenuItems(adv['selected_menu_items']);

      menuItems.forEach((menuItemName, orderQty) {
        final menuLower = menuItemName.toLowerCase().trim();
        final matchedRecipes = findMatchingRecipes(menuItemName);

        if (matchedRecipes != null && matchedRecipes.isNotEmpty) {
          for (var rec in matchedRecipes) {
            final ingName = (rec['name'] ?? '').toString().trim();
            if (ingName.isEmpty) continue;

            final ingLower = ingName.toLowerCase();
            final invItem = inventoryLowerMap[ingLower] ??
                inventory.firstWhere(
                  (inv) {
                    final invName = (inv['name'] ?? '').toString().toLowerCase().trim();
                    return invName.isNotEmpty && (invName == ingLower || invName.contains(ingLower) || ingLower.contains(invName));
                  },
                  orElse: () => {},
                );

            final unitReq = (rec['quantity'] as num?)?.toDouble() ?? 1.0;
            final totalNeeded = unitReq * orderQty;
            final currentStock = (invItem['quantity'] as num?)?.toDouble() ?? 0.0;
            final unit = (invItem['unit'] ?? rec['unit'] ?? 'pcs').toString();
            final priority = currentStock <= 0 ? 'Urgent' : (currentStock < totalNeeded ? 'High' : 'Normal');
            final storage = (invItem['storage_room'] ?? 'Kitchen Line').toString();

            final supplyCategory = (invItem['category'] ?? rec['category'] ?? 'Groceries').toString().trim();
            final dishCategory = resolveMenuCategory(menuItemName);

            forecast.add({
              'name': invItem['name'] ?? ingName,
              'category': supplyCategory.isNotEmpty ? supplyCategory : (dishCategory.isNotEmpty ? dishCategory : 'Groceries'),
              'menuCategory': dishCategory,
              'menuItem': menuItemName,
              'currentStock': currentStock,
              'unit': unit,
              'requestQuantity': totalNeeded,
              'priority': priority,
              'status': 'Scheduled',
              'storage_room': storage,
              'riskColor': _getPriorityColor(priority),
              'riskIcon': _getPriorityIcon(priority),
              'requestId': advId,
              'requestedBy': customerName,
              'createdAt': createdAt,
              'notes': 'Advance Order: $menuItemName (Qty: $orderQty)',
              'demandSource': 'Advance Order',
              'supplier': invItem['supplier'] ?? 'Unassigned',
            });
          }
        } else {
          final invItem = inventoryLowerMap[menuLower] ??
              inventory.firstWhere(
                (inv) {
                  final invName = (inv['name'] ?? '').toString().toLowerCase().trim();
                  return invName.isNotEmpty && (menuLower.contains(invName) || invName.contains(menuLower));
                },
                orElse: () => {},
              );

          final dishCategory = resolveMenuCategory(menuItemName);
          final directCategory = resolveDirectCategory(invItem, menuLower, dishCategory);
          final currentStock = (invItem['quantity'] as num?)?.toDouble() ?? 0.0;
          final unit = (invItem['unit'] ?? 'pcs').toString();
          final totalNeeded = orderQty.toDouble();
          final priority = currentStock <= 0 ? 'Urgent' : (currentStock < totalNeeded ? 'High' : 'Normal');
          final storage = (invItem['storage_room'] ?? 'Bar / Counter').toString();

          forecast.add({
            'name': invItem['name'] ?? menuItemName,
            'category': directCategory,
            'menuCategory': dishCategory.isNotEmpty ? dishCategory : directCategory,
            'menuItem': menuItemName,
            'currentStock': currentStock,
            'unit': unit,
            'requestQuantity': totalNeeded,
            'priority': priority,
            'status': 'Scheduled',
            'storage_room': storage,
            'riskColor': _getPriorityColor(priority),
            'riskIcon': _getPriorityIcon(priority),
            'requestId': advId,
            'requestedBy': customerName,
            'createdAt': createdAt,
            'notes': 'Advance Direct: $menuItemName (Qty: $orderQty)',
            'demandSource': 'Advance Order',
            'supplier': invItem['supplier'] ?? 'Unassigned',
          });
        }
      });
    }

    // 4. Process Catering Reservations (Exploded through recipes into raw ingredients)
    for (var res in reservations) {
      final resStatus = (res['status'] ?? '').toString().toLowerCase();
      final paymentStatus = (res['payment_status'] ?? '').toString().toLowerCase();
      if (resStatus == 'cancelled' || resStatus == 'rejected' || paymentStatus == 'cancelled') continue;

      final resId = res['id']?.toString() ?? '';
      final customerName = (res['customer_name'] ?? 'Catering Client').toString();
      final eventType = (res['event_type'] ?? 'Catering Event').toString();
      final guests = (res['number_of_guests'] as num?)?.toInt() ?? 0;
      String createdAt = res['created_at']?.toString() ?? DateTime.now().toIso8601String();
      if (res['event_date'] != null && res['event_date'].toString().trim().isNotEmpty) {
        createdAt = res['event_date'].toString().trim();
      }
      final menuItems = _extractMenuItems(res['selected_menu_items']);

      menuItems.forEach((menuItemName, orderQty) {
        final menuLower = menuItemName.toLowerCase().trim();
        final matchedRecipes = findMatchingRecipes(menuItemName);

        if (matchedRecipes != null && matchedRecipes.isNotEmpty) {
          for (var rec in matchedRecipes) {
            final ingName = (rec['name'] ?? '').toString().trim();
            if (ingName.isEmpty) continue;

            final ingLower = ingName.toLowerCase();
            final invItem = inventoryLowerMap[ingLower] ??
                inventory.firstWhere(
                  (inv) {
                    final invName = (inv['name'] ?? '').toString().toLowerCase().trim();
                    return invName.isNotEmpty && (invName == ingLower || invName.contains(ingLower) || ingLower.contains(invName));
                  },
                  orElse: () => {},
                );

            final unitReq = (rec['quantity'] as num?)?.toDouble() ?? 1.0;
            final totalNeeded = unitReq * orderQty;
            final currentStock = (invItem['quantity'] as num?)?.toDouble() ?? 0.0;
            final unit = (invItem['unit'] ?? rec['unit'] ?? 'pcs').toString();
            final priority = currentStock <= 0 ? 'Urgent' : (currentStock < totalNeeded ? 'High' : 'Normal');
            final storage = (invItem['storage_room'] ?? 'Kitchen Line').toString();

            final supplyCategory = (invItem['category'] ?? rec['category'] ?? 'Groceries').toString().trim();
            final dishCategory = resolveMenuCategory(menuItemName);

            forecast.add({
              'name': invItem['name'] ?? ingName,
              'category': supplyCategory.isNotEmpty ? supplyCategory : (dishCategory.isNotEmpty ? dishCategory : 'Groceries'),
              'menuCategory': dishCategory,
              'menuItem': menuItemName,
              'currentStock': currentStock,
              'unit': unit,
              'requestQuantity': totalNeeded,
              'priority': priority,
              'status': 'Event Booked',
              'storage_room': storage,
              'riskColor': _getPriorityColor(priority),
              'riskIcon': _getPriorityIcon(priority),
              'requestId': resId,
              'requestedBy': '$customerName ($eventType)',
              'createdAt': createdAt,
              'notes': 'Catering: $menuItemName (Qty: $orderQty${guests > 0 ? ', $guests pax' : ''})',
              'demandSource': 'Catering Reservation',
              'supplier': invItem['supplier'] ?? 'Unassigned',
            });
          }
        } else {
          final invItem = inventoryLowerMap[menuLower] ??
              inventory.firstWhere(
                (inv) {
                  final invName = (inv['name'] ?? '').toString().toLowerCase().trim();
                  return invName.isNotEmpty && (menuLower.contains(invName) || invName.contains(menuLower));
                },
                orElse: () => {},
              );

          final dishCategory = resolveMenuCategory(menuItemName);
          final directCategory = resolveDirectCategory(invItem, menuLower, dishCategory);
          final currentStock = (invItem['quantity'] as num?)?.toDouble() ?? 0.0;
          final unit = (invItem['unit'] ?? 'pcs').toString();
          final totalNeeded = orderQty.toDouble();
          final priority = currentStock <= 0 ? 'Urgent' : (currentStock < totalNeeded ? 'High' : 'Normal');
          final storage = (invItem['storage_room'] ?? 'Bar / Counter').toString();

          forecast.add({
            'name': invItem['name'] ?? menuItemName,
            'category': directCategory,
            'menuCategory': dishCategory.isNotEmpty ? dishCategory : directCategory,
            'menuItem': menuItemName,
            'currentStock': currentStock,
            'unit': unit,
            'requestQuantity': totalNeeded,
            'priority': priority,
            'status': 'Event Booked',
            'storage_room': storage,
            'riskColor': _getPriorityColor(priority),
            'riskIcon': _getPriorityIcon(priority),
            'requestId': resId,
            'requestedBy': '$customerName ($eventType)',
            'createdAt': createdAt,
            'notes': 'Catering Direct: $menuItemName (Qty: $orderQty)',
            'demandSource': 'Catering Reservation',
            'supplier': invItem['supplier'] ?? 'Unassigned',
          });
        }
      });
    }

    forecast.sort((a, b) {
      final dateA = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return forecast;
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'High':
      case 'Urgent':
        return const Color(0xFFEF4444);
      case 'Medium':
        return const Color(0xFFF59E0B);
      case 'Normal':
      case 'Low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF14332E);
    }
  }

  IconData _getPriorityIcon(String? priority) {
    switch (priority) {
      case 'High':
      case 'Urgent':
        return Icons.warning_amber_rounded;
      case 'Medium':
        return Icons.info_outline_rounded;
      case 'Normal':
      case 'Low':
        return Icons.check_circle_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  List<Map<String, dynamic>> _filterDataByTime(List<Map<String, dynamic>> forecast) {
    if (forecast.isEmpty) return [];

    final now = DateTime.now();
    final List<Map<String, dynamic>> filteredData = [];

    for (var item in forecast) {
      final createdAt = DateTime.tryParse(item['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now();

      switch (_selectedTimeFilter) {
        case 'Daily':
          final selectedMonthIndex = _getMonthIndex(_selectedDailyMonth);
          final selectedDay = int.parse(_selectedDailyDay);
          if (createdAt.year == now.year &&
              createdAt.month == selectedMonthIndex &&
              createdAt.day == selectedDay) {
            filteredData.add(item);
          }
          break;

        case 'Weekly':
          final selectedWeekNumber = int.parse(_selectedWeekFilter.split(' ')[1]);
          final selectedMonthIndex = _getMonthIndex(_selectedWeeklyMonth);
          if (_isInSelectedWeekOfMonth(createdAt, selectedWeekNumber, selectedMonthIndex, now.year)) {
            filteredData.add(item);
          }
          break;

        case 'Monthly':
          final selectedMonthIndex = _getMonthIndex(_selectedMonthFilter);
          if (createdAt.year == now.year && createdAt.month == selectedMonthIndex) {
            filteredData.add(item);
          }
          break;

        case 'Annually':
          final selectedYear = int.parse(_selectedYearFilter);
          if (createdAt.year == selectedYear) {
            filteredData.add(item);
          }
          break;
      }
    }

    return filteredData;
  }

  int _getMonthIndex(String monthName) {
    switch (monthName) {
      case 'January': return 1;
      case 'February': return 2;
      case 'March': return 3;
      case 'April': return 4;
      case 'May': return 5;
      case 'June': return 6;
      case 'July': return 7;
      case 'August': return 8;
      case 'September': return 9;
      case 'October': return 10;
      case 'November': return 11;
      case 'December': return 12;
      default: return 1;
    }
  }

  bool _isInSelectedWeekOfMonth(DateTime date, int weekNumber, int monthIndex, int year) {
    if (date.year != year || date.month != monthIndex) return false;
    final int startDay = (weekNumber - 1) * 7 + 1;
    final int daysInMonth = DateTime(year, monthIndex + 1, 0).day;
    if (startDay > daysInMonth) return false;
    final int endDay = math.min(startDay + 6, daysInMonth);
    return date.day >= startDay && date.day <= endDay;
  }

  /// Returns short date range label (e.g. "Sep 1–7", "Sep 22–28", "Sep 29–30")
  String _getWeekDateRangeLabel(String weekKey) {
    try {
      final year = DateTime.now().year;
      final monthIdx = _getMonthIndex(_selectedWeeklyMonth);
      final weekNum = int.tryParse(weekKey.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      final startDay = (weekNum - 1) * 7 + 1;
      final daysInMonth = DateTime(year, monthIdx + 1, 0).day;
      if (startDay > daysInMonth) return '';
      final endDay = math.min(startDay + 6, daysInMonth);
      final monthAbbr = DateFormat('MMM').format(DateTime(year, monthIdx));
      return '$monthAbbr $startDay–$endDay';
    } catch (_) {
      return '';
    }
  }

  double _calculateDynamicMaxY(double maxValue) {
    if (maxValue <= 0) return 5.0;
    if (maxValue <= 1) return 2.0;
    if (maxValue <= 2) return 3.0;
    if (maxValue <= 4) return 5.0;
    final double rawMax = maxValue * 1.15;
    if (rawMax <= 10) return 10.0;
    if (rawMax <= 20) return (rawMax / 5).ceil() * 5.0;
    if (rawMax <= 50) return (rawMax / 10).ceil() * 10.0;
    if (rawMax <= 100) return (rawMax / 20).ceil() * 20.0;
    if (rawMax <= 250) return (rawMax / 25).ceil() * 25.0;
    if (rawMax <= 500) return (rawMax / 50).ceil() * 50.0;
    if (rawMax <= 1000) return (rawMax / 100).ceil() * 100.0;
    if (rawMax <= 5000) return (rawMax / 500).ceil() * 500.0;
    if (rawMax <= 20000) return (rawMax / 1000).ceil() * 1000.0;
    return (rawMax / 5000).ceil() * 5000.0;
  }

  String _formatAxisValue(double value) {
    if (value >= 1000000) {
      final formatted = (value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1);
      return '${formatted}M';
    } else if (value >= 1000) {
      final formatted = (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
      return '${formatted}k';
    }
    return value.toInt().toString();
  }

  Map<String, dynamic> _getTopItemsData(List<Map<String, dynamic>> forecast) {
    final timeFilteredData = _filterDataByTime(forecast);
    if (timeFilteredData.isEmpty) {
      return {
        'barGroups': <BarChartGroupData>[],
        'topItems': <MapEntry<String, double>>[],
        'itemDetails': <String, Map<String, dynamic>>{},
        'totalDemand': 0.0,
        'calculatedMaxY': 10.0,
      };
    }

    final Map<String, double> itemTotals = {};
    final Map<String, Map<String, dynamic>> itemDetails = {};
    double totalDemand = 0.0;

    for (var item in timeFilteredData) {
      final itemName = (item['name'] ?? '').toString();
      final quantity = (item['requestQuantity'] as num?)?.toDouble() ?? 0.0;
      itemTotals[itemName] = (itemTotals[itemName] ?? 0) + quantity;
      totalDemand += quantity;

      if (!itemDetails.containsKey(itemName)) {
        itemDetails[itemName] = {
          'unit': item['unit'] ?? 'units',
          'category': item['category'] ?? 'General',
          'storage': item['storage_room'] ?? 'Warehouse',
          'currentStock': (item['currentStock'] as num?)?.toDouble() ?? 0.0,
        };
      }
    }

    final sortedItems = itemTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topItems = sortedItems.take(_topItemsCount).toList();

    final double maxVal = topItems.fold<double>(
      0.0,
      (prev, elem) => math.max(prev, elem.value),
    );
    final double calculatedMaxY = _calculateDynamicMaxY(maxVal);

    final barGroups = List.generate(topItems.length, (index) {
      final item = topItems[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: item.value,
            gradient: const LinearGradient(
              colors: [Color(0xFF14332E), Color(0xFF10B981)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: calculatedMaxY,
              color: const Color(0xFF14332E).withValues(alpha: 0.04),
            ),
          ),
        ],
      );
    });

    return {
      'barGroups': barGroups,
      'topItems': topItems,
      'itemDetails': itemDetails,
      'totalDemand': totalDemand,
      'calculatedMaxY': calculatedMaxY,
    };
  }


  String _formatQty(num value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  // ── Excel Export Method ──────────────────────────────────────────────────
  Future<void> _exportForecastToExcel() async {
    GlobalMessenger.showInfo('Ginagawa ang Inventory Forecast Excel Spreadsheet...');

    try {
      final excel = excel_pkg.Excel.createExcel();
      excel.delete('Sheet1');

      // Styles
      final headerStyle = excel_pkg.CellStyle(
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#14332E'),
        horizontalAlign: excel_pkg.HorizontalAlign.Left,
        bold: true,
      );
      final titleStyle = excel_pkg.CellStyle(
        fontSize: 14,
        bold: true,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#14332E'),
      );
      final subTitleStyle = excel_pkg.CellStyle(
        fontSize: 10,
        italic: true,
        fontColorHex: excel_pkg.ExcelColor.fromHexString('#475569'),
      );

      void appendStyledRow(excel_pkg.Sheet sheet, List<excel_pkg.CellValue?> rowValues, {excel_pkg.CellStyle? style}) {
        sheet.appendRow(rowValues);
        if (style != null) {
          final rowIndex = sheet.maxRows - 1;
          for (var c = 0; c < rowValues.length; c++) {
            final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
            cell.cellStyle = style;
          }
        }
      }

      var categoryFiltered = _forecastItems;
      if (_selectedCategory != 'All') {
        categoryFiltered = _forecastItems
            .where((item) => _matchesCategoryFilter(item, _selectedCategory))
            .toList();
      }
      if (_selectedDemandSource != 'All') {
        categoryFiltered = categoryFiltered
            .where((item) =>
                (item['demandSource'] ?? '').toString().trim().toLowerCase() ==
                _selectedDemandSource.trim().toLowerCase())
            .toList();
      }
      final timeFiltered = _filterDataByTime(categoryFiltered);

      final totalDemandTickets = timeFiltered.length;
      final posTickets = timeFiltered.where((i) => i['demandSource'] == 'POS Walk-in').length;
      final kitchenTickets = timeFiltered.where((i) => i['demandSource'] == 'Kitchen Request').length;
      final advanceTickets = timeFiltered.where((i) => i['demandSource'] == 'Advance Order').length;
      final cateringTickets = timeFiltered.where((i) => i['demandSource'] == 'Catering Reservation').length;

      // Group per SKU for summary
      final Map<String, Map<String, dynamic>> skuMap = {};
      for (var item in timeFiltered) {
        final name = item['name'] as String;
        final req = (item['requestQuantity'] as num).toDouble();
        final currentStock = (item['currentStock'] as num).toDouble();
        final unit = (item['unit'] ?? 'pcs') as String;
        final cat = (item['category'] ?? 'General') as String;
        final storage = (item['storage_room'] ?? 'Dry Storage') as String;
        final supplier = (item['supplier'] ?? 'Unassigned') as String;

        if (!skuMap.containsKey(name)) {
          skuMap[name] = {
            'name': name,
            'category': cat,
            'storage_room': storage,
            'supplier': supplier,
            'currentStock': currentStock,
            'totalDemand': 0.0,
            'unit': unit,
            'posDemand': 0.0,
            'kitchenDemand': 0.0,
            'advanceDemand': 0.0,
            'cateringDemand': 0.0,
          };
        }
        skuMap[name]!['totalDemand'] = (skuMap[name]!['totalDemand'] as double) + req;
        if (item['demandSource'] == 'POS Walk-in') {
          skuMap[name]!['posDemand'] = (skuMap[name]!['posDemand'] as double) + req;
        } else if (item['demandSource'] == 'Advance Order') {
          skuMap[name]!['advanceDemand'] = (skuMap[name]!['advanceDemand'] as double) + req;
        } else if (item['demandSource'] == 'Catering Reservation') {
          skuMap[name]!['cateringDemand'] = (skuMap[name]!['cateringDemand'] as double) + req;
        } else {
          skuMap[name]!['kitchenDemand'] = (skuMap[name]!['kitchenDemand'] as double) + req;
        }
      }

      // TAB 1: EXECUTIVE SUMMARY
      final summarySheet = excel['Executive Summary'];
      summarySheet.setColumnWidth(0, 32.0);
      summarySheet.setColumnWidth(1, 24.0);
      summarySheet.setColumnWidth(2, 35.0);

      appendStyledRow(summarySheet, [excel_pkg.TextCellValue('YANG CHOW RESTAURANT - INVENTORY DEMAND & FORECAST REPORT')], style: titleStyle);
      appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Branch: CLA Town Center Mall, Pagsanjan, Laguna • Automated ERP Forecasting')], style: subTitleStyle);
      appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Timeframe: $_selectedTimeFilter | Category: $_selectedCategory | Source: $_selectedDemandSource')]);
      appendStyledRow(summarySheet, [excel_pkg.TextCellValue('Generated On: ${DateFormat('yyyy-MM-dd hh:mm:ss a').format(DateTime.now())}')]);
      appendStyledRow(summarySheet, []);

      appendStyledRow(summarySheet, [
        excel_pkg.TextCellValue('Executive Metric'),
        excel_pkg.TextCellValue('Value'),
        excel_pkg.TextCellValue('Operational Context / Notes'),
      ], style: headerStyle);

      double totalDemandUnits = 0.0;
      int totalDeficitSkus = 0;
      for (var sku in skuMap.values) {
        final stock = sku['currentStock'] as double;
        final demand = sku['totalDemand'] as double;
        totalDemandUnits += demand;
        if (stock < demand) totalDeficitSkus++;
      }

      appendStyledRow(summarySheet, [
        excel_pkg.TextCellValue('Total Demand Tickets'),
        excel_pkg.IntCellValue(totalDemandTickets),
        excel_pkg.TextCellValue('Combined operational demand across 4 channels'),
      ]);
      appendStyledRow(summarySheet, [
        excel_pkg.TextCellValue('POS Walk-in Demand Tickets'),
        excel_pkg.IntCellValue(posTickets),
        excel_pkg.TextCellValue('Automated ingredient explosion from walk-in POS sales'),
      ]);
      appendStyledRow(summarySheet, [
        excel_pkg.TextCellValue('Kitchen Warehouse Requisitions'),
        excel_pkg.IntCellValue(kitchenTickets),
        excel_pkg.TextCellValue('Direct warehouse requisition tickets from kitchen staff'),
      ]);
      appendStyledRow(summarySheet, [
        excel_pkg.TextCellValue('Advance Pre-Order Demands'),
        excel_pkg.IntCellValue(advanceTickets),
        excel_pkg.TextCellValue('Customer advance orders scheduled for fulfillment'),
      ]);
      appendStyledRow(summarySheet, [
        excel_pkg.TextCellValue('Catering Event Demands'),
        excel_pkg.IntCellValue(cateringTickets),
        excel_pkg.TextCellValue('Event catering bookings and banquet requisitions'),
      ]);
      appendStyledRow(summarySheet, [
        excel_pkg.TextCellValue('Total Volume Demanded'),
        excel_pkg.DoubleCellValue(double.parse(totalDemandUnits.toStringAsFixed(1))),
        excel_pkg.TextCellValue('Aggregated units / kilos consumed across all ingredients'),
      ]);
      appendStyledRow(summarySheet, [
        excel_pkg.TextCellValue('Stock Deficit Alerts (Critical SKUs)'),
        excel_pkg.IntCellValue(totalDeficitSkus),
        excel_pkg.TextCellValue(totalDeficitSkus > 0 ? 'Urgent purchase order required' : 'Stock level is healthy'),
      ]);

      // TAB 2: STOCK DEFICIT & REORDER ADVICE
      final deficitSheet = excel['Stock Deficit & Reorder Advice'];
      deficitSheet.setColumnWidth(0, 26.0);
      deficitSheet.setColumnWidth(1, 16.0);
      deficitSheet.setColumnWidth(2, 18.0);
      deficitSheet.setColumnWidth(3, 14.0);
      deficitSheet.setColumnWidth(4, 16.0);
      deficitSheet.setColumnWidth(5, 14.0);
      deficitSheet.setColumnWidth(6, 12.0);
      deficitSheet.setColumnWidth(7, 16.0);
      deficitSheet.setColumnWidth(8, 20.0);
      deficitSheet.setColumnWidth(9, 24.0);

      appendStyledRow(deficitSheet, [
        excel_pkg.TextCellValue('Ingredient / Item Name'),
        excel_pkg.TextCellValue('Category'),
        excel_pkg.TextCellValue('Storage Room'),
        excel_pkg.TextCellValue('In-Stock'),
        excel_pkg.TextCellValue('Total Demand'),
        excel_pkg.TextCellValue('Deficit'),
        excel_pkg.TextCellValue('Unit'),
        excel_pkg.TextCellValue('Stock Status'),
        excel_pkg.TextCellValue('Suggested Reorder Qty'),
        excel_pkg.TextCellValue('Procurement Recommendation'),
      ], style: headerStyle);

      final sortedSkus = skuMap.values.toList()
        ..sort((a, b) {
          final defA = (a['totalDemand'] as double) - (a['currentStock'] as double);
          final defB = (b['totalDemand'] as double) - (b['currentStock'] as double);
          return defB.compareTo(defA);
        });

      for (var sku in sortedSkus) {
        final stock = sku['currentStock'] as double;
        final demand = sku['totalDemand'] as double;
        final deficit = (demand - stock).clamp(0.0, double.infinity);
        final hasDeficit = deficit > 0;
        final suggestedReorder = hasDeficit ? (deficit * 1.15).ceilToDouble() : 0.0;

        appendStyledRow(deficitSheet, [
          excel_pkg.TextCellValue(sku['name'] as String),
          excel_pkg.TextCellValue(sku['category'] as String),
          excel_pkg.TextCellValue(sku['storage_room'] as String),
          excel_pkg.DoubleCellValue(double.parse(stock.toStringAsFixed(1))),
          excel_pkg.DoubleCellValue(double.parse(demand.toStringAsFixed(1))),
          excel_pkg.DoubleCellValue(double.parse(deficit.toStringAsFixed(1))),
          excel_pkg.TextCellValue(sku['unit'] as String),
          excel_pkg.TextCellValue(hasDeficit ? 'DEFICIT / SHORTAGE' : 'SUFFICIENT'),
          excel_pkg.DoubleCellValue(suggestedReorder),
          excel_pkg.TextCellValue(hasDeficit ? 'Reorder immediately + 15% buffer' : 'Stock level is healthy'),
        ]);
      }

      // TAB 3: DETAILED DEMAND LOG
      final logSheet = excel['Detailed Demand Tickets'];
      logSheet.setColumnWidth(0, 20.0);
      logSheet.setColumnWidth(1, 18.0);
      logSheet.setColumnWidth(2, 24.0);
      logSheet.setColumnWidth(3, 16.0);
      logSheet.setColumnWidth(4, 14.0);
      logSheet.setColumnWidth(5, 10.0);
      logSheet.setColumnWidth(6, 12.0);
      logSheet.setColumnWidth(7, 18.0);
      logSheet.setColumnWidth(8, 30.0);

      appendStyledRow(logSheet, [
        excel_pkg.TextCellValue('Timestamp'),
        excel_pkg.TextCellValue('Demand Source'),
        excel_pkg.TextCellValue('Ingredient Name'),
        excel_pkg.TextCellValue('Category'),
        excel_pkg.TextCellValue('Quantity Needed'),
        excel_pkg.TextCellValue('Unit'),
        excel_pkg.TextCellValue('Current Stock'),
        excel_pkg.TextCellValue('Origin / Requester'),
        excel_pkg.TextCellValue('Notes / Menu Origin'),
      ], style: headerStyle);

      for (var item in timeFiltered) {
        DateTime? dt;
        try { dt = DateTime.parse(item['createdAt'] as String).toLocal(); } catch (_) {}
        final dateStr = dt != null ? DateFormat('yyyy-MM-dd hh:mm a').format(dt) : '-';

        appendStyledRow(logSheet, [
          excel_pkg.TextCellValue(dateStr),
          excel_pkg.TextCellValue(item['demandSource']?.toString() ?? 'Demand'),
          excel_pkg.TextCellValue(item['name']?.toString() ?? ''),
          excel_pkg.TextCellValue(item['category']?.toString() ?? ''),
          excel_pkg.DoubleCellValue((item['requestQuantity'] as num).toDouble()),
          excel_pkg.TextCellValue(item['unit']?.toString() ?? ''),
          excel_pkg.DoubleCellValue((item['currentStock'] as num).toDouble()),
          excel_pkg.TextCellValue(item['requestedBy']?.toString() ?? ''),
          excel_pkg.TextCellValue(item['notes']?.toString() ?? ''),
        ]);
      }

      final List<int>? excelBytes = excel.save();
      if (excelBytes == null) throw Exception('Excel encoding failed');
      final Uint8List bytes = Uint8List.fromList(excelBytes);

      final fileName = 'Yang_Chow_Inventory_Forecast_${_selectedTimeFilter}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';

      // ── Rekta / Direct Download on Web ──
      if (kIsWeb) {
        final downloaded = downloadBinaryFile(
          bytes,
          '$fileName.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (downloaded) {
          GlobalMessenger.showSuccess('Inventory Forecast Excel na-download: $fileName.xlsx');
          return;
        }
      } else {
        // Direct Download on Windows Desktop
        try {
          if (Platform.isWindows) {
            final userProfile = Platform.environment['USERPROFILE'];
            if (userProfile != null) {
              final downloadsDir = Directory('$userProfile\\Downloads');
              if (downloadsDir.existsSync()) {
                final targetPath = '${downloadsDir.path}\\$fileName.xlsx';
                final file = File(targetPath);
                await file.writeAsBytes(bytes);
                GlobalMessenger.showSuccess('Inventory Forecast Excel na-save sa Downloads: $fileName.xlsx');
                return;
              }
            }
          }
        } catch (_) {}
      }

      // ── Desktop / Non-Web Save Dialog Fallback ──
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Yang Chow Inventory Forecast Excel Report',
        fileName: '$fileName.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: bytes,
      );

      if (outputFile != null) {
        if (!kIsWeb) {
          try {
            final finalPath = outputFile.toLowerCase().endsWith('.xlsx') ? outputFile : '$outputFile.xlsx';
            final file = File(finalPath);
            if (!file.existsSync() || file.lengthSync() == 0) {
              await file.writeAsBytes(bytes);
            }
          } catch (e) {
            debugPrint('Desktop file write fallback: $e');
          }
        }
        GlobalMessenger.showSuccess('Inventory Forecast Excel na-save: $fileName.xlsx');
      }
    } catch (e) {
      GlobalMessenger.showError('Hindi na-export ang Excel: $e');
    }
  }

  // ── PDF Export Method ────────────────────────────────────────────────────
  Future<void> _exportForecastToPdf({bool printPreview = true}) async {
    GlobalMessenger.showInfo('Ginagawa ang PDF Inventory Forecast Report...');

    try {
      var categoryFiltered = _forecastItems;
      if (_selectedCategory != 'All') {
        categoryFiltered = _forecastItems
            .where((item) => _matchesCategoryFilter(item, _selectedCategory))
            .toList();
      }
      if (_selectedDemandSource != 'All') {
        categoryFiltered = categoryFiltered
            .where((item) =>
                (item['demandSource'] ?? '').toString().trim().toLowerCase() ==
                _selectedDemandSource.trim().toLowerCase())
            .toList();
      }
      final timeFiltered = _filterDataByTime(categoryFiltered);

      final totalDemandTickets = timeFiltered.length;
      final posTickets = timeFiltered.where((i) => i['demandSource'] == 'POS Walk-in').length;
      final kitchenTickets = timeFiltered.where((i) => i['demandSource'] == 'Kitchen Request').length;
      final advanceTickets = timeFiltered.where((i) => i['demandSource'] == 'Advance Order').length;
      final cateringTickets = timeFiltered.where((i) => i['demandSource'] == 'Catering Reservation').length;

      // Group per SKU
      final Map<String, Map<String, dynamic>> skuMap = {};
      for (var item in timeFiltered) {
        final name = item['name'] as String;
        final req = (item['requestQuantity'] as num).toDouble();
        final currentStock = (item['currentStock'] as num).toDouble();
        final unit = (item['unit'] ?? 'pcs') as String;
        final cat = (item['category'] ?? 'General') as String;

        if (!skuMap.containsKey(name)) {
          skuMap[name] = {
            'name': name,
            'category': cat,
            'currentStock': currentStock,
            'totalDemand': 0.0,
            'unit': unit,
          };
        }
        skuMap[name]!['totalDemand'] = (skuMap[name]!['totalDemand'] as double) + req;
      }

      final deficitSkus = skuMap.values.where((s) => (s['currentStock'] as double) < (s['totalDemand'] as double)).toList();
      final topDemandItems = skuMap.values.toList()
        ..sort((a, b) => (b['totalDemand'] as double).compareTo(a['totalDemand'] as double));

      final now = DateTime.now();
      final dateStr = DateFormat('MMMM d, yyyy - hh:mm a').format(now);
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (pw.Context context) {
            return [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'YANG CHOW RESTAURANT',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('14332E'),
                        ),
                      ),
                      pw.Text(
                        'CLA Town Center Mall, Pagsanjan, Laguna • Kitchen & POS Demand Forecasting',
                        style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('64748B')),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('14332E'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'INVENTORY FORECAST REPORT',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text('Period: $_selectedTimeFilter ($_selectedCategory)', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColor.fromHex('CBD5E1')),
              pw.SizedBox(height: 10),

              // KPI Summary Boxes
              pw.Row(
                children: [
                  _pdfKpiBox('TOTAL DEMAND', '$totalDemandTickets', 'Tickets across 4 channels', PdfColor.fromHex('14332E')),
                  pw.SizedBox(width: 6),
                  _pdfKpiBox('POS WALK-IN', '$posTickets Orders', 'Counter sales demand', PdfColor.fromHex('2563EB')),
                  pw.SizedBox(width: 6),
                  _pdfKpiBox('KITCHEN REQS', '$kitchenTickets Slips', 'Warehouse pullouts', PdfColor.fromHex('D97706')),
                  pw.SizedBox(width: 6),
                  _pdfKpiBox('ADV & CATERING', '${advanceTickets + cateringTickets} Events', 'Scheduled bookings', PdfColor.fromHex('7C3AED')),
                  pw.SizedBox(width: 6),
                  _pdfKpiBox('DEFICIT SKUS', '${deficitSkus.length} Items', deficitSkus.isNotEmpty ? 'Reorder needed' : 'Stocks healthy', PdfColor.fromHex('DC2626')),
                ],
              ),
              pw.SizedBox(height: 16),

              // SECTION 1: CRITICAL STOCK DEFICITS & REORDER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'CRITICAL STOCK DEFICITS & REORDER ADVICE',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('DC2626')),
                  ),
                  pw.Text(
                    '${deficitSkus.length} SKU(s) exceed current inventory',
                    style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('64748B')),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              if (deficitSkus.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('F0FDF4'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColor.fromHex('BBF7D0')),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'All requested and sold ingredients in this timeframe are covered by available stock.',
                      style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('166534')),
                    ),
                  ),
                )
              else
                pw.TableHelper.fromTextArray(
                  headers: ['#', 'Ingredient Description', 'Category', 'In-Stock', 'Demand', 'Deficit', 'Suggested Reorder'],
                  headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('991B1B')),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellHeight: 20,
                  data: deficitSkus.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final itm = entry.value;
                    final stock = itm['currentStock'] as double;
                    final demand = itm['totalDemand'] as double;
                    final def = demand - stock;
                    final unit = itm['unit'];
                    final suggested = (def * 1.15).ceilToDouble();
                    return [
                      '$idx',
                      itm['name'],
                      itm['category'],
                      '${_formatPdfQty(stock)} $unit',
                      '${_formatPdfQty(demand)} $unit',
                      '-${_formatPdfQty(def)} $unit',
                      '+${_formatPdfQty(suggested)} $unit',
                    ];
                  }).toList(),
                ),

              pw.SizedBox(height: 18),

              // SECTION 2: TOP CONSUMED INGREDIENTS
              pw.Text(
                'TOP CONSUMED INGREDIENTS (DEMAND VELOCITY)',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('14332E')),
              ),
              pw.SizedBox(height: 6),

              pw.TableHelper.fromTextArray(
                headers: ['Rank', 'Ingredient Name', 'Category', 'Current Stock', 'Total Demand Volume', 'Unit', 'Stock Status'],
                headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('14332E')),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellHeight: 20,
                data: topDemandItems.take(15).toList().asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final itm = entry.value;
                  final stock = itm['currentStock'] as double;
                  final demand = itm['totalDemand'] as double;
                  final unit = itm['unit'];
                  final isShort = stock < demand;
                  return [
                    '#$rank',
                    itm['name'],
                    itm['category'],
                    '${_formatPdfQty(stock)} $unit',
                    '${_formatPdfQty(demand)} $unit',
                    '$unit',
                    isShort ? 'DEFICIT ALERT' : 'Covered',
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 24),

              // Signatures
              pw.Divider(thickness: 1, color: PdfColor.fromHex('CBD5E1')),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Prepared By:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.SizedBox(height: 20),
                      pw.Container(width: 150, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 3),
                      pw.Text('Inventory In-Charge / Store Admin', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Reviewed & Approved By:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.SizedBox(height: 20),
                      pw.Container(width: 150, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 3),
                      pw.Text('Head Chef / Store General Manager', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final fileName = 'Yang_Chow_Inventory_Forecast_${_selectedTimeFilter}_${DateFormat('yyyyMMdd').format(now)}.pdf';
      final pdfBytes = await pdf.save();

      if (printPreview) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: fileName,
        );
      } else {
        // Rekta / Direct Download
        if (kIsWeb) {
          final downloaded = downloadBinaryFile(pdfBytes, fileName, 'application/pdf');
          if (downloaded) {
            GlobalMessenger.showSuccess('PDF Report na-download: $fileName');
            return;
          }
        } else {
          // Direct Download on Windows Desktop
          try {
            if (Platform.isWindows) {
              final userProfile = Platform.environment['USERPROFILE'];
              if (userProfile != null) {
                final downloadsDir = Directory('$userProfile\\Downloads');
                if (downloadsDir.existsSync()) {
                  final targetPath = '${downloadsDir.path}\\$fileName';
                  final file = File(targetPath);
                  await file.writeAsBytes(pdfBytes);
                  GlobalMessenger.showSuccess('PDF Report na-save sa Downloads: $fileName');
                  return;
                }
              }
            }
          } catch (_) {}
        }
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      }
    } catch (e) {
      GlobalMessenger.showError('Hindi nagawa ang PDF: $e');
    }
  }

  static pw.Widget _pdfKpiBox(String title, String val, String sub, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('F8FAFC'),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: PdfColor.fromHex('E2E8F0')),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 2),
            pw.Text(val, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 1),
            pw.Text(sub, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  static String _formatPdfQty(num value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    // Apply category & demand source filtering in memory
    var categoryFiltered = _forecastItems;
    if (_selectedCategory != 'All') {
      categoryFiltered = _forecastItems
          .where((item) => _matchesCategoryFilter(item, _selectedCategory))
          .toList();
    }
    if (_selectedDemandSource != 'All') {
      categoryFiltered = categoryFiltered
          .where((item) =>
              (item['demandSource'] ?? '').toString().trim().toLowerCase() ==
              _selectedDemandSource.trim().toLowerCase())
          .toList();
    }

    final timeFiltered = _filterDataByTime(categoryFiltered);

    // Calculations for 4 Executive KPI Cards
    final totalTickets = timeFiltered.length;
    final urgentCount = timeFiltered.where((i) =>
        i['priority'] == 'High' || i['priority'] == 'Urgent').length;

    int deficitCount = 0;
    double totalUnitsRequested = 0;

    for (var item in timeFiltered) {
      final req = (item['requestQuantity'] as num).toDouble();
      final stock = (item['currentStock'] as num).toDouble();
      totalUnitsRequested += req;
      if (stock < req) {
        deficitCount++;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.adminMainBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Executive Header Banner ──────────────────────────────
                _buildExecutiveHeader(isMobile),

                const SizedBox(height: 16),

                if (_isLoading && _forecastItems.isEmpty)
                  const SizedBox(
                    height: 240,
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF14332E)),
                    ),
                  )
                else ...[
                  // ── 4 Top KPI Cards ──────────────────────────────
                  _buildKpiMetricsRow(
                    totalTickets: totalTickets,
                    totalUnits: totalUnitsRequested,
                    urgentCount: urgentCount,
                    deficitCount: deficitCount,
                    isMobile: isMobile,
                  ),

                  const SizedBox(height: 16),

                  // ── Filter Controls Section ──────────────────────
                  _buildFilterControls(isMobile),

                  const SizedBox(height: 16),

                  // ── View Mode Selector & Content ─────────────────
                  _buildMainContent(categoryFiltered, timeFiltered, isMobile),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Executive Header Banner ────────────────────────────────────────────────
  Widget _buildExecutiveHeader(bool isMobile) {
    final titleSection = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1.0),
          ),
          child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kitchen Demand & Inventory Forecast',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
                maxLines: 2,
              ),
              SizedBox(height: 3),
              Text(
                'POS Walk-in sales & kitchen requisitions with automated procurement forecasting',
                style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.15),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );

    final exportButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Excel Direct Download Button
        ElevatedButton.icon(
          onPressed: _exportForecastToExcel,
          icon: const Icon(Icons.file_download_rounded, size: 16),
          label: const Text('Download Excel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 13, vertical: isMobile ? 8 : 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
              side: const BorderSide(color: Colors.black, width: 1.0),
            ),
            textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            elevation: 2,
          ),
        ),
        // PDF Direct Download Button (Rekta Download)
        ElevatedButton.icon(
          onPressed: () => _exportForecastToPdf(printPreview: false),
          icon: const Icon(Icons.file_download_rounded, size: 16),
          label: const Text('Download PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 13, vertical: isMobile ? 8 : 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
              side: const BorderSide(color: Colors.black, width: 1.0),
            ),
            textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            elevation: 2,
          ),
        ),
        // PDF Print / Layout Preview Button
        OutlinedButton.icon(
          onPressed: () => _exportForecastToPdf(printPreview: true),
          icon: const Icon(Icons.print_rounded, size: 15, color: Colors.white),
          label: const Text('Print / Preview'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.black, width: 1.0),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 13, vertical: isMobile ? 8 : 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
              side: const BorderSide(color: Colors.black, width: 1.0),
            ),
            textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 16 : 20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14332E), Color(0xFF1B4942), Color(0xFF163C35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14332E).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleSection,
                const SizedBox(height: 12),
                exportButtons,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: titleSection),
                const SizedBox(width: 16),
                exportButtons,
              ],
            ),
    );
  }

  // ── 4 Top KPI Cards ────────────────────────────────────────────────────────
  Widget _buildKpiMetricsRow({
    required int totalTickets,
    required num totalUnits,
    required int urgentCount,
    required int deficitCount,
    required bool isMobile,
  }) {
    final cards = [
      _buildKpiCard(
        categoryTag: 'TICKETS & SLIPS',
        title: 'Total Demand Transactions',
        value: '$totalTickets Tickets',
        subtitle: _selectedDemandSource == 'All'
            ? 'Orders & kitchen requisitions in selected period'
            : 'Requisitions from $_selectedDemandSource channel',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF14332E),
        badgeText: 'Channel: $_selectedDemandSource',
      ),
      _buildKpiCard(
        categoryTag: 'INGREDIENTS USED',
        title: 'Raw Stock Consumed',
        value: '${_formatQty(totalUnits)} Units Used',
        subtitle: 'Total raw ingredients consumed to fulfill orders',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF2563EB),
        badgeText: 'Total Pulled',
      ),
      _buildKpiCard(
        categoryTag: 'KITCHEN PRIORITY',
        title: 'Urgent & Rush Demands',
        value: urgentCount > 0 ? '$urgentCount Urgent Slips' : '0 Urgent Slips',
        subtitle: urgentCount > 0
            ? 'Kitchen marked high priority / rush prep'
            : 'All kitchen requisitions at normal prep speed',
        icon: Icons.priority_high_rounded,
        color: urgentCount > 0 ? const Color(0xFFD97706) : const Color(0xFF059669),
        isAlert: urgentCount > 0,
        badgeText: urgentCount > 0 ? 'Urgent Alert' : 'Normal Prep',
      ),
      _buildKpiCard(
        categoryTag: 'INVENTORY RISK',
        title: 'Stock Deficit Warnings',
        value: deficitCount > 0 ? '$deficitCount Deficit SKUs' : '0 Shortages',
        subtitle: deficitCount > 0
            ? 'Demand exceeds available stock! Reorder needed'
            : 'Sufficient stock buffer covers all demand',
        icon: deficitCount > 0 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
        color: deficitCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
        isAlert: deficitCount > 0,
        badgeText: deficitCount > 0 ? 'Restock Needed' : 'Stock Healthy',
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 120,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: cards
              .map((c) => Container(
                    width: 230,
                    margin: const EdgeInsets.only(right: 10),
                    child: c,
                  ))
              .toList(),
        ),
      );
    }

    return Row(
      children: cards
          .map((card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: card,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildKpiCard({
    required String categoryTag,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badgeText,
    bool isAlert = false,
  }) {
    final isMobile = ResponsiveUtils.isMobile(context);
    return Container(
      constraints: BoxConstraints(minHeight: isMobile ? 110 : 118),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 14,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black,
          width: isAlert ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black, width: 0.8),
                ),
                child: Text(
                  categoryTag,
                  style: TextStyle(
                    fontSize: isMobile ? 8.5 : 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(isMobile ? 4 : 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(isMobile ? 6 : 7),
                  border: Border.all(color: Colors.black, width: 0.8),
                ),
                child: Icon(icon, color: Colors.black, size: isMobile ? 14 : 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: isMobile ? 9.5 : 10.5,
              color: Colors.black,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Filter Controls Section ────────────────────────────────────────────────
  // ── Filter Controls Section (Unified Industry-Standard Toolbar) ───────────
  Widget _buildFilterControls(bool isMobile) {
    final hasActiveCustomFilter = _selectedDemandSource != 'All' || _selectedCategory != 'All';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Title, Reset Button, and Active Filter Context
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.black, width: 1.0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black, width: 0.8),
                  ),
                  child: const Icon(Icons.tune_rounded, size: 15, color: Colors.black),
                ),
                const SizedBox(width: 8),
                const Text(
                  'FORECAST FILTERS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.black,
                  ),
                ),
                if (hasActiveCustomFilter) ...[
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDemandSource = 'All';
                        _selectedCategory = 'All';
                        _demandQueueCurrentPage = 1;
                        _stockDeficitCurrentPage = 1;
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.refresh_rounded, size: 12, color: Colors.black),
                          SizedBox(width: 4),
                          Text(
                            'Reset Filters',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (!isMobile) _buildActiveTimeBadge(),
              ],
            ),
          ),

          // Main Controls
          Padding(
            padding: const EdgeInsets.all(14),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPeriodToggle(isMobile: true),
                      const SizedBox(height: 10),
                      _buildSecondaryTimeDropdown(isMobile: true),
                      const SizedBox(height: 10),
                      _buildDemandSourceDropdown(isMobile: true),
                      const SizedBox(height: 10),
                      _buildCategorySelectorButton(context, isMobile: true),
                    ],
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // 1. Timeframe
                      _buildPeriodToggle(isMobile: false),
                      Container(width: 1, height: 26, color: Colors.black),
                      // 2. Secondary Time Dropdown (Month / Day / Week / Year)
                      _buildSecondaryTimeDropdown(isMobile: false),
                      Container(width: 1, height: 26, color: Colors.black),
                      // 3. Channel Dropdown
                      _buildDemandSourceDropdown(isMobile: false),
                      // 4. Category Searchable Selector
                      _buildCategorySelectorButton(context, isMobile: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Channel Dropdown Selector ──────────────────────────────────────────────
  Widget _buildDemandSourceDropdown({required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 1.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: demandSourceFilters.contains(_selectedDemandSource)
              ? _selectedDemandSource
              : demandSourceFilters.first,
          isDense: true,
          isExpanded: isMobile,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.black),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedDemandSource = val;
                _demandQueueCurrentPage = 1;
                _stockDeficitCurrentPage = 1;
              });
            }
          },
          items: demandSourceFilters.map((src) {
            IconData icon = Icons.all_inclusive_rounded;
            String label = src;
            if (src == 'All') label = 'All Channels';
            if (src == 'POS Walk-in') icon = Icons.point_of_sale_rounded;
            if (src == 'Kitchen Request') icon = Icons.restaurant_rounded;
            if (src == 'Advance Order') icon = Icons.schedule_send_rounded;
            if (src == 'Catering Reservation') icon = Icons.celebration_rounded;

            return DropdownMenuItem<String>(
              value: src,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: Colors.black),
                  const SizedBox(width: 8),
                  Flexible(child: Text(label, style: const TextStyle(color: Colors.black), overflow: TextOverflow.ellipsis)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Category Searchable Selector Button ────────────────────────────────────
  Widget _buildCategorySelectorButton(BuildContext context, {required bool isMobile}) {
    final isFiltered = _selectedCategory.toLowerCase() != 'all';
    final label = isFiltered ? _selectedCategory : 'All Categories (${categories.length})';

    return InkWell(
      onTap: () => _openCategorySearchDialog(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isFiltered ? const Color(0xFFD97706).withValues(alpha: 0.1) : AppTheme.adminMainBackground.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.black,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
          children: [
            const Icon(
              Icons.category_rounded,
              size: 14,
              color: Colors.black,
            ),
            const SizedBox(width: 8),
            const Text(
              'Category: ',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            Expanded(
              flex: isMobile ? 1 : 0,
              child: isMobile
                  ? Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
            ),
            const SizedBox(width: 6),
            if (isFiltered)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = 'All';
                    _demandQueueCurrentPage = 1;
                    _stockDeficitCurrentPage = 1;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 0.8),
                  ),
                  child: const Icon(Icons.close_rounded, size: 12, color: Colors.black),
                ),
              )
            else
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.black),
          ],
        ),
      ),
    );
  }

  // ── Searchable Category Modal Dialog ──────────────────────────────────────
  void _openCategorySearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        String searchKeyword = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCategories = categories.where((cat) {
              if (searchKeyword.isEmpty) return true;
              return cat.toLowerCase().contains(searchKeyword.toLowerCase());
            }).toList();

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.category_rounded, size: 20, color: Color(0xFFD97706)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Supply & Food Category',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF14332E),
                                  ),
                                ),
                                Text(
                                  '${categories.length} categories available in catalog',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.mediumGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: AppTheme.mediumGrey),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Type to search category...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppTheme.mediumGrey),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF14332E)),
                          filled: true,
                          fillColor: AppTheme.adminMainBackground.withValues(alpha: 0.6),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppTheme.cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppTheme.cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.5),
                          ),
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            searchKeyword = val.trim();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filteredCategories.isEmpty
                            ? const Center(
                                child: Text(
                                  'No matching category found',
                                  style: TextStyle(fontSize: 13, color: AppTheme.mediumGrey),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredCategories.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
                                itemBuilder: (context, index) {
                                  final cat = filteredCategories[index];
                                  final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
                                  final isAll = cat.toLowerCase() == 'all';
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    tileColor: isSelected ? const Color(0xFF14332E).withValues(alpha: 0.08) : Colors.transparent,
                                    leading: Icon(
                                      isAll ? Icons.all_inclusive_rounded : Icons.label_rounded,
                                      size: 18,
                                      color: isSelected ? const Color(0xFF14332E) : AppTheme.mediumGrey,
                                    ),
                                    title: Text(
                                      isAll ? 'All Categories' : cat,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? const Color(0xFF14332E) : AppTheme.darkGrey,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF14332E))
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedCategory = cat;
                                        _demandQueueCurrentPage = 1;
                                        _stockDeficitCurrentPage = 1;
                                      });
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildPeriodToggle({required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 1.0),
      ),
      child: Row(
        mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
        children: timeFilters.map((period) {
          final isSel = _selectedTimeFilter == period;
          final itemWidget = GestureDetector(
            onTap: () => setState(() {
              _selectedTimeFilter = period;
              if (period == 'Weekly' &&
                  _selectedWeeklyMonth == monthFilters[DateTime.now().month - 1]) {
                final currentWeekNum = ((DateTime.now().day - 1) ~/ 7) + 1;
                _selectedWeekFilter = 'Week ${currentWeekNum.clamp(1, 5)}';
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFF14332E) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                period,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                  color: isSel ? Colors.white : Colors.black,
                ),
              ),
            ),
          );

          if (isMobile) {
            return Expanded(child: itemWidget);
          }
          return itemWidget;
        }).toList(),
      ),
    );
  }

  Widget _buildActiveTimeBadge() {
    String text;
    switch (_selectedTimeFilter) {
      case 'Daily':
        text = '$_selectedDailyMonth $_selectedDailyDay, 2026';
        break;
      case 'Weekly':
        final range = _getWeekDateRangeLabel(_selectedWeekFilter);
        text = '$_selectedWeeklyMonth 2026 ($_selectedWeekFilter${range.isNotEmpty ? ' • $range' : ''})';
        break;
      case 'Monthly':
        text = 'Month of $_selectedMonthFilter 2026';
        break;
      case 'Annually':
        text = 'Year $_selectedYearFilter';
        break;
      default:
        text = _selectedTimeFilter;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_available_rounded, size: 14, color: Colors.black),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryTimeDropdown({required bool isMobile}) {
    switch (_selectedTimeFilter) {
      case 'Daily':
        if (isMobile) {
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: _styledDropdown(
                  value: _selectedDailyMonth,
                  items: monthFilters,
                  onChanged: (v) => setState(() => _selectedDailyMonth = v!),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _styledDropdown(
                  value: _selectedDailyDay,
                  items: dayFilters,
                  prefix: 'Day ',
                  onChanged: (v) => setState(() => _selectedDailyDay = v!),
                ),
              ),
            ],
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              child: _styledDropdown(
                value: _selectedDailyMonth,
                items: monthFilters,
                onChanged: (v) => setState(() => _selectedDailyMonth = v!),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 105,
              child: _styledDropdown(
                value: _selectedDailyDay,
                items: dayFilters,
                prefix: 'Day ',
                onChanged: (v) => setState(() => _selectedDailyDay = v!),
              ),
            ),
          ],
        );

      case 'Weekly':
        final availableWeeks = _getWeeksForMonth(_selectedWeeklyMonth);
        final weekSubtitles = {
          for (var w in availableWeeks) w: _getWeekDateRangeLabel(w),
        };
        if (isMobile) {
          return Row(
            children: [
              Expanded(
                flex: 4,
                child: _styledDropdown(
                  value: _selectedWeeklyMonth,
                  items: monthFilters,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedWeeklyMonth = v;
                        final weeks = _getWeeksForMonth(v);
                        if (!weeks.contains(_selectedWeekFilter)) {
                          _selectedWeekFilter = weeks.last;
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 5,
                child: _styledDropdown(
                  value: _selectedWeekFilter,
                  items: availableWeeks,
                  itemSubtitles: weekSubtitles,
                  onChanged: (v) => setState(() => _selectedWeekFilter = v!),
                ),
              ),
            ],
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              child: _styledDropdown(
                value: _selectedWeeklyMonth,
                items: monthFilters,
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedWeeklyMonth = v;
                      final weeks = _getWeeksForMonth(v);
                      if (!weeks.contains(_selectedWeekFilter)) {
                        _selectedWeekFilter = weeks.last;
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 190,
              child: _styledDropdown(
                value: _selectedWeekFilter,
                items: availableWeeks,
                itemSubtitles: weekSubtitles,
                onChanged: (v) => setState(() => _selectedWeekFilter = v!),
              ),
            ),
          ],
        );

      case 'Monthly':
        if (isMobile) {
          return _styledDropdown(
            value: _selectedMonthFilter,
            items: monthFilters,
            onChanged: (v) => setState(() => _selectedMonthFilter = v!),
          );
        }
        return SizedBox(
          width: 150,
          child: _styledDropdown(
            value: _selectedMonthFilter,
            items: monthFilters,
            onChanged: (v) => setState(() => _selectedMonthFilter = v!),
          ),
        );

      case 'Annually':
        if (isMobile) {
          return _styledDropdown(
            value: _selectedYearFilter,
            items: yearFilters,
            onChanged: (v) => setState(() => _selectedYearFilter = v!),
          );
        }
        return SizedBox(
          width: 120,
          child: _styledDropdown(
            value: _selectedYearFilter,
            items: yearFilters,
            onChanged: (v) => setState(() => _selectedYearFilter = v!),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  List<String> _getWeeksForMonth(String monthName) {
    final monthIdx = _getMonthIndex(monthName);
    final daysInMonth = DateTime(DateTime.now().year, monthIdx + 1, 0).day;
    if (daysInMonth > 28) {
      return ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5'];
    }
    return ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
  }

  Widget _styledDropdown({
    required String value,
    required List<String> items,
    String prefix = '',
    Map<String, String>? itemSubtitles,
    required ValueChanged<String?> onChanged,
    bool isExpanded = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.adminMainBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 1.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          isExpanded: isExpanded,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.black),
          items: items.map((i) {
            final sub = itemSubtitles?[i];
            if (sub != null && sub.isNotEmpty) {
              return DropdownMenuItem<String>(
                value: i,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text('$prefix$i', style: const TextStyle(color: Colors.black), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              );
            }
            return DropdownMenuItem<String>(
              value: i,
              child: Text('$prefix$i', style: const TextStyle(color: Colors.black), overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }


  // ── Main Content Section ───────────────────────────────────────────────────
  Widget _buildMainContent(
    List<Map<String, dynamic>> categoryFiltered,
    List<Map<String, dynamic>> timeFiltered,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // View Mode Switcher Header
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _viewModeTab('Chart', Icons.bar_chart_rounded, 'Demand Analytics', 'Usage Charts'),
                    const SizedBox(width: 8),
                    _viewModeTab('Feed', Icons.format_list_bulleted_rounded, 'Demand Queue', 'Ticket Log'),
                    const SizedBox(width: 8),
                    _viewModeTab('Deficit', Icons.warning_amber_rounded, 'Stock Deficits', 'Reorder Warnings'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${timeFiltered.length} demand records in scope',
                  style: const TextStyle(fontSize: 11, color: AppTheme.mediumGrey, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _viewModeTab('Chart', Icons.bar_chart_rounded, 'Demand Analytics', 'Top Usage Chart'),
                  const SizedBox(width: 8),
                  _viewModeTab('Feed', Icons.format_list_bulleted_rounded, 'Demand Queue', 'Itemized Ticket Log'),
                  const SizedBox(width: 8),
                  _viewModeTab('Deficit', Icons.warning_amber_rounded, 'Stock Deficits', 'Critical Reorders'),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.dataset_rounded, size: 14, color: AppTheme.mediumGrey),
                    const SizedBox(width: 6),
                    Text(
                      '${timeFiltered.length} Demand Records in Scope',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.darkGrey, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),

        const SizedBox(height: 14),

        if (timeFiltered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.query_stats_rounded, size: 48, color: AppTheme.mediumGrey),
                  const SizedBox(height: 12),
                  Text(
                    _selectedDemandSource == 'All'
                        ? 'No demand records in this timeframe'
                        : 'No $_selectedDemandSource demand records in this timeframe',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkGrey),
                  ),
                  const SizedBox(height: 4),
                  const Text('Try switching to another month, week, or select "Monthly" or "Annually"',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.mediumGrey)),
                ],
              ),
            ),
          )
        else if (_selectedViewMode == 'Chart')
          _buildBarChartCard(categoryFiltered)
        else if (_selectedViewMode == 'Deficit')
          _buildDeficitMatrix(timeFiltered, isMobile)
        else
          _buildDemandFeed(timeFiltered, isMobile),
      ],
    );
  }

  Widget _viewModeTab(String mode, IconData icon, String label, String subtitle) {
    final isSelected = _selectedViewMode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedViewMode = mode;
        _demandQueueCurrentPage = 1;
        _stockDeficitCurrentPage = 1;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF14332E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF14332E) : AppTheme.cardBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF14332E).withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.darkGrey),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                    color: isSelected ? Colors.white : AppTheme.darkGrey,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white70 : AppTheme.mediumGrey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Demand Bar Chart Card (Executive Demand Visualizer) ────────────────
  Widget _buildBarChartCard(List<Map<String, dynamic>> forecast) {
    final chartData = _getTopItemsData(forecast);
    final barGroups = chartData['barGroups'] as List<BarChartGroupData>;
    final topItems = chartData['topItems'] as List<MapEntry<String, double>>;
    final itemDetails = chartData['itemDetails'] as Map<String, Map<String, dynamic>>;
    final calculatedMaxY = (chartData['calculatedMaxY'] as num?)?.toDouble() ?? 10.0;
    final isMobile = ResponsiveUtils.isMobile(context);

    if (topItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black, width: 1.0),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart_rounded, size: 44, color: Colors.black),
              SizedBox(height: 10),
              Text('No demand records in this timeframe to graph.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
            ],
          ),
        ),
      );
    }

    final double gridInterval;
    if (calculatedMaxY <= 5) {
      gridInterval = 1.0;
    } else if (calculatedMaxY <= 10) {
      gridInterval = 2.0;
    } else if (calculatedMaxY <= 50) {
      gridInterval = 10.0;
    } else if (calculatedMaxY <= 100) {
      gridInterval = 25.0;
    } else {
      gridInterval = (calculatedMaxY / 4).clamp(1.0, double.infinity);
    }

    final double? chartWidth = isMobile
        ? math.max(MediaQuery.of(context).size.width - 64, topItems.length * 72.0)
        : null;

    final chartWidget = BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: calculatedMaxY,
        minY: 0,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF14332E),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipMargin: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = topItems[group.x];
              final details = itemDetails[item.key] ?? {};
              final unit = details['unit'] ?? 'units';
              final category = details['category'] ?? '';

              return BarTooltipItem(
                '${item.key}\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                children: [
                  TextSpan(
                    text: '${_formatQty(rod.toY)} $unit needed',
                    style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  if (category.isNotEmpty) ...[
                    const TextSpan(text: '\n'),
                    TextSpan(
                      text: category,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < topItems.length) {
                  final item = topItems[index];
                  final details = itemDetails[item.key] ?? {};
                  final unit = details['unit']?.toString() ?? '';
                  final unitLabel = unit.length > 4 ? unit.substring(0, 3) : unit;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14332E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${_formatQty(item.value)} $unitLabel',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF14332E),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: calculatedMaxY >= 1000 ? 44 : 36,
              interval: gridInterval,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > calculatedMaxY) return const SizedBox.shrink();
                return Text(
                  _formatAxisValue(value),
                  style: const TextStyle(color: Colors.black, fontSize: 9.5, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < topItems.length) {
                  final label = topItems[index].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: isMobile ? 68 : 88,
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isMobile ? 8.5 : 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          height: 1.15,
                        ),
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: gridInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.black.withValues(alpha: 0.12),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black, width: 0.8),
                          ),
                          child: const Icon(Icons.bar_chart_rounded, size: 16, color: Colors.black),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Top Kitchen Ingredients by Consumption',
                            style: TextStyle(
                              fontSize: isMobile ? 13.5 : 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Highest requested supplies for $_selectedTimeFilter • Ranked by kitchen volume',
                      style: const TextStyle(fontSize: 11, color: Colors.black),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Top-N Count Selector (5, 8, 10)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.adminMainBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [5, 8, 10].map((n) {
                    final isSel = _topItemsCount == n;
                    return GestureDetector(
                      onTap: () => setState(() => _topItemsCount = n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF14332E) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Top $n',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Bar Chart Widget ──
          SizedBox(
            height: 270,
            child: isMobile
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: chartWidth,
                      height: 270,
                      child: chartWidget,
                    ),
                  )
                : chartWidget,
          ),

          if (isMobile && topItems.length > 4) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.swipe_rounded, size: 14, color: Colors.black),
                SizedBox(width: 5),
                Text(
                  'Scroll chart horizontally to view all ingredient bars',
                  style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          const Divider(height: 1, color: Colors.black),
          const SizedBox(height: 16),

          // ── Ranked Consumption Leaderboard & Stock Health ──
          () {
            int deficitCount = 0;
            int coveredCount = 0;
            for (var item in topItems) {
              final details = itemDetails[item.key] ?? {};
              final stock = (details['currentStock'] as num?)?.toDouble() ?? 0.0;
              if (stock < item.value) {
                deficitCount++;
              } else {
                coveredCount++;
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Summary & Table/Card View Toggle
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black, width: 0.8),
                          ),
                          child: const Icon(Icons.military_tech_rounded, size: 14, color: Colors.black),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'CONSUMPTION LEADERBOARD & STOCK HEALTH',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Deficit & Covered Counters
                        if (deficitCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black, width: 0.8),
                            ),
                            child: Text(
                              '$deficitCount Deficit Risk',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (coveredCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black, width: 0.8),
                            ),
                            child: Text(
                              '$coveredCount Covered',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // View Mode Toggle (Cards vs Table)
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            color: AppTheme.adminMainBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black, width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _leaderboardTableView = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: !_leaderboardTableView ? const Color(0xFF14332E) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.grid_view_rounded,
                                    size: 13,
                                    color: !_leaderboardTableView ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              GestureDetector(
                                onTap: () => setState(() => _leaderboardTableView = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _leaderboardTableView ? const Color(0xFF14332E) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.table_rows_rounded,
                                    size: 13,
                                    color: _leaderboardTableView ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Content View (Cards or Table)
                if (_leaderboardTableView)
                  _buildLeaderboardTable(topItems, itemDetails, isMobile)
                else
                  _buildLeaderboardCards(topItems, itemDetails),
              ],
            );
          }(),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCards(
    List<MapEntry<String, double>> topItems,
    Map<String, Map<String, dynamic>> itemDetails,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final crossAxisCount = isWide ? 2 : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10,
            mainAxisExtent: 82,
          ),
          itemBuilder: (context, index) {
            final item = topItems[index];
            final details = itemDetails[item.key] ?? {};
            final unit = details['unit'] ?? 'units';
            final category = details['category'] ?? 'General';
            final storage = details['storage'] ?? 'Storage';
            final currentStock = (details['currentStock'] as num?)?.toDouble() ?? 0.0;
            final demand = item.value;
            final hasDeficit = currentStock < demand;
            final deficitQty = demand - currentStock;
            final coverageRatio = demand > 0 ? (currentStock / demand).clamp(0.0, 1.0) : 1.0;

            Color rankColor;
            Color rankBg;
            if (index == 0) {
              rankColor = const Color(0xFFB45309);
              rankBg = const Color(0xFFFEF3C7);
            } else if (index == 1) {
              rankColor = const Color(0xFF475569);
              rankBg = const Color(0xFFE2E8F0);
            } else if (index == 2) {
              rankColor = const Color(0xFF9A3412);
              rankBg = const Color(0xFFFFEDD5);
            } else {
              rankColor = const Color(0xFF14332E);
              rankBg = const Color(0xFFF1F5F9);
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.black,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Row 1: Rank + Item Name + Status Pill
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rankBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 0.8),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: rankColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.key,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: currentStock <= 0
                              ? const Color(0xFFFEF2F2)
                              : (hasDeficit ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4)),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.black, width: 0.8),
                        ),
                        child: Text(
                          currentStock <= 0
                              ? 'Out of Stock'
                              : (hasDeficit ? 'Deficit: -${_formatQty(deficitQty)} $unit' : 'Covered (+${_formatQty(currentStock - demand)})'),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: currentStock <= 0
                                ? const Color(0xFFDC2626)
                                : (hasDeficit ? const Color(0xFFC2410C) : const Color(0xFF16A34A)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Row 2: Category & Storage | Stock vs Need
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$category • $storage',
                        style: const TextStyle(fontSize: 9.5, color: Colors.black, fontWeight: FontWeight.w500),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Stock: ${_formatQty(currentStock)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: currentStock <= 0 ? const Color(0xFFDC2626) : Colors.black,
                              ),
                            ),
                            const TextSpan(
                              text: '  /  ',
                              style: TextStyle(fontSize: 9, color: Colors.black),
                            ),
                            TextSpan(
                              text: 'Need: ${_formatQty(demand)} $unit',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Row 3: Slim Coverage Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: coverageRatio,
                      minHeight: 4,
                      backgroundColor: const Color(0xFF14332E).withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        currentStock <= 0
                            ? const Color(0xFFEF4444)
                            : (hasDeficit ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLeaderboardTable(
    List<MapEntry<String, double>> topItems,
    Map<String, Map<String, dynamic>> itemDetails,
    bool isMobile,
  ) {
    final tableWidget = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: Colors.transparent,
              child: Row(
                children: const [
                  SizedBox(
                    width: 38,
                    child: Text(
                      '#',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'INGREDIENT & CATEGORY',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'STORAGE ROOM',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'PROJECTED DEMAND',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'ON-HAND STOCK',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'DEFICIT SHORTAGE',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'STOCK STATUS',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.black),

            // Rows
            ...List.generate(topItems.length, (index) {
              final item = topItems[index];
              final details = itemDetails[item.key] ?? {};
              final unit = details['unit'] ?? 'units';
              final category = details['category'] ?? 'General';
              final storage = details['storage'] ?? 'Storage';
              final currentStock = (details['currentStock'] as num?)?.toDouble() ?? 0.0;
              final demand = item.value;
              final hasDeficit = currentStock < demand;
              final deficitQty = demand - currentStock;

              Color rankColor;
              Color rankBg;
              if (index == 0) {
                rankColor = const Color(0xFFB45309);
                rankBg = const Color(0xFFFEF3C7);
              } else if (index == 1) {
                rankColor = const Color(0xFF475569);
                rankBg = const Color(0xFFE2E8F0);
              } else if (index == 2) {
                rankColor = const Color(0xFF9A3412);
                rankBg = const Color(0xFFFFEDD5);
              } else {
                rankColor = const Color(0xFF14332E);
                rankBg = const Color(0xFFF1F5F9);
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: index < topItems.length - 1
                      ? const Border(bottom: BorderSide(color: Colors.black, width: 1.0))
                      : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 38,
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rankBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 0.8),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: rankColor),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.key,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                          Text(
                            category,
                            style: const TextStyle(fontSize: 10, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        storage,
                        style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${_formatQty(demand)} $unit',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${_formatQty(currentStock)} $unit',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: currentStock <= 0 ? const Color(0xFFDC2626) : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        hasDeficit ? '-${_formatQty(deficitQty)} $unit' : '0 (None)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: hasDeficit ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: currentStock <= 0
                                ? const Color(0xFFFEF2F2)
                                : (hasDeficit ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4)),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.black, width: 0.8),
                          ),
                          child: Text(
                            currentStock <= 0 ? 'Out of Stock' : (hasDeficit ? 'Deficit Risk' : 'Sufficient'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: currentStock <= 0
                                  ? const Color(0xFFDC2626)
                                  : (hasDeficit ? const Color(0xFFC2410C) : const Color(0xFF16A34A)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: 720,
          child: tableWidget,
        ),
      );
    }
    return tableWidget;
  }

  // ── Reorder / Stock Deficit Matrix View (Enterprise Procurement Table) ────
  Widget _buildDeficitMatrix(List<Map<String, dynamic>> items, bool isMobile) {
    // 1. Filter items with real deficit
    final allDeficitItems = items.where((i) {
      final req = (i['requestQuantity'] as num).toDouble();
      final stock = (i['currentStock'] as num).toDouble();
      return stock < req;
    }).toList();

    if (allDeficitItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: AppTheme.successGreen, size: 44),
              SizedBox(height: 10),
              Text('No Stock Deficits Detected',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkGrey)),
              SizedBox(height: 4),
              Text('All requested ingredients in this timeframe were covered by available inventory.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.mediumGrey)),
            ],
          ),
        ),
      );
    }

    // 2. In-Queue Search filter
    final query = _stockDeficitSearchQuery.trim().toLowerCase();
    final filteredDeficits = query.isEmpty
        ? allDeficitItems
        : allDeficitItems.where((it) {
            final name = (it['name'] ?? '').toString().toLowerCase();
            final category = (it['category'] ?? '').toString().toLowerCase();
            final menuCategory = (it['menuCategory'] ?? '').toString().toLowerCase();
            final notes = (it['notes'] ?? '').toString().toLowerCase();
            final storage = (it['storage_room'] ?? '').toString().toLowerCase();
            final src = (it['demandSource'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                category.contains(query) ||
                menuCategory.contains(query) ||
                notes.contains(query) ||
                storage.contains(query) ||
                src.contains(query);
          }).toList();

    // 3. Deficit Matrix Pagination (15 items per page)
    final totalItems = filteredDeficits.length;
    final totalPages = totalItems > 0 ? (totalItems / _forecastItemsPerPage).ceil() : 1;
    if (_stockDeficitCurrentPage > totalPages) {
      _stockDeficitCurrentPage = totalPages;
    }
    if (_stockDeficitCurrentPage < 1) {
      _stockDeficitCurrentPage = 1;
    }

    final startIndex = (_stockDeficitCurrentPage - 1) * _forecastItemsPerPage;
    final endIndex = (startIndex + _forecastItemsPerPage < totalItems)
        ? startIndex + _forecastItemsPerPage
        : totalItems;

    final paginatedDeficits = totalItems > 0
        ? filteredDeficits.sublist(startIndex, endIndex)
        : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Deficit Header Control Bar ──
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CRITICAL STOCK DEFICITS (${filteredDeficits.length} SKUs)',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDeficitSearchField(),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 0.8),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'CRITICAL STOCK DEFICITS',
                              style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black, width: 0.8),
                              ),
                              child: Text(
                                query.isEmpty
                                    ? '${allDeficitItems.length} SKUs Reorder Alert'
                                    : '${filteredDeficits.length} of ${allDeficitItems.length} SKUs',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Demand exceeds warehouse on-hand stock. Recommended reorder quantities are prioritized below.',
                          style: TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Deficit Quick Search
                    _buildDeficitSearchField(),
                    const SizedBox(width: 8),
                    // Table vs Cards View Toggle
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.adminMainBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _viewToggleButton(
                            icon: Icons.table_chart_rounded,
                            label: 'Table',
                            isActive: _stockDeficitTableView,
                            onTap: () => setState(() => _stockDeficitTableView = true),
                          ),
                          _viewToggleButton(
                            icon: Icons.view_agenda_rounded,
                            label: 'Cards',
                            isActive: !_stockDeficitTableView,
                            onTap: () => setState(() => _stockDeficitTableView = false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),

        // ── Main Deficit Content (Table or Cards) ──
        if (_stockDeficitTableView && !isMobile)
          _buildDeficitQueueTable(paginatedDeficits)
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginatedDeficits.length,
            itemBuilder: (context, index) {
              return _buildDemandCard(paginatedDeficits[index], isDeficitView: true);
            },
          ),

        // ── Pagination ──
        if (filteredDeficits.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildForecastPagination(
            totalItems: totalItems,
            currentPage: _stockDeficitCurrentPage,
            totalPages: totalPages,
            onPageChanged: (newPage) {
              setState(() {
                _stockDeficitCurrentPage = newPage;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDeficitSearchField() {
    return SizedBox(
      width: 220,
      height: 34,
      child: TextField(
        style: const TextStyle(fontSize: 11.5, color: Colors.black),
        decoration: InputDecoration(
          hintText: 'Search deficits...',
          hintStyle: const TextStyle(fontSize: 11.5, color: Colors.black54),
          prefixIcon: const Icon(Icons.search_rounded, size: 15, color: Colors.black),
          suffixIcon: _stockDeficitSearchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    _stockDeficitSearchQuery = '';
                    _stockDeficitCurrentPage = 1;
                  }),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.black),
                )
              : null,
          filled: true,
          fillColor: AppTheme.adminMainBackground.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 1.5),
          ),
        ),
        onChanged: (val) {
          setState(() {
            _stockDeficitSearchQuery = val;
            _stockDeficitCurrentPage = 1;
          });
        },
      ),
    );
  }

  Widget _buildDeficitQueueTable(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black, width: 1.0),
        ),
        child: const Center(
          child: Text(
            'No matching deficit items found',
            style: TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Table Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              color: Colors.transparent,
              child: Row(
                children: const [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'DEFICIT SKU & STORAGE',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'DEMAND SOURCE',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'TOTAL DEMAND',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'CURRENT IN-STOCK',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'REORDER DEFICIT',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'REQUEST INFO & DATE',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.black),

            // Table Data Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black),
              itemBuilder: (context, index) {
                final item = items[index];
                final name = (item['name'] ?? '').toString();
                final category = (item['category'] ?? '').toString();
                final unit = (item['unit'] ?? '').toString();
                final reqQty = (item['requestQuantity'] as num?)?.toDouble() ?? 0.0;
                final currentStock = (item['currentStock'] as num?)?.toDouble() ?? 0.0;
                final storageRoom = (item['storage_room'] ?? '').toString();
                final notes = (item['notes'] ?? '').toString();
                final requestedBy = (item['requestedBy'] ?? 'Chef / Kitchen').toString();
                final demandSource = (item['demandSource'] ?? 'Kitchen Request').toString();

                DateTime? createdAt;
                try {
                  createdAt = DateTime.parse(item['createdAt'] as String).toLocal();
                } catch (_) {}

                final deficit = reqQty - currentStock;

                Color srcBg;
                IconData srcIcon;
                String srcLabel;
                switch (demandSource) {
                  case 'POS Walk-in':
                    srcBg = const Color(0xFF3B82F6).withValues(alpha: 0.1);
                    srcIcon = Icons.point_of_sale_rounded;
                    srcLabel = 'POS Walk-in';
                    break;
                  case 'Advance Order':
                    srcBg = const Color(0xFF8B5CF6).withValues(alpha: 0.1);
                    srcIcon = Icons.schedule_send_rounded;
                    srcLabel = 'Advance Order';
                    break;
                  case 'Catering Reservation':
                    srcBg = const Color(0xFFEA580C).withValues(alpha: 0.1);
                    srcIcon = Icons.celebration_rounded;
                    srcLabel = 'Catering Event';
                    break;
                  default:
                    srcBg = const Color(0xFF10B981).withValues(alpha: 0.1);
                    srcIcon = Icons.restaurant_rounded;
                    srcLabel = 'Kitchen Req';
                    break;
                }

                return Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Item & Storage
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black, width: 0.8),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$category • $storageRoom',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Demand Channel
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: srcBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(srcIcon, size: 11, color: Colors.black),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    srcLabel,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Required Demand
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${_formatQty(reqQty)} $unit',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Current In-Stock
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${_formatQty(currentStock)} $unit',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: currentStock == 0 ? const Color(0xFFEF4444) : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Reorder Deficit
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 11,
                                  color: Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Deficit -${_formatQty(deficit)} $unit',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFDC2626),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Request Info & Date
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notes.isNotEmpty ? notes : 'By $requestedBy',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Colors.black,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (createdAt != null)
                              Text(
                                DateFormat('MMM d, h:mm a').format(createdAt),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Demand Feed View (Enterprise Audit Queue) ─────────────────────────────
  Widget _buildDemandFeed(List<Map<String, dynamic>> items, bool isMobile) {
    // 1. In-Queue Search filter
    final query = _demandQueueSearchQuery.trim().toLowerCase();
    final filteredItems = query.isEmpty
        ? items
        : items.where((it) {
            final name = (it['name'] ?? '').toString().toLowerCase();
            final category = (it['category'] ?? '').toString().toLowerCase();
            final menuCategory = (it['menuCategory'] ?? '').toString().toLowerCase();
            final notes = (it['notes'] ?? '').toString().toLowerCase();
            final storage = (it['storage_room'] ?? '').toString().toLowerCase();
            final src = (it['demandSource'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                category.contains(query) ||
                menuCategory.contains(query) ||
                notes.contains(query) ||
                storage.contains(query) ||
                src.contains(query);
          }).toList();

    // 2. Pagination (15 items per page)
    final totalItems = filteredItems.length;
    final totalPages = totalItems > 0 ? (totalItems / _forecastItemsPerPage).ceil() : 1;
    if (_demandQueueCurrentPage > totalPages) {
      _demandQueueCurrentPage = totalPages;
    }
    if (_demandQueueCurrentPage < 1) {
      _demandQueueCurrentPage = 1;
    }

    final startIndex = (_demandQueueCurrentPage - 1) * _forecastItemsPerPage;
    final endIndex = (startIndex + _forecastItemsPerPage < totalItems)
        ? startIndex + _forecastItemsPerPage
        : totalItems;

    final paginatedItems = totalItems > 0
        ? filteredItems.sublist(startIndex, endIndex)
        : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Demand Queue Header Control Bar ──
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF86EFAC).withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF16A34A), size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ITEMIZED DEMAND QUEUE (${filteredItems.length} Tickets)',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildQueueSearchField(),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 0.8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF16A34A), size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'ITEMIZED DEMAND QUEUE',
                              style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black, width: 0.8),
                              ),
                              child: Text(
                                query.isEmpty
                                    ? '${items.length} Tickets in Scope'
                                    : '${filteredItems.length} of ${items.length} Tickets',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Complete audit trail of customer receipts, kitchen requisition slips, and catering reservations.',
                          style: TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Quick Search Field
                    _buildQueueSearchField(),
                    const SizedBox(width: 8),
                    // Table vs Card View Toggle
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.adminMainBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _viewToggleButton(
                            icon: Icons.table_chart_rounded,
                            label: 'Table',
                            isActive: _demandQueueTableView,
                            onTap: () => setState(() => _demandQueueTableView = true),
                          ),
                          _viewToggleButton(
                            icon: Icons.view_agenda_rounded,
                            label: 'Cards',
                            isActive: !_demandQueueTableView,
                            onTap: () => setState(() => _demandQueueTableView = false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),

        // ── Main Queue Content (Table or Cards) ──
        if (_demandQueueTableView && !isMobile)
          _buildDemandQueueTable(paginatedItems)
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginatedItems.length,
            itemBuilder: (context, index) {
              return _buildDemandCard(paginatedItems[index], isDeficitView: false);
            },
          ),

        // ── Pagination ──
        if (filteredItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildForecastPagination(
            totalItems: totalItems,
            currentPage: _demandQueueCurrentPage,
            totalPages: totalPages,
            onPageChanged: (newPage) {
              setState(() {
                _demandQueueCurrentPage = newPage;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildQueueSearchField() {
    return SizedBox(
      width: 220,
      height: 34,
      child: TextField(
        style: const TextStyle(fontSize: 11.5, color: Colors.black),
        decoration: InputDecoration(
          hintText: 'Search tickets...',
          hintStyle: const TextStyle(fontSize: 11.5, color: Colors.black54),
          prefixIcon: const Icon(Icons.search_rounded, size: 15, color: Colors.black),
          suffixIcon: _demandQueueSearchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    _demandQueueSearchQuery = '';
                    _demandQueueCurrentPage = 1;
                  }),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.black),
                )
              : null,
          filled: true,
          fillColor: AppTheme.adminMainBackground.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 1.5),
          ),
        ),
        onChanged: (val) {
          setState(() {
            _demandQueueSearchQuery = val;
            _demandQueueCurrentPage = 1;
          });
        },
      ),
    );
  }

  Widget _viewToggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF14332E) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isActive ? Colors.white : Colors.black),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemandQueueTable(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black, width: 1.0),
        ),
        child: const Center(
          child: Text(
            'No matching tickets in queue',
            style: TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Table Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              color: Colors.transparent,
              child: Row(
                children: const [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'ITEM & STORAGE',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'DEMAND CHANNEL',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'REQUIRED DEMAND',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'CURRENT STOCK',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'STATUS / HEALTH',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'EVENT / NOTE & DATE',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.black),

            // Table Data Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black),
              itemBuilder: (context, index) {
                final item = items[index];
                final name = (item['name'] ?? '').toString();
                final category = (item['category'] ?? '').toString();
                final unit = (item['unit'] ?? '').toString();
                final reqQty = (item['requestQuantity'] as num?)?.toDouble() ?? 0.0;
                final currentStock = (item['currentStock'] as num?)?.toDouble() ?? 0.0;
                final storageRoom = (item['storage_room'] ?? '').toString();
                final notes = (item['notes'] ?? '').toString();
                final requestedBy = (item['requestedBy'] ?? 'Chef / Kitchen').toString();
                final demandSource = (item['demandSource'] ?? 'Kitchen Request').toString();

                DateTime? createdAt;
                try {
                  createdAt = DateTime.parse(item['createdAt'] as String).toLocal();
                } catch (_) {}

                final deficit = reqQty - currentStock;
                final hasDeficit = deficit > 0;

                // Demand source color & icon
                Color srcBg;
                IconData srcIcon;
                String srcLabel;
                switch (demandSource) {
                  case 'POS Walk-in':
                    srcBg = const Color(0xFF3B82F6).withValues(alpha: 0.1);
                    srcIcon = Icons.point_of_sale_rounded;
                    srcLabel = 'POS Walk-in';
                    break;
                  case 'Advance Order':
                    srcBg = const Color(0xFF8B5CF6).withValues(alpha: 0.1);
                    srcIcon = Icons.schedule_send_rounded;
                    srcLabel = 'Advance Order';
                    break;
                  case 'Catering Reservation':
                    srcBg = const Color(0xFFEA580C).withValues(alpha: 0.1);
                    srcIcon = Icons.celebration_rounded;
                    srcLabel = 'Catering Event';
                    break;
                  default:
                    srcBg = const Color(0xFF10B981).withValues(alpha: 0.1);
                    srcIcon = Icons.restaurant_rounded;
                    srcLabel = 'Kitchen Req';
                    break;
                }

                return Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Item & Storage
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: hasDeficit
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                    : const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black, width: 0.8),
                              ),
                              child: Icon(
                                hasDeficit ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                                size: 14,
                                color: hasDeficit ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$category • $storageRoom',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Demand Channel
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: srcBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(srcIcon, size: 11, color: Colors.black),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    srcLabel,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Required Demand
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${_formatQty(reqQty)} $unit',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Current In-Stock
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${_formatQty(currentStock)} $unit',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: currentStock == 0 ? const Color(0xFFEF4444) : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Status / Health
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: hasDeficit
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                  : const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.black,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasDeficit ? Icons.error_outline_rounded : Icons.check_rounded,
                                  size: 11,
                                  color: hasDeficit ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    hasDeficit ? 'Deficit -${_formatQty(deficit)} $unit' : 'Covered',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: hasDeficit ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Notes & Date
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notes.isNotEmpty ? notes : 'By $requestedBy',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Colors.black,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (createdAt != null)
                              Text(
                                DateFormat('MMM d, h:mm a').format(createdAt),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastPagination({
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = ((currentPage - 1) * _forecastItemsPerPage) + 1;
    final endItem = (currentPage * _forecastItemsPerPage < totalItems)
        ? currentPage * _forecastItemsPerPage
        : totalItems;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing $startItem–$endItem of $totalItems records',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black, width: 0.8),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          if (totalPages > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Prev Button
                    InkWell(
                      onTap: currentPage > 1
                          ? () {
                              onPageChanged(currentPage - 1);
                            }
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: currentPage > 1 ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.black,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chevron_left_rounded,
                              size: 16,
                              color: currentPage > 1 ? Colors.white : Colors.black45,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Prev',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: currentPage > 1 ? Colors.white : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Page Number Buttons with smart ellipsis window
                    ...List.generate(totalPages, (index) {
                      final pageNum = index + 1;
                      if (totalPages > 5) {
                        if (pageNum != 1 &&
                            pageNum != totalPages &&
                            (pageNum < currentPage - 1 || pageNum > currentPage + 1)) {
                          if (pageNum == currentPage - 2 || pageNum == currentPage + 2) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '…',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }
                      }

                      final isSelected = pageNum == currentPage;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () {
                            if (!isSelected) {
                              onPageChanged(pageNum);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF14332E) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.black,
                                width: isSelected ? 1.2 : 1.0,
                              ),
                            ),
                            child: Text(
                              '$pageNum',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(width: 8),

                    // Next Button
                    InkWell(
                      onTap: currentPage < totalPages
                          ? () {
                              onPageChanged(currentPage + 1);
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: currentPage < totalPages ? const Color(0xFF14332E) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.black,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Next',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: currentPage < totalPages ? Colors.white : Colors.black45,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: currentPage < totalPages ? Colors.white : Colors.black45,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Go to page input (Digits only - letters strictly prohibited)
                _buildPageJumpInput(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPageSubmitted: onPageChanged,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageJumpInput({
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageSubmitted,
  }) {
    final controller = TextEditingController(text: currentPage.toString());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Go to:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 48,
            height: 28,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.black, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.black, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                ),
              ),
              onSubmitted: (val) {
                final page = int.tryParse(val.trim());
                if (page != null) {
                  final clampedPage = page.clamp(1, totalPages);
                  onPageSubmitted(clampedPage);
                }
              },
            ),
          ),
          const SizedBox(width: 5),
          InkWell(
            onTap: () {
              final page = int.tryParse(controller.text.trim());
              if (page != null) {
                final clampedPage = page.clamp(1, totalPages);
                onPageSubmitted(clampedPage);
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF14332E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black, width: 1.0),
              ),
              child: const Text(
                'Go',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandCard(Map<String, dynamic> item, {required bool isDeficitView}) {
    final name = item['name'] as String;
    final category = item['category'] as String;
    final unit = item['unit'] as String;
    final reqQty = (item['requestQuantity'] as num).toDouble();
    final currentStock = (item['currentStock'] as num).toDouble();
    final storageRoom = item['storage_room'] as String;
    final requestedBy = item['requestedBy']?.toString() ?? 'Chef / Kitchen';
    final notes = item['notes']?.toString() ?? '';
    final status = (item['status']?.toString() ?? 'Approved').toLowerCase();
    final isPending = status == 'pending';
    final demandSource = item['demandSource']?.toString() ?? 'Kitchen Request';
    final isPos = demandSource == 'POS Walk-in';

    DateTime? createdAt;
    try {
      createdAt = DateTime.parse(item['createdAt'] as String).toLocal();
    } catch (_) {}

    final deficit = reqQty - currentStock;
    final hasDeficit = deficit > 0;

    final iconBg = hasDeficit ? const Color(0xFFEF4444).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12);
    final iconFg = hasDeficit ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final iconData = hasDeficit ? Icons.warning_amber_rounded : Icons.check_circle_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.black, width: 0.8),
                ),
                child: Icon(iconData, size: 15, color: iconFg),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$category • $storageRoom',
                      style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 5,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Demand Source Badge
                  Builder(
                    builder: (context) {
                      Color badgeBg;
                      Color badgeFg;
                      IconData badgeIcon;
                      String badgeText;

                      switch (demandSource) {
                        case 'POS Walk-in':
                          badgeBg = const Color(0xFF3B82F6).withValues(alpha: 0.1);
                          badgeFg = const Color(0xFF2563EB);
                          badgeIcon = Icons.point_of_sale_rounded;
                          badgeText = 'POS WALK-IN';
                          break;
                        case 'Advance Order':
                          badgeBg = const Color(0xFF8B5CF6).withValues(alpha: 0.1);
                          badgeFg = const Color(0xFF7C3AED);
                          badgeIcon = Icons.schedule_send_rounded;
                          badgeText = 'ADVANCE ORDER';
                          break;
                        case 'Catering Reservation':
                          badgeBg = const Color(0xFFEA580C).withValues(alpha: 0.1);
                          badgeFg = const Color(0xFFC2410C);
                          badgeIcon = Icons.celebration_rounded;
                          badgeText = 'CATERING EVENT';
                          break;
                        case 'Kitchen Request':
                        default:
                          badgeBg = const Color(0xFF10B981).withValues(alpha: 0.1);
                          badgeFg = const Color(0xFF059669);
                          badgeIcon = Icons.restaurant_rounded;
                          badgeText = 'KITCHEN REQ';
                          break;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 10, color: badgeFg),
                            const SizedBox(width: 4),
                            Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: badgeFg,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Deficit Alert Pill if stock is insufficient
                  if (hasDeficit)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black, width: 0.8),
                      ),
                      child: const Text(
                        'DEFICIT RISK',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                      ),
                    ),

                  // Pending pill if unapproved
                  if (isPending)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black, width: 0.8),
                      ),
                      child: const Text(
                        'PENDING',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFD97706)),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Compact Numbers & Deficit Callout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 0.8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPos ? 'POS DEMAND' : 'REQ DEMAND',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black),
                      ),
                      const SizedBox(height: 1),
                      Text('${_formatQty(reqQty)} $unit',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black)),
                    ],
                  ),
                ),
                Container(width: 1, height: 22, color: Colors.black),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CURRENT IN-STOCK',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black)),
                      const SizedBox(height: 1),
                      Text('${_formatQty(currentStock)} $unit',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: currentStock == 0 ? const Color(0xFFEF4444) : Colors.black,
                          )),
                    ],
                  ),
                ),
                Container(width: 1, height: 22, color: Colors.black),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('STOCK STATUS',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black)),
                      const SizedBox(height: 1),
                      Text(
                        hasDeficit ? 'Deficit: -${_formatQty(deficit)} $unit' : 'Covered in stock',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: hasDeficit ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  notes.isNotEmpty ? 'Note: $notes' : 'Requested by $requestedBy',
                  style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (createdAt != null)
                Text(
                  DateFormat('MMM d, h:mm a').format(createdAt),
                  style: const TextStyle(fontSize: 9.5, color: Colors.black, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

