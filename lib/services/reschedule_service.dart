import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:yang_chow/services/audit_log_service.dart';

/// Service to manage reservation reschedule requests and approval workflow.
class RescheduleService {
  static final RescheduleService _instance = RescheduleService._internal();
  static final SupabaseClient _supabase = Supabase.instance.client;

  RescheduleService._internal();

  factory RescheduleService() {
    return _instance;
  }

  // ══════════════════════════════════════════════════════════
  //  STREAMS
  // ══════════════════════════════════════════════════════════

  /// Stream of all reschedule requests for admin dashboard
  Stream<List<Map<String, dynamic>>> rescheduleRequestsStream() {
    return _supabase
        .from('reschedule_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  /// Stream of reschedule requests for a specific customer
  Stream<List<Map<String, dynamic>>> customerRescheduleRequestsStream(String customerEmail) {
    return _supabase
        .from('reschedule_requests')
        .stream(primaryKey: ['id'])
        .eq('customer_email', customerEmail.toLowerCase())
        .order('created_at', ascending: false);
  }

  // ══════════════════════════════════════════════════════════
  //  CUSTOMER ACTIONS
  // ══════════════════════════════════════════════════════════

  /// Submit a reschedule request from customer side (Pending Admin Approval)
  Future<Map<String, dynamic>> requestReschedule({
    required String reservationId,
    String? customerId,
    required String customerName,
    required String customerEmail,
    String? customerPhone,
    required String oldDate,
    required String oldTime,
    int? oldDuration,
    int? oldGuests,
    required String newDate,
    required String newTime,
    int? newDuration,
    int? newGuests,
    required String reason,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // Check if there is already a pending reschedule request for this reservation
      final existing = await _supabase
          .from('reschedule_requests')
          .select('id')
          .eq('reservation_id', reservationId)
          .eq('status', 'pending')
          .maybeSingle();

      if (existing != null) {
        return {
          'success': false,
          'error': 'There is already a pending reschedule request for this reservation.',
        };
      }

      // Insert new reschedule request
      final requestData = {
        'reservation_id': reservationId,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_email': customerEmail.toLowerCase(),
        'customer_phone': customerPhone,
        'old_date': oldDate,
        'old_time': oldTime,
        'old_duration': oldDuration,
        'old_guests': oldGuests,
        'new_date': newDate,
        'new_time': newTime,
        'new_duration': newDuration ?? oldDuration,
        'new_guests': newGuests ?? oldGuests,
        'reason': reason,
        'status': 'pending',
        'created_at': now,
        'updated_at': now,
      };

      final response = await _supabase
          .from('reschedule_requests')
          .insert(requestData)
          .select()
          .single();

      // Attempt to update reservation reschedule_status flag
      try {
        await _supabase.from('reservations').update({
          'reschedule_status': 'pending_approval',
          'updated_at': now,
        }).eq('id', reservationId);
      } catch (e) {
        debugPrint('Note: reschedule_status column update skipped or failed: $e');
      }

      // Send in-app notification to Admin
      await NotificationService.sendNotification(
        isForAdmin: true,
        actorName: customerName,
        actionType: 'reschedule_request',
        reservationId: reservationId,
        eventType: 'Reschedule Request: $customerName requested to move reservation from $oldDate ($oldTime) to $newDate ($newTime)',
        customerEmail: customerEmail,
        eventDate: newDate,
        startTime: newTime,
      );

      return {
        'success': true,
        'request': response,
        'message': 'Reschedule request submitted successfully. Waiting for admin approval.',
      };
    } catch (e) {
      debugPrint('Error requesting reschedule: $e');
      return {
        'success': false,
        'error': 'Failed to submit reschedule request: $e',
      };
    }
  }

  // ══════════════════════════════════════════════════════════
  //  ADMIN ACTIONS
  // ══════════════════════════════════════════════════════════

  /// Admin approves a reschedule request
  Future<bool> approveReschedule({
    required String requestId,
    required String reservationId,
    required String adminEmail,
    required String newDate,
    required String newTime,
    int? newDuration,
    int? newGuests,
    String? adminNotes,
    String? customerEmail,
    String? customerName,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // 1. Update the reschedule_requests record
      await _supabase.from('reschedule_requests').update({
        'status': 'approved',
        'reviewed_by': adminEmail,
        'reviewed_at': now,
        'admin_notes': adminNotes,
        'updated_at': now,
      }).eq('id', requestId);

      // 2. Update the actual reservation with the approved new schedule
      final reservationUpdates = <String, dynamic>{
        'event_date': newDate,
        'start_time': newTime,
        'updated_at': now,
        'reschedule_status': 'rescheduled',
      };

      if (newDuration != null) {
        reservationUpdates['duration_hours'] = newDuration;
      }
      if (newGuests != null) {
        reservationUpdates['number_of_guests'] = newGuests;
      }

      await _supabase
          .from('reservations')
          .update(reservationUpdates)
          .eq('id', reservationId);

      // 3. Notify customer of approval
      String? targetEmail = customerEmail?.trim().toLowerCase();
      if (targetEmail == null || targetEmail.isEmpty) {
        try {
          final res = await _supabase
              .from('reservations')
              .select('customer_email')
              .eq('id', reservationId)
              .maybeSingle();
          targetEmail = res?['customer_email']?.toString().trim().toLowerCase();
        } catch (_) {}
      }
      if (targetEmail == null || targetEmail.isEmpty) {
        try {
          final req = await _supabase
              .from('reschedule_requests')
              .select('customer_email')
              .eq('id', requestId)
              .maybeSingle();
          targetEmail = req?['customer_email']?.toString().trim().toLowerCase();
        } catch (_) {}
      }

      if (targetEmail != null && targetEmail.isNotEmpty) {
        await NotificationService.sendNotification(
          recipientEmail: targetEmail,
          isForAdmin: false,
          actorName: 'Admin',
          actionType: 'reschedule_approved',
          reservationId: reservationId,
          eventType: 'Your reschedule request has been APPROVED! New schedule: $newDate at $newTime.',
          eventDate: newDate,
          startTime: newTime,
        );
      }

      // Log in Audit Trail
      await AuditLogService.logActivity(
        action: 'APPROVE',
        module: 'Reschedule',
        description: 'Approved reschedule request for Reservation #$reservationId to $newDate ($newTime) for ${customerName ?? targetEmail ?? "Customer"}',
        entityId: reservationId,
        customUserEmail: adminEmail,
        metadata: {
          'request_id': requestId,
          'reservation_id': reservationId,
          'new_date': newDate,
          'new_time': newTime,
          'customer_name': customerName,
          'customer_email': targetEmail,
          'admin_notes': adminNotes,
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error approving reschedule: $e');
      return false;
    }
  }

  /// Admin rejects a reschedule request
  Future<bool> rejectReschedule({
    required String requestId,
    required String reservationId,
    required String adminEmail,
    required String rejectionReason,
    String? customerEmail,
    String? customerName,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // 1. Update the reschedule_requests record
      await _supabase.from('reschedule_requests').update({
        'status': 'rejected',
        'reviewed_by': adminEmail,
        'reviewed_at': now,
        'admin_notes': rejectionReason,
        'updated_at': now,
      }).eq('id', requestId);

      // 2. Reset reservation reschedule_status flag
      try {
        await _supabase.from('reservations').update({
          'reschedule_status': 'reschedule_rejected',
          'updated_at': now,
        }).eq('id', reservationId);
      } catch (e) {
        debugPrint('Note: reschedule_status update skipped: $e');
      }

      // 3. Notify customer of rejection with reason
      String? targetEmail = customerEmail?.trim().toLowerCase();
      if (targetEmail == null || targetEmail.isEmpty) {
        try {
          final res = await _supabase
              .from('reservations')
              .select('customer_email')
              .eq('id', reservationId)
              .maybeSingle();
          targetEmail = res?['customer_email']?.toString().trim().toLowerCase();
        } catch (_) {}
      }
      if (targetEmail == null || targetEmail.isEmpty) {
        try {
          final req = await _supabase
              .from('reschedule_requests')
              .select('customer_email')
              .eq('id', requestId)
              .maybeSingle();
          targetEmail = req?['customer_email']?.toString().trim().toLowerCase();
        } catch (_) {}
      }

      if (targetEmail != null && targetEmail.isNotEmpty) {
        await NotificationService.sendNotification(
          recipientEmail: targetEmail,
          isForAdmin: false,
          actorName: 'Admin',
          actionType: 'reschedule_rejected',
          reservationId: reservationId,
          eventType: 'Your reschedule request was not approved. Reason: $rejectionReason',
        );
      }

      // Log in Audit Trail
      await AuditLogService.logActivity(
        action: 'REJECT',
        module: 'Reschedule',
        description: 'Rejected reschedule request for Reservation #$reservationId (${customerName ?? targetEmail ?? "Customer"}). Reason: $rejectionReason',
        entityId: reservationId,
        customUserEmail: adminEmail,
        metadata: {
          'request_id': requestId,
          'reservation_id': reservationId,
          'customer_name': customerName,
          'customer_email': targetEmail,
          'rejection_reason': rejectionReason,
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error rejecting reschedule: $e');
      return false;
    }
  }

  /// Customer cancels their own pending reschedule request
  Future<bool> cancelRescheduleRequest({
    required String requestId,
    required String reservationId,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await _supabase.from('reschedule_requests').update({
        'status': 'cancelled',
        'updated_at': now,
      }).eq('id', requestId);

      try {
        await _supabase.from('reservations').update({
          'reschedule_status': 'none',
          'updated_at': now,
        }).eq('id', reservationId);
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error cancelling reschedule request: $e');
      return false;
    }
  }
}
