import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final _supabase = Supabase.instance.client;
  
  static StreamSubscription? _inventorySubscription;
  static StreamSubscription? _kitchenSubscription;
  static bool _isBulkOperation = false; // Flag to skip stock alerts during bulk operations
  
  // POS order debouncing
  static Timer? _posOrderDebounceTimer;
  static int _pendingPosOrderCount = 0;
  static const Duration _posOrderDebounceDelay = Duration(seconds: 3);

  /// Check if an unread stock alert of this type exists; if not, send a notification
  static Future<void> checkAndSendStockAlert({
    required String itemName,
    required String status,
    required int quantity,
    required String unit,
    required String source,
  }) async {
    // Skip stock alerts during bulk operations
    if (_isBulkOperation) {
      return;
    }
    
    try {
      final eventText = '$itemName is $status! ($quantity $unit left in $source)';
      
      final existing = await _supabase
          .from('notifications')
          .select('id')
          .eq('is_for_admin', true)
          .eq('action_type', 'stock_alert')
          .eq('event_type', eventText)
          .eq('is_read', false)
          .limit(1);
          
      if (existing.isEmpty) {
        await sendNotification(
          isForAdmin: true,
          actorName: 'System',
          actionType: 'stock_alert',
          reservationId: source,
          eventType: eventText,
        );
      }
    } catch (e) {
      debugPrint('Error checking/sending stock alert: $e');
    }
  }

  /// Set bulk operation flag to skip stock monitoring alerts
  static void setBulkOperation(bool isBulk) {
    _isBulkOperation = isBulk;
  }

  /// Handle POS order with debouncing to prevent notification spam
  static Future<void> handlePosOrderNotification({
    required String actorName,
    required String reservationId,
    String? eventType,
  }) async {
    // Increment pending count
    _pendingPosOrderCount++;
    
    // Cancel existing timer if any
    _posOrderDebounceTimer?.cancel();
    
    // Set new timer
    _posOrderDebounceTimer = Timer(_posOrderDebounceDelay, () async {
      // Send consolidated notification
      final count = _pendingPosOrderCount;
      _pendingPosOrderCount = 0;
      
      if (count > 0) {
        await sendNotification(
          isForAdmin: true,
          actorName: actorName,
          actionType: 'pos_order',
          reservationId: reservationId,
          eventType: count == 1 
              ? (eventType ?? 'New POS Order') 
              : '$count new POS orders',
        );
      }
    });
  }

  /// Start monitoring stock levels for kitchen inventory only.
  /// This will automatically trigger notifications when items are low or out of stock in the kitchen.
  static void startStockMonitoring() {
    stopStockMonitoring();

    // Listen to Kitchen Inventory only
    _kitchenSubscription = _supabase
        .from('kitchen_inventory')
        .stream(primaryKey: ['id'])
        .listen((items) {
          for (final item in items) {
            final name = item['name']?.toString() ?? 'Unknown';
            final qty = (item['quantity'] as num?)?.toInt() ?? 0;
            final unit = item['unit']?.toString() ?? 'pcs';
            
            if (qty == 0) {
              checkAndSendStockAlert(
                itemName: name,
                status: 'OUT OF STOCK',
                quantity: qty,
                unit: unit,
                source: 'Kitchen',
              );
            } else if (qty <= 10) {
              checkAndSendStockAlert(
                itemName: name,
                status: 'LOW STOCK',
                quantity: qty,
                unit: unit,
                source: 'Kitchen',
              );
            }
          }
        });
  }

  static void stopStockMonitoring() {
    _inventorySubscription?.cancel();
    _inventorySubscription = null;
    _kitchenSubscription?.cancel();
    _kitchenSubscription = null;
  }

  /// Send a notification to a specific recipient or to all admins
  static Future<void> sendNotification({
    String? recipientEmail,
    bool isForAdmin = false,
    required String actorName,
    required String actionType,
    required String reservationId,
    String? eventType,
    String? eventDate,
    String? customerEmail, // For admin context: which customer this is about
    String? startTime,
    int? guestCount,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'recipient_email': recipientEmail?.toLowerCase(),
        'is_for_admin': isForAdmin,
        'actor_name': actorName,
        'action_type': actionType,
        'reservation_id': reservationId,
        'event_type': eventType,
        'event_date': eventDate,
        'customer_email': customerEmail
            ?.toLowerCase(), // Helps admins know which customer
        'start_time': startTime,
        'guest_count': guestCount,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Mark a single notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications for a recipient or all admins as read
  static Future<void> markAllAsRead(
    String email, {
    bool forAdmin = false,
  }) async {
    try {
      if (forAdmin) {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('is_for_admin', true);
      } else {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('recipient_email', email.toLowerCase());
      }
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  /// Mark specific notifications as read by their IDs
  static Future<void> markVisibleAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .filter('id', 'in', notificationIds);
    } catch (e) {
      debugPrint('Error marking specific notifications as read: $e');
    }
  }

  /// Get real-time stream of notifications for a recipient
  static Stream<List<Map<String, dynamic>>> getNotificationsStream(
    String email,
  ) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_email', email.toLowerCase())
        .order('created_at', ascending: false);
  }

  /// Get real-time stream of ADMIN-RELATED notifications for a customer
  /// Only shows notifications where admin took an action on the customer's reservation
  static Stream<List<Map<String, dynamic>>> getCustomerAdminNotificationsStream(
    String email,
  ) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_email', email.toLowerCase())
        .order('created_at', ascending: false)
        .map((notifications) => notifications.where((n) {
              final isFromAdmin = n['actor_name'] == 'Admin';
              final isValidAction = [
                'approved',
                'rejected',
                'updated',
                'paid',
                'cancelled',
                'completed',
                'deleted',
              ].contains(n['action_type']);
              return isFromAdmin && isValidAction;
            }).toList());
  }

  /// Get real-time stream of notifications for admins
  static Stream<List<Map<String, dynamic>>> getAdminNotificationsStream() {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('is_for_admin', true)
        .order('created_at', ascending: false);
  }

  /// Stream for Kitchen Side (POS orders, stock approval, advance order tickets)
  /// Also includes event reservations only when the event is within 2 days
  static Stream<List<Map<String, dynamic>>> getKitchenNotificationsStream() {
    return getAdminNotificationsStream().map((list) => list.where((n) {
          final actionType = n['action_type'];
          if (actionType == 'pos_order' ||
              actionType == 'stock_approved') {
            return true;
          }
          // Advance order tickets - only if within 2 days
          if (actionType == 'advance_order_ticket') {
            final eventDateStr = n['event_date']?.toString();
            if (eventDateStr != null) {
              try {
                final eventDate = DateTime.parse(eventDateStr);
                final now = DateTime.now();
                final daysUntilEvent = eventDate.difference(now).inDays;
                // Only include if within 2 days (including today and tomorrow)
                return daysUntilEvent >= 0 && daysUntilEvent <= 2;
              } catch (e) {
                // If date parsing fails, don't include the notification
                return false;
              }
            }
            return false;
          }
          // Include event reservations only if within 2 days
          if (actionType == 'created' || actionType == 'updated' || actionType == 'paid' ||
              actionType == 'deposit_paid' || actionType == 'fully_paid' || actionType == 'balance_cleared') {
            final eventDateStr = n['event_date']?.toString();
            if (eventDateStr != null) {
              try {
                final eventDate = DateTime.parse(eventDateStr);
                final now = DateTime.now();
                final daysUntilEvent = eventDate.difference(now).inDays;
                // Only include if event is within 2 days (including today and tomorrow)
                return daysUntilEvent >= 0 && daysUntilEvent <= 2;
              } catch (e) {
                // If date parsing fails, don't include the notification
                return false;
              }
            }
          }
          return false;
        }).toList());
  }

  /// Stream for Main Inventory Side (stock requests, inventory stock alerts)
  static Stream<List<Map<String, dynamic>>> getInventoryNotificationsStream() {
    return getAdminNotificationsStream().map((list) => list.where((n) {
          final actionType = n['action_type'];
          if (actionType == 'stock_request') {
            return true;
          }
          if (actionType == 'stock_alert' && n['reservation_id'] == 'Main Inventory') {
            return true;
          }
          return false;
        }).toList());
  }

  /// Stream for Admin Main Page (reservations, bookings, payments only, excluding kitchen/inventory)
  static Stream<List<Map<String, dynamic>>> getAdminOnlyNotificationsStream() {
    return getAdminNotificationsStream().map((list) => list.where((n) {
          final actionType = n['action_type'];
          final kitchenTypes = ['pos_order', 'stock_approved', 'advance_order_ticket'];
          final inventoryTypes = ['stock_request'];
          if (kitchenTypes.contains(actionType) || inventoryTypes.contains(actionType)) {
            return false;
          }
          if (actionType == 'stock_alert') {
            return false; // Exclude stock alerts from Admin Main page
          }
          return true;
        }).toList());
  }
}
