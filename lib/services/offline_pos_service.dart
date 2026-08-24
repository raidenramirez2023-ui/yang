import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item.dart';
import 'recipe_service.dart';
import 'notification_service.dart';

class SyncResult {
  final int syncedCount;
  final int failedCount;
  final String? errorMessage;

  const SyncResult({
    required this.syncedCount,
    required this.failedCount,
    this.errorMessage,
  });
}

class OfflinePosService {
  static final OfflinePosService _instance = OfflinePosService._internal();
  factory OfflinePosService() => _instance;
  OfflinePosService._internal();

  static const String _keyMenuCache = 'yang_offline_menu_cache';
  static const String _keyInventoryCache = 'yang_offline_inventory_cache';
  static const String _keyOrdersQueue = 'yang_offline_orders_queue';
  static const String _keyOfflineCounter = 'yang_offline_tx_counter';

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<int> pendingOrdersCountNotifier = ValueNotifier<int>(0);

  Timer? _heartbeatTimer;
  bool _isSyncing = false;

  /// Initialize service, load pending count, and start connectivity monitoring
  Future<void> init() async {
    await updatePendingCount();
    await checkConnectivity();

    // Heartbeat connectivity check & auto-sync every 15 seconds
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final wasOffline = !isOnlineNotifier.value;
      final onlineNow = await checkConnectivity();
      
      // If we just reconnected and have pending orders, auto-sync!
      if (wasOffline && onlineNow && pendingOrdersCountNotifier.value > 0) {
        debugPrint('[OfflinePos] Internet connection restored. Auto-syncing pending orders...');
        await syncPendingOrders();
      }
    });
  }

  void dispose() {
    _heartbeatTimer?.cancel();
  }

  /// Actively test if Supabase is reachable
  Future<bool> checkConnectivity() async {
    try {
      final supabase = Supabase.instance.client;
      // Quick lightweight query with a short timeout
      await supabase
          .from('menu_items')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 4));

      if (!isOnlineNotifier.value) {
        isOnlineNotifier.value = true;
      }
      return true;
    } catch (e) {
      if (isOnlineNotifier.value) {
        isOnlineNotifier.value = false;
      }
      return false;
    }
  }

  // ==========================================
  // MENU CACHING
  // ==========================================

  /// Save menu items to local cache for offline usage
  Future<void> cacheMenuItems(List<Map<String, dynamic>> rawRows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(rawRows);
      await prefs.setString(_keyMenuCache, jsonStr);
      debugPrint('[OfflinePos] Cached ${rawRows.length} menu items locally.');
    } catch (e) {
      debugPrint('[OfflinePos] Failed to cache menu items: $e');
    }
  }

  /// Get cached menu grouped by category
  Future<Map<String, List<MenuItem>>> getCachedMenu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyMenuCache);
      if (jsonStr == null || jsonStr.isEmpty) return {};

      final List<dynamic> list = jsonDecode(jsonStr);
      final Map<String, List<MenuItem>> menu = {};

      for (final raw in list) {
        if (raw is Map<String, dynamic>) {
          final item = MenuItem.fromJson(raw);
          final cat = item.category;
          menu.putIfAbsent(cat, () => []).add(item);
        }
      }
      return menu;
    } catch (e) {
      debugPrint('[OfflinePos] Failed to read cached menu: $e');
      return {};
    }
  }

  // ==========================================
  // INVENTORY CACHING
  // ==========================================

  /// Save kitchen inventory items to local cache
  Future<void> cacheInventory(List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(items);
      await prefs.setString(_keyInventoryCache, jsonStr);
    } catch (e) {
      debugPrint('[OfflinePos] Failed to cache inventory: $e');
    }
  }

  /// Get cached inventory items
  Future<List<Map<String, dynamic>>> getCachedInventory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyInventoryCache);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('[OfflinePos] Failed to read cached inventory: $e');
      return [];
    }
  }

  // ==========================================
  // TRANSACTION NUMBER GENERATION
  // ==========================================

  /// Generate next sequential offline transaction ID (e.g., OFF-001)
  Future<String> generateOfflineTransactionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int current = prefs.getInt(_keyOfflineCounter) ?? 0;
      current += 1;
      await prefs.setInt(_keyOfflineCounter, current);
      return 'OFF-${current.toString().padLeft(3, '0')}';
    } catch (e) {
      return 'OFF-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }
  }

  // ==========================================
  // OFFLINE ORDER QUEUE (OUTBOX PATTERN)
  // ==========================================

  /// Save an order to the local queue when offline or if direct insert fails
  Future<void> enqueueOrder({
    required String transactionId,
    required double total,
    required String customerName,
    required String customerAddress,
    required String note,
    required String paymentMethod,
    required double amountPaid,
    required double changeDue,
    required int guestCount,
    required String tableNumber,
    required double discountAmount,
    required String discountLabel,
    required String discountName,
    required String discountAddress,
    required String staffEmail,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getString(_keyOrdersQueue);
      List<dynamic> queue = [];
      if (rawQueue != null && rawQueue.isNotEmpty) {
        queue = jsonDecode(rawQueue) as List<dynamic>;
      }

      final orderPayload = {
        'offline_id': 'offline_${DateTime.now().millisecondsSinceEpoch}_$transactionId',
        'transaction_id': transactionId,
        'customer_name': customerName.isNotEmpty ? customerName : 'Guest',
        'customer_address': customerAddress.isNotEmpty ? customerAddress : null,
        'note': note,
        'kitchen_status': 'Pending',
        'total_amount': total,
        'payment_method': paymentMethod,
        'payment_status': amountPaid >= total ? 'paid' : 'partially_paid',
        'amount_paid': amountPaid,
        'change_due': changeDue,
        'item_count': items.fold(0, (s, c) => s + (c['quantity'] as int? ?? 1)),
        'staff_email': staffEmail,
        'table_number': tableNumber.isNotEmpty ? tableNumber : null,
        'number_of_guests': guestCount,
        'discount_amount': discountAmount,
        'discount_label': discountLabel,
        'discount_name': discountName,
        'discount_address': discountAddress,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'items': items,
      };

      queue.add(orderPayload);
      await prefs.setString(_keyOrdersQueue, jsonEncode(queue));
      await updatePendingCount();
      debugPrint('[OfflinePos] Enqueued offline order #$transactionId. Total pending: ${queue.length}');
    } catch (e) {
      debugPrint('[OfflinePos] Error enqueuing offline order: $e');
    }
  }

  /// Get list of pending offline orders
  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getString(_keyOrdersQueue);
      if (rawQueue == null || rawQueue.isEmpty) return [];

      final List<dynamic> list = jsonDecode(rawQueue);
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('[OfflinePos] Error reading pending orders: $e');
      return [];
    }
  }

  /// Refresh pending count notifier
  Future<void> updatePendingCount() async {
    final orders = await getPendingOrders();
    pendingOrdersCountNotifier.value = orders.length;
  }

  // ==========================================
  // SYNC ENGINE
  // ==========================================

  /// Sync all pending offline orders to Supabase
  Future<SyncResult> syncPendingOrders() async {
    if (_isSyncing) {
      return const SyncResult(syncedCount: 0, failedCount: 0, errorMessage: 'Sync already in progress');
    }

    _isSyncing = true;
    int synced = 0;
    int failed = 0;
    String? lastError;

    try {
      final isOnline = await checkConnectivity();
      if (!isOnline) {
        _isSyncing = false;
        return const SyncResult(syncedCount: 0, failedCount: 0, errorMessage: 'No internet connection');
      }

      final prefs = await SharedPreferences.getInstance();
      final pendingOrders = await getPendingOrders();

      if (pendingOrders.isEmpty) {
        _isSyncing = false;
        return const SyncResult(syncedCount: 0, failedCount: 0);
      }

      final supabase = Supabase.instance.client;
      final List<Map<String, dynamic>> remainingOrders = [];

      for (final order in pendingOrders) {
        try {
          final items = (order['items'] as List<dynamic>?) ?? [];

          // 1. Insert order header
          final orderRes = await supabase
              .from('orders')
              .insert({
                'transaction_id': order['transaction_id'],
                'customer_name': order['customer_name'],
                'customer_address': order['customer_address'],
                'note': order['note'],
                'kitchen_status': order['kitchen_status'] ?? 'Pending',
                'total_amount': order['total_amount'],
                'payment_method': order['payment_method'],
                'payment_status': order['payment_status'],
                'amount_paid': order['amount_paid'],
                'change_due': order['change_due'],
                'item_count': order['item_count'],
                'staff_email': order['staff_email'],
                'table_number': order['table_number'],
                'number_of_guests': order['number_of_guests'],
                'discount_amount': order['discount_amount'],
                'discount_label': order['discount_label'],
                'discount_name': order['discount_name'],
                'discount_address': order['discount_address'],
                'created_at': order['created_at'],
              })
              .select('id')
              .single();

          final orderId = orderRes['id'].toString();

          // 2. Insert order items
          if (items.isNotEmpty) {
            final itemRows = items.map((c) => {
              'order_id': orderId,
              'item_name': c['item_name'],
              'quantity': c['quantity'],
              'unit_price': c['unit_price'],
              'subtotal': c['subtotal'] ?? ((c['unit_price'] as num) * (c['quantity'] as num)),
            }).toList();

            await supabase.from('order_items').insert(itemRows);

            // 3. Deduct inventory stocks on cloud
            for (final it in items) {
              final itemName = it['item_name']?.toString() ?? '';
              final qty = (it['quantity'] as num?)?.toInt() ?? 1;
              if (itemName.isNotEmpty) {
                try {
                  await RecipeService().deductIngredientsFromInventory(itemName, qty);
                } catch (e) {
                  debugPrint('[OfflinePos] Inventory deduction warning for $itemName: $e');
                }
              }
            }
          }

          // 4. Send notification
          try {
            final staffEmail = order['staff_email']?.toString() ?? 'staff';
            final txId = order['transaction_id']?.toString() ?? '';
            await NotificationService.handlePosOrderNotification(
              actorName: staffEmail.split('@')[0],
              reservationId: orderId,
              eventType: 'Synced POS Order ($txId)',
            );
          } catch (_) {}

          synced++;
        } catch (e) {
          debugPrint('[OfflinePos] Failed to sync order ${order['transaction_id']}: $e');
          lastError = e.toString();
          failed++;
          remainingOrders.add(order);
        }
      }

      // Save remaining unsynced orders back
      await prefs.setString(_keyOrdersQueue, jsonEncode(remainingOrders));
      await updatePendingCount();

      debugPrint('[OfflinePos] Sync completed: $synced synced, $failed failed.');
      return SyncResult(syncedCount: synced, failedCount: failed, errorMessage: lastError);
    } catch (e) {
      debugPrint('[OfflinePos] Unexpected sync error: $e');
      return SyncResult(syncedCount: synced, failedCount: failed, errorMessage: e.toString());
    } finally {
      _isSyncing = false;
    }
  }
}
