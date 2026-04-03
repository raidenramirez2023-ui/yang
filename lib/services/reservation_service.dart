import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yang_chow/services/app_settings_service.dart';
import 'package:yang_chow/services/email_notification_service.dart';

/// Service to manage reservation operations (create, cancel, reschedule, etc.)
class ReservationService {
  static final ReservationService _instance = ReservationService._internal();
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final AppSettingsService _appSettings = AppSettingsService();
  static final EmailNotificationService _emailService =
      EmailNotificationService();

  ReservationService._internal();

  factory ReservationService() {
    return _instance;
  }

  /// Create a new reservation
  Future<Map<String, dynamic>> createReservation({
    required String customerEmail,
    required String customerName,
    required String eventType,
    required String eventDate,
    required String startTime,
    required double durationHours,
    required int numberOfGuests,
    required String? specialRequests,
    required String? customerPhone,
    required String? customerAddress,
  }) async {
    try {
      final now = DateTime.now();

      final response = await _supabase
          .from('reservations')
          .insert({
            'customer_email': customerEmail,
            'customer_name': customerName,
            'event_type': eventType,
            'event_date': eventDate,
            'start_time': startTime,
            'duration_hours': durationHours.toInt(),
            'number_of_guests': numberOfGuests,
            'status': 'pending',
            'payment_status': 'unpaid',
            'special_requests': specialRequests,
            'customer_phone': customerPhone,
            'customer_address': customerAddress,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .select()
          .single();

      // Send confirmation email
      await _emailService.sendReservationConfirmation(
        customerEmail: customerEmail,
        customerName: customerName,
        eventType: eventType,
        eventDate: eventDate,
        startTime: startTime,
        duration: durationHours,
        guests: numberOfGuests,
      );

      return response;
    } catch (e) {
      debugPrint('Error creating reservation: $e');
      throw Exception('Failed to create reservation: $e');
    }
  }

  /// Cancel a reservation and process refund
  Future<bool> cancelReservation({
    required String reservationId,
    required String customerEmail,
    required String customerName,
    required String eventType,
    required String eventDate,
    required String cancellationReason,
    required bool isAdminCancel,
  }) async {
    try {
      // Get reservation to check current status
      final reservation = await _supabase
          .from('reservations')
          .select()
          .eq('id', reservationId)
          .single();

      // Calculate refund amount based on cancellation policy
      final refundAmount = _calculateRefundAmount(
        eventDate: eventDate,
        paymentAmount: reservation['payment_amount'] ?? 0.0,
      );

      // Update reservation status
      await _supabase
          .from('reservations')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancellation_reason': cancellationReason,
            'refund_amount': refundAmount,
            'refund_status': refundAmount > 0 ? 'pending' : 'none',
          })
          .eq('id', reservationId);

      // Log cancellation request for admin review if customer initiated
      if (!isAdminCancel) {
        await _supabase.from('cancellation_requests').insert({
          'reservation_id': reservationId,
          'customer_email': customerEmail,
          'cancellation_reason': cancellationReason,
          'refund_amount': refundAmount,
          'status': 'pending',
        });
      }

      // Send cancellation email
      await _emailService.sendReservationCancelled(
        customerEmail: customerEmail,
        customerName: customerName,
        eventType: eventType,
        eventDate: eventDate,
        refundAmount: refundAmount > 0 ? refundAmount : null,
      );

      return true;
    } catch (e) {
      debugPrint('Error cancelling reservation: $e');
      throw Exception('Failed to cancel reservation: $e');
    }
  }

  /// Reschedule a reservation to a new date/time
  Future<bool> rescheduleReservation({
    required String reservationId,
    required String newDate,
    required String newStartTime,
    required double? newDuration,
    required int? newGuests,
  }) async {
    try {
      final now = DateTime.now();

      final updates = <String, dynamic>{
        'event_date': newDate,
        'start_time': newStartTime,
        'updated_at': now.toIso8601String(),
      };

      if (newDuration != null) {
        updates['duration_hours'] = newDuration.toInt();
      }

      if (newGuests != null) {
        updates['number_of_guests'] = newGuests;
      }

      await _supabase
          .from('reservations')
          .update(updates)
          .eq('id', reservationId);

      return true;
    } catch (e) {
      debugPrint('Error rescheduling reservation: $e');
      throw Exception('Failed to reschedule reservation: $e');
    }
  }

  /// Update special requests for a reservation
  Future<bool> updateSpecialRequests({
    required String reservationId,
    required String specialRequests,
  }) async {
    try {
      await _supabase
          .from('reservations')
          .update({
            'special_requests': specialRequests,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reservationId);

      return true;
    } catch (e) {
      debugPrint('Error updating special requests: $e');
      throw Exception('Failed to update special requests: $e');
    }
  }

  /// Update customer contact info
  Future<bool> updateCustomerInfo({
    required String reservationId,
    required String? phone,
    required String? address,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (phone != null) updates['customer_phone'] = phone;
      if (address != null) updates['customer_address'] = address;

      await _supabase
          .from('reservations')
          .update(updates)
          .eq('id', reservationId);

      return true;
    } catch (e) {
      debugPrint('Error updating customer info: $e');
      throw Exception('Failed to update customer info: $e');
    }
  }

  /// Add a review for a reservation
  Future<bool> addReview({
    required String reservationId,
    required String customerEmail,
    required int overallRating,
    required int foodQuality,
    required int serviceQuality,
    required int ambiance,
    required String? reviewText,
  }) async {
    try {
      await _supabase.from('reviews').insert({
        'reservation_id': reservationId,
        'customer_email': customerEmail,
        'rating': overallRating,
        'food_quality': foodQuality,
        'service_quality': serviceQuality,
        'ambiance': ambiance,
        'review_text': reviewText,
      });

      return true;
    } catch (e) {
      debugPrint('Error adding review: $e');
      throw Exception('Failed to add review: $e');
    }
  }

  /// Get reviews for a reservation
  Future<Map<String, dynamic>?> getReservationReview(
    String reservationId,
  ) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select()
          .eq('reservation_id', reservationId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching review: $e');
      return null;
    }
  }

  /// Get all reviews (public listing)
  Future<List<Map<String, dynamic>>> getAllReviews({
    int limit = 5,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
      return [];
    }
  }

  /// Get average ratings
  Future<Map<String, double>> getAverageRatings() async {
    try {
      final response = await _supabase.rpc('get_average_ratings');

      return {
        'overall': (response['avg_rating'] as num?)?.toDouble() ?? 0.0,
        'food': (response['avg_food_quality'] as num?)?.toDouble() ?? 0.0,
        'service': (response['avg_service_quality'] as num?)?.toDouble() ?? 0.0,
        'ambiance': (response['avg_ambiance'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      debugPrint('Error fetching average ratings: $e');
      return {'overall': 0.0, 'food': 0.0, 'service': 0.0, 'ambiance': 0.0};
    }
  }

  /// Calculate refund amount based on cancellation policy
  double _calculateRefundAmount({
    required String eventDate,
    required double paymentAmount,
  }) {
    try {
      final event = DateTime.parse(eventDate);
      final now = DateTime.now();
      final daysUntilEvent = event.difference(now).inDays;

      final refundPolicyDays = _appSettings.getRefundPolicyDays();
      final refundPercentageWithinWindow = _appSettings
          .getRefundPercentageWithinWindow();

      // 100% refund if cancelled 7+ days before
      if (daysUntilEvent >= refundPolicyDays) {
        return paymentAmount;
      }

      // Percentage refund if within window
      if (daysUntilEvent > 0) {
        return paymentAmount * (refundPercentageWithinWindow / 100);
      }

      // No refund if event date passed
      return 0.0;
    } catch (e) {
      debugPrint('Error calculating refund: $e');
      return 0.0;
    }
  }

  /// Get customer reservations
  Future<List<Map<String, dynamic>>> getCustomerReservations(
    String customerEmail,
  ) async {
    try {
      final response = await _supabase
          .from('reservations')
          .select()
          .eq('customer_email', customerEmail)
          .order('event_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching customer reservations: $e');
      return [];
    }
  }

  /// Get a specific reservation
  Future<Map<String, dynamic>?> getReservation(String reservationId) async {
    try {
      final response = await _supabase
          .from('reservations')
          .select()
          .eq('id', reservationId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching reservation: $e');
      return null;
    }
  }

  /// Check if customer can cancel/reschedule a reservation
  bool canModifyReservation(String status) {
    return status == 'pending' || status == 'confirmed';
  }

  /// Stream of customer reservations (real-time updates)
  Stream<List<Map<String, dynamic>>> watchCustomerReservations(
    String customerEmail,
  ) {
    return _supabase
        .from('reservations')
        .stream(primaryKey: ['id'])
        .eq('customer_email', customerEmail)
        .order('event_date')
        .map((maps) => List<Map<String, dynamic>>.from(maps));
  }
}
