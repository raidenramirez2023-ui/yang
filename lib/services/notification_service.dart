import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final _supabase = Supabase.instance.client;

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
