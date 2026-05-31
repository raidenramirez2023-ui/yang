import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final _supabase = Supabase.instance.client;
  
  static StreamSubscription? _inventorySubscription;
  static StreamSubscription? _kitchenSubscription;

  /// Check if an unread stock alert of this type exists; if not, send a notification
  static Future<void> checkAndSendStockAlert({
    required String itemName,
    required String status,
    required int quantity,
    required String unit,
    required String source,
  }) async {
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

  /// Start monitoring stock levels for both main inventory and kitchen inventory.
  /// This will automatically trigger notifications when items are low or out of stock.
  static void startStockMonitoring() {
    stopStockMonitoring();

    // Listen to Main Inventory
    _inventorySubscription = _supabase
        .from('inventory')
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
                source: 'Main Inventory',
              );
            } else if (qty <= 10) {
              checkAndSendStockAlert(
                itemName: name,
                status: 'LOW STOCK',
                quantity: qty,
                unit: unit,
                source: 'Main Inventory',
              );
            }
          }
        });

    // Listen to Kitchen Inventory
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
}
