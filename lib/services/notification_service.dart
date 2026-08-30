import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

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

  /// Automatically checks for approved upcoming event reservations:
  /// 1. If it's the day of the event (daysUntil == 0), sends an 'event_today' automatic notification.
  /// 2. If it's within 1 to 5 days ahead (daysUntil between 1 and 5), sends an 'event_reminder' notification.
  static Future<void> checkAndSendUpcomingEventReminders() async {
    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);

      // Query reservations that are menu-based and not marked as Done/Served
      final rows = await _supabase
          .from('reservations')
          .select()
          .eq('is_menu_based', true)
          .neq('kitchen_status', 'Done');

      for (final r in rows) {
        final status = r['status']?.toString().toLowerCase();
        final isApproved = status == 'confirmed' || status == 'completed';
        final ps = r['payment_status']?.toString().toLowerCase();
        final isPaid = ps == 'paid' || ps == 'deposit_paid' || ps == 'fully_paid';
        final eventDateStr = r['event_date']?.toString();

        if (!isApproved || !isPaid || eventDateStr == null) continue;

        try {
          final eventDate = DateTime.parse(eventDateStr);
          final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
          final daysUntil = eventDateOnly.difference(todayDate).inDays;
          final resId = r['id'].toString();

          final formattedDate = DateFormat('MMM d, yyyy').format(eventDate);
          String formattedTime = r['start_time']?.toString() ?? '';
          try {
            final parts = formattedTime.split(':');
            if (parts.length >= 2) {
              final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
              formattedTime = DateFormat('h:mm a').format(dt);
            }
          } catch (_) {}

          final customerName = r['customer_name']?.toString() ?? 'Guest';
          final eventType = r['event_type']?.toString() ?? 'Event';
          final guests = r['number_of_guests']?.toString() ?? '0';

          // 1. Day of Event Automatic Notification (Today)
          if (daysUntil == 0) {
            final existingToday = await _supabase
                .from('notifications')
                .select('id')
                .eq('is_for_admin', true)
                .eq('action_type', 'event_today')
                .eq('reservation_id', resId)
                .limit(1);

            if (existingToday.isEmpty) {
              await sendNotification(
                isForAdmin: true,
                actorName: 'System',
                actionType: 'event_today',
                reservationId: resId,
                eventType: 'TODAY\'S EVENT: $eventType for $customerName ($guests guests) scheduled today at $formattedTime!',
                customerEmail: r['customer_email'],
                eventDate: r['event_date'],
                startTime: r['start_time'],
                guestCount: r['number_of_guests'],
              );
            }
          }

          // 2. Advance Reminder (1 to 5 days before the event)
          if (daysUntil >= 1 && daysUntil <= 5) {
            final existingReminder = await _supabase
                .from('notifications')
                .select('id')
                .eq('is_for_admin', true)
                .eq('action_type', 'event_reminder')
                .eq('reservation_id', resId)
                .limit(1);

            if (existingReminder.isEmpty) {
              final urgency = daysUntil == 1 ? 'Tomorrow' : 'In $daysUntil days';
              await sendNotification(
                isForAdmin: true,
                actorName: 'System',
                actionType: 'event_reminder',
                reservationId: resId,
                eventType: 'Upcoming Event ($urgency): $eventType for $customerName ($guests guests) on $formattedDate at $formattedTime',
                customerEmail: r['customer_email'],
                eventDate: r['event_date'],
                startTime: r['start_time'],
                guestCount: r['number_of_guests'],
              );
            }
          }
        } catch (e) {
          debugPrint('Error parsing event date for reminder: $e');
        }
      }
    } catch (e) {
      debugPrint('Error checking upcoming event reminders: $e');
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
        'created_at': DateTime.now().toUtc().toIso8601String(),
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
        final lower = email.toLowerCase().trim();
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .or('recipient_email.eq.$lower,customer_email.eq.$lower');
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
          .inFilter('id', notificationIds);
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

  /// Get real-time stream of notifications for a customer
  /// Shows all admin actions, system events, and reschedule/payment updates
  static Stream<List<Map<String, dynamic>>> getCustomerAdminNotificationsStream(
    String email,
  ) {
    const relevantActionTypes = [
      // Admin actions on reservations
      'approved',
      'rejected',
      'updated',
      'cancelled',
      'completed',
      'deleted',
      // Payment confirmations
      'paid',
      'deposit_paid',
      'fully_paid',
      'balance_cleared',
      // Reschedule results
      'reschedule_approved',
      'reschedule_rejected',
      // Refund updates
      'refund_approved',
      'refund_processed',
      'refund_rejected',
    ];

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_email', email.toLowerCase())
        .order('created_at', ascending: false)
        .map((notifications) => notifications
            .where((n) => relevantActionTypes.contains(n['action_type']))
            .toList());
  }

  /// Get real-time stream of notifications for admins
  static Stream<List<Map<String, dynamic>>> getAdminNotificationsStream() {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('is_for_admin', true)
        .order('created_at', ascending: false);
  }

  /// Stream for Kitchen Side (POS orders, stock approval & rejection from inventory, advance order tickets, kitchen alerts, event reminders)
  static Stream<List<Map<String, dynamic>>> getKitchenNotificationsStream() {
    return getAdminNotificationsStream().map((list) => list.where((n) {
          final actionType = n['action_type'];
          // Kitchen receives approvals/rejections from inventory, event reminders, day-of-event notifications, and new incoming orders
          if (actionType == 'pos_order' ||
              actionType == 'stock_approved' ||
              actionType == 'stock_rejected' ||
              actionType == 'event_reminder' ||
              actionType == 'event_today') {
            return true;
          }
          if (actionType == 'stock_alert' && n['reservation_id'] == 'Kitchen') {
            return true;
          }
          // Advance order tickets
          if (actionType == 'advance_order_ticket') {
            final eventTypeStr = n['event_type']?.toString() ?? '';
            if (eventTypeStr.contains('Event Reservation')) {
              return true; // Always notify kitchen immediately of event reservations
            }

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
            return true;
          }
          return false;
        }).toList());
  }

  /// Stream for Main Inventory Side (stock requests from Chef, inventory stock alerts)
  static Stream<List<Map<String, dynamic>>> getInventoryNotificationsStream() {
    return getAdminNotificationsStream().map((list) => list.where((n) {
          final actionType = n['action_type'];
          // Inventory receives stock requests submitted by Kitchen and inventory stock alerts
          if (actionType == 'stock_request' ||
              actionType == 'stock_alert') {
            return true;
          }
          return false;
        }).toList());
  }

  /// Stream for Admin Main Page (reservations, bookings, payments only, excluding kitchen/inventory)
  static Stream<List<Map<String, dynamic>>> getAdminOnlyNotificationsStream() {
    return getAdminNotificationsStream().map((list) => list.where((n) {
          final actionType = n['action_type'];
          final kitchenTypes = ['pos_order', 'stock_approved', 'stock_rejected', 'advance_order_ticket', 'event_reminder', 'event_today'];
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
