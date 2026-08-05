import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/app_settings_service.dart';
import 'package:yang_chow/services/email_notification_service.dart';
import 'package:yang_chow/services/notification_service.dart';


/// Service to manage all refund operations across POS, Reservations, and Advance Orders.
class RefundService {
  static final RefundService _instance = RefundService._internal();
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final AppSettingsService _appSettings = AppSettingsService();
  static final EmailNotificationService _emailService =
      EmailNotificationService();

  RefundService._internal();

  factory RefundService() {
    return _instance;
  }

  // ══════════════════════════════════════════════════════════
  //  PASSCODE VERIFICATION
  // ══════════════════════════════════════════════════════════

  /// Verify the admin passcode for POS refunds.
  /// Returns true if the passcode matches the one stored in app_settings.
  Future<bool> verifyAdminPasscode(String enteredPasscode) async {
    try {
      // Try fetching the latest from database first
      final response = await _supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'refund_passcode')
          .maybeSingle();

      final storedPasscode = response?['setting_value'] as String? ??
          _appSettings.getSetting<String>('refund_passcode') ??
          '1234';

      return enteredPasscode == storedPasscode;
    } catch (e) {
      debugPrint('Error verifying passcode: $e');
      // Fallback to cached settings
      final cached =
          _appSettings.getSetting<String>('refund_passcode') ?? '1234';
      return enteredPasscode == cached;
    }
  }

  /// Update the admin refund passcode.
  Future<bool> updateAdminPasscode(String newPasscode) async {
    try {
      await _appSettings.updateSetting('refund_passcode', newPasscode);
      return true;
    } catch (e) {
      debugPrint('Error updating passcode: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  REFUND AMOUNT CALCULATION
  // ══════════════════════════════════════════════════════════

  /// Calculate refund amount based on the cancellation policy.
  ///   • 4+ days before event → 100% refund
  ///   • 1–3 days before OR on the event day → 50% refund
  ///   • After event date has passed → 0% (no refund)
  double calculateRefundAmount({
    required String eventDate,
    required double paymentAmount,
  }) {
    try {
      final event = DateTime.parse(eventDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final eventDay = DateTime(event.year, event.month, event.day);
      final daysUntilEvent = eventDay.difference(today).inDays;

      final refundPolicyDays = _appSettings.getRefundPolicyDays();
      final refundPercentageWithinWindow =
          _appSettings.getRefundPercentageWithinWindow();

      // 100% refund if cancelled 4+ days before (or refundPolicyDays+)
      if (daysUntilEvent >= refundPolicyDays) {
        return paymentAmount;
      }

      // 50% refund if 0-3 days before (including event day)
      if (daysUntilEvent >= 0) {
        return paymentAmount * (refundPercentageWithinWindow / 100);
      }

      // No refund if event date already passed
      return 0.0;
    } catch (e) {
      debugPrint('Error calculating refund: $e');
      return 0.0;
    }
  }

  /// Get a human-readable explanation of the refund policy for the given event date.
  Map<String, dynamic> getRefundPolicyExplanation({
    required String eventDate,
    required double paymentAmount,
  }) {
    try {
      final event = DateTime.parse(eventDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final eventDay = DateTime(event.year, event.month, event.day);
      final daysUntilEvent = eventDay.difference(today).inDays;

      final refundPolicyDays = _appSettings.getRefundPolicyDays();
      final refundPercentage = _appSettings.getRefundPercentageWithinWindow();
      final refundAmount = calculateRefundAmount(
        eventDate: eventDate,
        paymentAmount: paymentAmount,
      );

      String explanation;
      int percentage;

      if (daysUntilEvent >= refundPolicyDays) {
        percentage = 100;
        explanation =
            'Your event is $daysUntilEvent days away. Since you\'re cancelling $refundPolicyDays+ days before, you\'re eligible for a full refund.';
      } else if (daysUntilEvent >= 0) {
        percentage = refundPercentage;
        if (daysUntilEvent == 0) {
          explanation =
              'Your event is today. You\'re eligible for a $refundPercentage% partial refund.';
        } else {
          explanation =
              'Your event is in $daysUntilEvent day${daysUntilEvent == 1 ? '' : 's'}. Since you\'re cancelling within the $refundPolicyDays-day window, you\'re eligible for a $refundPercentage% refund.';
        }
      } else {
        percentage = 0;
        explanation =
            'Your event date has already passed. Unfortunately, no refund is available.';
      }

      return {
        'refund_amount': refundAmount,
        'percentage': percentage,
        'explanation': explanation,
        'days_until_event': daysUntilEvent,
        'payment_amount': paymentAmount,
      };
    } catch (e) {
      debugPrint('Error getting refund explanation: $e');
      return {
        'refund_amount': 0.0,
        'percentage': 0,
        'explanation': 'Unable to calculate refund. Please contact admin.',
        'days_until_event': -1,
        'payment_amount': paymentAmount,
      };
    }
  }

  // ══════════════════════════════════════════════════════════
  //  POS ITEM REFUND (Immediate — passcode verified by caller)
  // ══════════════════════════════════════════════════════════

  /// Process an immediate POS item refund.
  /// Called AFTER the admin passcode has been verified.
  /// Creates a refund record with status 'completed' (no approval queue for POS).
  Future<Map<String, dynamic>> processImmediatePOSRefund({
    required String orderId,
    required String transactionId,
    required String customerName,
    required List<Map<String, dynamic>> refundedItems,
    required double refundAmount,
    required double originalAmount,
    required String reason,
    required String staffEmail,
  }) async {
    try {
      // Validate: only same-day orders
      final order = await _supabase
          .from('orders')
          .select('created_at, refund_status, total_amount')
          .eq('id', orderId)
          .single();

      final orderDate = DateTime.parse(order['created_at']);
      final now = DateTime.now();
      final isSameDay = orderDate.year == now.year &&
          orderDate.month == now.month &&
          orderDate.day == now.day;

      if (!isSameDay) {
        return {
          'success': false,
          'error': 'POS refunds can only be processed for same-day orders.',
        };
      }

      // Check if already fully refunded
      if (order['refund_status'] == 'full_refund') {
        return {
          'success': false,
          'error': 'This order has already been fully refunded.',
        };
      }

      // Determine refund type
      final totalAmount =
          (order['total_amount'] as num?)?.toDouble() ?? originalAmount;
      final isFullRefund = (refundAmount >= totalAmount);
      final refundType = isFullRefund ? 'full' : 'item';

      // Create the refund record (immediately completed)
      final refundRecord = await _supabase
          .from('refunds')
          .insert({
            'source_table': 'orders',
            'source_id': orderId,
            'transaction_id': transactionId,
            'customer_name': customerName,
            'refund_type': refundType,
            'refund_method': 'cash',
            'refund_reason': reason,
            'refund_amount': refundAmount,
            'original_amount': originalAmount,
            'refunded_items': refundedItems,
            'status': 'completed',
            'requested_by': staffEmail,
            'reviewed_by': staffEmail,
            'reviewed_at': now.toUtc().toIso8601String(),
            'completed_at': now.toUtc().toIso8601String(),
            'admin_notes': 'POS refund - verified via admin passcode',
          })
          .select()
          .single();

      // Update the order's refund_status, payment_status, and kitchen_status
      await _supabase.from('orders').update({
        'refund_status': isFullRefund ? 'full_refund' : 'partial_refund',
        'payment_status': isFullRefund ? 'refunded' : 'partially_refunded',
        'kitchen_status': 'Done',
      }).eq('id', orderId);

      // Send admin notification
      await NotificationService.sendNotification(
        isForAdmin: true,
        actorName: 'POS System',
        actionType: 'refund_processed',
        reservationId: orderId,
        eventType:
            'POS Refund: ₱${refundAmount.toStringAsFixed(2)} for order #$transactionId ($customerName)',
      );

      return {
        'success': true,
        'refund': refundRecord,
        'refund_type': refundType,
      };
    } catch (e) {
      debugPrint('Error processing POS refund: $e');
      return {
        'success': false,
        'error': 'Failed to process refund: $e',
      };
    }
  }

  // ══════════════════════════════════════════════════════════
  //  RESERVATION / ADVANCE ORDER REFUND REQUEST
  // ══════════════════════════════════════════════════════════

  /// Request a refund for a cancelled reservation.
  /// Creates a refund record with status 'pending' for admin review.
  Future<Map<String, dynamic>> requestReservationRefund({
    required String reservationId,
    required String customerEmail,
    required String customerName,
    required String eventType,
    required String eventDate,
    required String cancellationReason,
    required double paymentAmount,
    String? paymongoPaymentId,
  }) async {
    try {
      final refundAmount = calculateRefundAmount(
        eventDate: eventDate,
        paymentAmount: paymentAmount,
      );

      if (refundAmount <= 0) {
        return {
          'success': true,
          'refund_amount': 0.0,
          'message': 'No refund available based on the refund policy.',
        };
      }

      // Determine refund method based on original payment
      final refundMethod =
          (paymongoPaymentId != null && paymongoPaymentId.isNotEmpty)
              ? 'paymongo'
              : 'cash';

      // Determine refund type
      final isFullRefund = (refundAmount >= paymentAmount);
      final refundType = isFullRefund ? 'full' : 'partial';

      // Create refund record
      final refundRecord = await _supabase
          .from('refunds')
          .insert({
            'source_table': 'reservations',
            'source_id': reservationId,
            'customer_email': customerEmail,
            'customer_name': customerName,
            'refund_type': refundType,
            'refund_method': refundMethod,
            'refund_reason': cancellationReason,
            'refund_amount': refundAmount,
            'original_amount': paymentAmount,
            'paymongo_payment_id': paymongoPaymentId,
            'status': 'pending',
            'requested_by': customerEmail,
          })
          .select()
          .single();

      // Update the reservation with refund info
      await _supabase.from('reservations').update({
        'refund_amount': refundAmount,
        'refund_status': 'pending',
      }).eq('id', reservationId);

      // Send admin notification
      await NotificationService.sendNotification(
        isForAdmin: true,
        actorName: customerName,
        actionType: 'refund_request',
        reservationId: reservationId,
        eventType:
            'Refund Request: ₱${refundAmount.toStringAsFixed(2)} for $eventType on $eventDate',
      );

      return {
        'success': true,
        'refund': refundRecord,
        'refund_amount': refundAmount,
      };
    } catch (e) {
      debugPrint('Error requesting reservation refund: $e');
      return {
        'success': false,
        'error': 'Failed to request refund: $e',
      };
    }
  }

  /// Request a refund for a cancelled advance order.
  /// Creates a refund record with status 'pending' for admin review.
  Future<Map<String, dynamic>> requestAdvanceOrderRefund({
    required String orderId,
    required String customerEmail,
    required String customerName,
    required String orderType,
    required String orderDate,
    required String cancellationReason,
    required double paymentAmount,
    String? paymongoPaymentId,
  }) async {
    try {
      final refundAmount = calculateRefundAmount(
        eventDate: orderDate,
        paymentAmount: paymentAmount,
      );

      if (refundAmount <= 0) {
        return {
          'success': true,
          'refund_amount': 0.0,
          'message': 'No refund available based on the refund policy.',
        };
      }

      final refundMethod =
          (paymongoPaymentId != null && paymongoPaymentId.isNotEmpty)
              ? 'paymongo'
              : 'cash';

      final isFullRefund = (refundAmount >= paymentAmount);
      final refundType = isFullRefund ? 'full' : 'partial';

      // Create refund record
      final refundRecord = await _supabase
          .from('refunds')
          .insert({
            'source_table': 'advance_orders',
            'source_id': orderId,
            'customer_email': customerEmail,
            'customer_name': customerName,
            'refund_type': refundType,
            'refund_method': refundMethod,
            'refund_reason': cancellationReason,
            'refund_amount': refundAmount,
            'original_amount': paymentAmount,
            'paymongo_payment_id': paymongoPaymentId,
            'status': 'pending',
            'requested_by': customerEmail,
          })
          .select()
          .single();

      // Update the advance order with refund info
      await _supabase.from('advance_orders').update({
        'refund_amount': refundAmount,
      }).eq('id', orderId);

      // Send admin notification
      await NotificationService.sendNotification(
        isForAdmin: true,
        actorName: customerName,
        actionType: 'refund_request',
        reservationId: orderId,
        eventType:
            'Refund Request: ₱${refundAmount.toStringAsFixed(2)} for Advance Order ($orderType) on $orderDate',
      );

      return {
        'success': true,
        'refund': refundRecord,
        'refund_amount': refundAmount,
      };
    } catch (e) {
      debugPrint('Error requesting advance order refund: $e');
      return {
        'success': false,
        'error': 'Failed to request refund: $e',
      };
    }
  }

  // ══════════════════════════════════════════════════════════
  //  ADMIN: APPROVE / REJECT / COMPLETE REFUNDS
  // ══════════════════════════════════════════════════════════

  /// Approve a pending refund request.
  Future<bool> approveRefund({
    required String refundId,
    required String adminEmail,
    String? adminNotes,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await _supabase.from('refunds').update({
        'status': 'approved',
        'reviewed_by': adminEmail,
        'reviewed_at': now,
        'admin_notes': adminNotes,
      }).eq('id', refundId);

      // Get refund details for notification
      final refund = await _supabase
          .from('refunds')
          .select()
          .eq('id', refundId)
          .single();

      // Update source table refund_status
      final sourceTable = refund['source_table'] as String;
      final sourceId = refund['source_id'] as String;
      if (sourceTable == 'reservations') {
        await _supabase.from('reservations').update({
          'refund_status': 'pending', // Still pending until completed
        }).eq('id', sourceId);
      }

      // Send email notification to customer
      if (refund['customer_email'] != null) {
        await _emailService.sendRefundApproved(
          customerEmail: refund['customer_email'],
          customerName: refund['customer_name'] ?? 'Customer',
          refundAmount: (refund['refund_amount'] as num).toDouble(),
          refundMethod: refund['refund_method'] ?? 'cash',
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error approving refund: $e');
      return false;
    }
  }

  /// Reject a pending refund request.
  Future<bool> rejectRefund({
    required String refundId,
    required String adminEmail,
    required String rejectionReason,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // Get refund details first
      final refund = await _supabase
          .from('refunds')
          .select()
          .eq('id', refundId)
          .single();

      await _supabase.from('refunds').update({
        'status': 'rejected',
        'reviewed_by': adminEmail,
        'reviewed_at': now,
        'admin_notes': rejectionReason,
      }).eq('id', refundId);

      // Update source table
      final sourceTable = refund['source_table'] as String;
      final sourceId = refund['source_id'] as String;
      if (sourceTable == 'reservations') {
        await _supabase.from('reservations').update({
          'refund_status': 'failed',
        }).eq('id', sourceId);
      }

      // Send rejection email
      if (refund['customer_email'] != null) {
        await _emailService.sendRefundRejected(
          customerEmail: refund['customer_email'],
          customerName: refund['customer_name'] ?? 'Customer',
          refundAmount: (refund['refund_amount'] as num).toDouble(),
          rejectionReason: rejectionReason,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error rejecting refund: $e');
      return false;
    }
  }

  /// Process a PayMongo refund via the Supabase RPC function.
  /// Returns the PayMongo refund ID on success.
  Future<Map<String, dynamic>> processPayMongoRefund({
    required String refundId,
  }) async {
    try {
      // Get the refund record
      final refund = await _supabase
          .from('refunds')
          .select()
          .eq('id', refundId)
          .single();

      final paymentId = refund['paymongo_payment_id'] as String?;
      if (paymentId == null || paymentId.isEmpty) {
        return {
          'success': false,
          'error':
              'No PayMongo payment ID found. This transaction may have been paid with cash.',
        };
      }

      final amountInCentavos =
          ((refund['refund_amount'] as num).toDouble() * 100).round();

      // Call the Supabase RPC function
      final response = await _supabase.rpc('process_paymongo_refund', params: {
        'p_payment_id': paymentId,
        'p_amount': amountInCentavos,
        'p_reason': 'others',
        'p_notes':
            'Refund for ${refund['source_table']} - ${refund['refund_reason']}',
      });

      // Extract refund ID from response
      final paymongoRefundId =
          response?['data']?['id'] as String? ?? 'unknown';

      // Update the refund record with PayMongo details
      await _supabase.from('refunds').update({
        'paymongo_refund_id': paymongoRefundId,
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', refundId);

      // Update source table
      await _markSourceAsRefunded(refund);

      // Send completion email
      if (refund['customer_email'] != null) {
        await _emailService.sendRefundCompleted(
          customerEmail: refund['customer_email'],
          customerName: refund['customer_name'] ?? 'Customer',
          refundAmount: (refund['refund_amount'] as num).toDouble(),
          refundMethod: 'paymongo',
        );
      }

      return {
        'success': true,
        'paymongo_refund_id': paymongoRefundId,
      };
    } catch (e) {
      debugPrint('Error processing PayMongo refund: $e');
      return {
        'success': false,
        'error': 'PayMongo refund failed: $e',
      };
    }
  }

  /// Mark a refund as completed (for cash/manual refunds).
  /// Called when admin confirms cash was physically returned.
  Future<bool> completeManualRefund({
    required String refundId,
    required String adminEmail,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // Get the refund record
      final refund = await _supabase
          .from('refunds')
          .select()
          .eq('id', refundId)
          .single();

      await _supabase.from('refunds').update({
        'status': 'completed',
        'completed_at': now,
        'reviewed_by': refund['reviewed_by'] ?? adminEmail,
        'reviewed_at': refund['reviewed_at'] ?? now,
      }).eq('id', refundId);

      // Update source table
      await _markSourceAsRefunded(refund);

      // Send completion email
      if (refund['customer_email'] != null) {
        await _emailService.sendRefundCompleted(
          customerEmail: refund['customer_email'],
          customerName: refund['customer_name'] ?? 'Customer',
          refundAmount: (refund['refund_amount'] as num).toDouble(),
          refundMethod: 'cash',
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error completing manual refund: $e');
      return false;
    }
  }

  /// Update the source table (orders/reservations/advance_orders) to reflect
  /// that the refund has been completed.
  Future<void> _markSourceAsRefunded(Map<String, dynamic> refund) async {
    try {
      final sourceTable = refund['source_table'] as String;
      final sourceId = refund['source_id'] as String;

      if (sourceTable == 'orders') {
        final refundType = refund['refund_type'] as String;
        await _supabase.from('orders').update({
          'refund_status':
              refundType == 'full' ? 'full_refund' : 'partial_refund',
          'payment_status': refundType == 'full' ? 'refunded' : 'partially_refunded',
          'kitchen_status': 'Done',
        }).eq('id', sourceId);
      } else if (sourceTable == 'reservations') {
        await _supabase.from('reservations').update({
          'refund_status': 'completed',
          'status': 'refunded',
          'kitchen_status': 'Done',
        }).eq('id', sourceId);
      } else if (sourceTable == 'advance_orders') {
        await _supabase.from('advance_orders').update({
          'refund_amount': (refund['refund_amount'] as num).toDouble(),
          'status': 'cancelled',
        }).eq('id', sourceId);
      }
    } catch (e) {
      debugPrint('Error marking source as refunded: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  QUERIES
  // ══════════════════════════════════════════════════════════

  /// Get all pending refund requests (for admin Refund Management page).
  Future<List<Map<String, dynamic>>> getPendingRefunds() async {
    try {
      final response = await _supabase
          .from('refunds')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching pending refunds: $e');
      return [];
    }
  }

  /// Get the count of pending refunds (for badge display).
  Future<int> getPendingRefundCount() async {
    try {
      final response = await _supabase
          .from('refunds')
          .select('id')
          .eq('status', 'pending');

      return response.length;
    } catch (e) {
      debugPrint('Error counting pending refunds: $e');
      return 0;
    }
  }

  /// Get all refunds with optional filters.
  Future<List<Map<String, dynamic>>> getRefunds({
    String? status,
    String? sourceTable,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _supabase.from('refunds').select();

      if (status != null && status.isNotEmpty && status != 'all') {
        query = query.eq('status', status);
      }

      if (sourceTable != null && sourceTable.isNotEmpty) {
        query = query.eq('source_table', sourceTable);
      }

      if (fromDate != null) {
        query = query.gte(
            'created_at', fromDate.toUtc().toIso8601String());
      }

      if (toDate != null) {
        final endOfDay =
            DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
        query = query.lte(
            'created_at', endOfDay.toUtc().toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching refunds: $e');
      return [];
    }
  }

  /// Get refunds associated with a specific source record.
  Future<List<Map<String, dynamic>>> getRefundsBySource({
    required String sourceTable,
    required String sourceId,
  }) async {
    try {
      final response = await _supabase
          .from('refunds')
          .select()
          .eq('source_table', sourceTable)
          .eq('source_id', sourceId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching refunds by source: $e');
      return [];
    }
  }

  /// Get a single refund by ID.
  Future<Map<String, dynamic>?> getRefundById(String refundId) async {
    try {
      final response = await _supabase
          .from('refunds')
          .select()
          .eq('id', refundId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching refund: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  SALES REPORT HELPERS
  // ══════════════════════════════════════════════════════════

  /// Get total completed refunds for a date range (for sales deduction).
  Future<double> getCompletedRefundTotal({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _supabase
          .from('refunds')
          .select('refund_amount')
          .eq('status', 'completed');

      if (fromDate != null) {
        query = query.gte(
            'completed_at', fromDate.toUtc().toIso8601String());
      }

      if (toDate != null) {
        final endOfDay =
            DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
        query = query.lte(
            'completed_at', endOfDay.toUtc().toIso8601String());
      }

      final response = await query;

      double total = 0;
      for (final record in response) {
        total += (record['refund_amount'] as num?)?.toDouble() ?? 0;
      }

      return total;
    } catch (e) {
      debugPrint('Error getting refund total: $e');
      return 0;
    }
  }

  /// Get refund statistics for a period (for sales report cards).
  Future<Map<String, dynamic>> getRefundStatsForPeriod({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final from = fromDate.toUtc().toIso8601String();
      final to = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59)
          .toUtc()
          .toIso8601String();

      final response = await _supabase
          .from('refunds')
          .select()
          .eq('status', 'completed')
          .gte('completed_at', from)
          .lte('completed_at', to);

      double totalAmount = 0;
      int totalCount = 0;
      int posRefunds = 0;
      int reservationRefunds = 0;
      int advanceOrderRefunds = 0;

      for (final record in response) {
        totalAmount += (record['refund_amount'] as num?)?.toDouble() ?? 0;
        totalCount++;

        switch (record['source_table']) {
          case 'orders':
            posRefunds++;
            break;
          case 'reservations':
            reservationRefunds++;
            break;
          case 'advance_orders':
            advanceOrderRefunds++;
            break;
        }
      }

      return {
        'total_amount': totalAmount,
        'total_count': totalCount,
        'pos_refunds': posRefunds,
        'reservation_refunds': reservationRefunds,
        'advance_order_refunds': advanceOrderRefunds,
      };
    } catch (e) {
      debugPrint('Error getting refund stats: $e');
      return {
        'total_amount': 0.0,
        'total_count': 0,
        'pos_refunds': 0,
        'reservation_refunds': 0,
        'advance_order_refunds': 0,
      };
    }
  }

  /// Stream for real-time refund updates (for admin page).
  Stream<List<Map<String, dynamic>>> refundsStream() {
    return _supabase
        .from('refunds')
        .stream(primaryKey: ['id']).order('created_at', ascending: false);
  }
}
