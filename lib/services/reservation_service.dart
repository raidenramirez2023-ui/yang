import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yang_chow/services/email_notification_service.dart';

import 'package:yang_chow/services/pricing_service.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:yang_chow/services/refund_service.dart';
import 'package:yang_chow/services/audit_log_service.dart';
import 'package:yang_chow/services/app_settings_service.dart';



/// Service to manage reservation operations (create, cancel, reschedule, etc.)

class ReservationService {

  static final ReservationService _instance = ReservationService._internal();

  static final SupabaseClient _supabase = Supabase.instance.client;

  static final EmailNotificationService _emailService =

      EmailNotificationService();

  static final PricingService _pricingService = PricingService();



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

    String? uploadedIdUrl,
    String? paymentOption = 'half',
    String? paymentMethod = 'paymongo',
    String? transactedBy,
    String status = 'pending',
    String paymentStatus = 'unpaid',
    bool bypassRestrictions = false,
  }) async {
    try {
      final now = DateTime.now();

      // Validate customer booking eligibility (restrictions, limits, duplicate spam)
      if (!bypassRestrictions) {
        final eligibility = await validateCustomerBookingEligibility(
          customerEmail: customerEmail,
          eventDate: eventDate,
          startTime: startTime,
        );
        if (eligibility['isEligible'] != true) {
          throw Exception(eligibility['message'] ?? 'Booking validation failed');
        }
      }

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
            'status': status,
            'payment_status': paymentStatus,
            'special_requests': specialRequests,
            'customer_phone': customerPhone,
            'customer_address': customerAddress,
            'uploaded_id_url': uploadedIdUrl,
            'payment_option': paymentOption,
            'payment_method': paymentMethod,
            'transacted_by': transactedBy,
            'created_at': now.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),
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

      // Send in-app notification to Admin & Kitchen
      await NotificationService.sendNotification(
        isForAdmin: true,
        actorName: customerName,
        actionType: 'created',
        reservationId: response['id'],
        eventType: eventType,
        customerEmail: customerEmail,
        startTime: startTime,
        guestCount: numberOfGuests,
        eventDate: eventDate,
      );



      return response;

    } catch (e) {

      debugPrint('Error creating reservation: $e');

      throw Exception('Failed to create reservation: $e');

    }

  }



  /// Create a new menu-based reservation

  Future<Map<String, dynamic>> createMenuBasedReservation({

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

    required Map<String, int> selectedMenuItems,

    required double totalMenuPrice,

    required double depositAmount,

    String? uploadedIdUrl,
    String? paymentOption = 'half',
    String? paymentMethod = 'paymongo',
    String? transactedBy,
    String status = 'pending',
    String paymentStatus = 'unpaid',
    bool bypassRestrictions = false,
  }) async {
    try {
      final now = DateTime.now();

      // Validate customer booking eligibility (restrictions, limits, duplicate spam)
      if (!bypassRestrictions) {
        final eligibility = await validateCustomerBookingEligibility(
          customerEmail: customerEmail,
          eventDate: eventDate,
          startTime: startTime,
        );
        if (eligibility['isEligible'] != true) {
          throw Exception(eligibility['message'] ?? 'Booking validation failed');
        }
      }

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
            'status': status,
            'payment_status': paymentStatus,
            'special_requests': specialRequests,
            'customer_phone': customerPhone,
            'customer_address': customerAddress,
            'uploaded_id_url': uploadedIdUrl,
            'payment_option': paymentOption,
            'payment_method': paymentMethod,
            'transacted_by': transactedBy,
            'created_at': now.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),

            // Menu-based pricing fields
            'total_price': totalMenuPrice,
            'deposit_amount': depositAmount,
            'remaining_balance': (paymentOption == 'full' || paymentStatus == 'paid' || paymentStatus == 'fully_paid')
                ? 0.0
                : (totalMenuPrice - depositAmount).clamp(0.0, double.infinity),
            'is_menu_based': true,
            'selected_menu_items': selectedMenuItems,
            'pricing_type': 'menu_based',
          })

          .select()

          .single();



      // Send confirmation email with menu details

      await _emailService.sendReservationConfirmation(
        customerEmail: customerEmail,
        customerName: customerName,
        eventType: eventType,
        eventDate: eventDate,
        startTime: startTime,
        duration: durationHours,
        guests: numberOfGuests,
      );

      // Send in-app notification to Admin & Kitchen
      await NotificationService.sendNotification(
        isForAdmin: true,
        actorName: customerName,
        actionType: 'created',
        reservationId: response['id'],
        eventType: eventType,
        customerEmail: customerEmail,
        startTime: startTime,
        guestCount: numberOfGuests,
        eventDate: eventDate,
      );



      return response;

    } catch (e) {

      debugPrint('Error creating menu-based reservation: $e');

      throw Exception('Failed to create menu-based reservation: $e');

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
      final paymentAmount = (reservation['payment_amount'] as num?)?.toDouble() ??
          (reservation['deposit_amount'] as num?)?.toDouble() ??
          (reservation['amount_paid'] as num?)?.toDouble() ??
          (reservation['total_price'] as num?)?.toDouble() ??
          (reservation['total_amount'] as num?)?.toDouble() ??
          0.0;

      final refundService = RefundService();

      final refundAmount = refundService.calculateRefundAmount(

        eventDate: eventDate,

        paymentAmount: paymentAmount,

      );



      // Update reservation status

      await _supabase

          .from('reservations')

          .update({

            'status': 'cancelled',

            'cancelled_at': DateTime.now().toUtc().toIso8601String(),

            'cancellation_reason': cancellationReason,

            'refund_amount': refundAmount,

            'refund_status': refundAmount > 0 ? 'pending' : 'none',

          })

          .eq('id', reservationId);



      // Create a refund record via RefundService (if refund is applicable)

      if (refundAmount > 0) {

        final paymongoPaymentId = reservation['paymongo_payment_id'] as String?;

        await refundService.requestReservationRefund(

          reservationId: reservationId,

          customerEmail: customerEmail,

          customerName: customerName,

          eventType: eventType,

          eventDate: eventDate,

          cancellationReason: cancellationReason,

          paymentAmount: paymentAmount,

          paymongoPaymentId: paymongoPaymentId,

        );

      }



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

        'updated_at': now.toUtc().toIso8601String(),

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

            'updated_at': DateTime.now().toUtc().toIso8601String(),

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

        'updated_at': DateTime.now().toUtc().toIso8601String(),

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
  /// Upsert a review (Create or Update based on customer email)
  Future<bool> upsertReview({
    required String reservationId,
    required String customerEmail,
    required int overallRating,
    required int foodQuality,
    required int serviceQuality,
    required int ambiance,
    int? turnaroundTime,
    int? responsivenessRate,
    required String? reviewText,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final fullData = <String, dynamic>{
        'reservation_id': reservationId,
        'customer_email': customerEmail,
        'rating': overallRating,
        'food_quality': foodQuality,
        'service_quality': serviceQuality,
        'ambiance': ambiance,
        if (turnaroundTime != null && turnaroundTime > 0) 'turnaround_time': turnaroundTime,
        if (responsivenessRate != null && responsivenessRate > 0) 'responsiveness_rate': responsivenessRate,
        'review_text': reviewText,
        'updated_at': now,
      };

      try {
        await _supabase.from('reviews').upsert(fullData, onConflict: 'customer_email');
        return true;
      } catch (upsertErr) {
        final errStr = upsertErr.toString().toLowerCase();
        // If columns don't exist yet in Supabase schema, fallback to standard columns
        if (errStr.contains('column') ||
            errStr.contains('schema') ||
            errStr.contains('turnaround') ||
            errStr.contains('responsiveness')) {
          final fallbackData = <String, dynamic>{
            'reservation_id': reservationId,
            'customer_email': customerEmail,
            'rating': overallRating,
            'food_quality': foodQuality,
            'service_quality': serviceQuality,
            'ambiance': ambiance,
            'review_text': reviewText,
            'updated_at': now,
          };
          await _supabase.from('reviews').upsert(fallbackData, onConflict: 'customer_email');
          return true;
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Error upserting review: $e');
      throw Exception('Failed to submit review: $e');
    }
  }

  /// Get the existing review for a customer
  Future<Map<String, dynamic>?> getCustomerReview(String customerEmail) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select()
          .eq('customer_email', customerEmail)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching customer review: $e');
      return null;
    }
  }

  /// Check if a customer is eligible to leave a review (has any reservation or advance order)
  Future<bool> isEligibleForReview(String customerEmail) async {
    try {
      final reservations = await getCustomerReservations(customerEmail);
      final advanceOrders = await getCustomerAdvanceOrders(customerEmail);

      return reservations.isNotEmpty || advanceOrders.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking review eligibility: $e');
      return false;
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







  /// Create a new advance order
  Future<Map<String, dynamic>> createAdvanceOrder({
    required String customerEmail,
    required String customerName,
    required String orderType,
    required String orderDate,
    required String orderTime,
    required int? numberOfGuests,
    required Map<String, int> selectedMenuItems,
    required double totalPrice,
    required String? preparationNotes,
    String? paymentMethod = 'paymongo',
  }) async {
    try {
      final now = DateTime.now();

      final response = await _supabase
          .from('advance_orders')
          .insert({
            'customer_email': customerEmail,
            'customer_name': customerName,
            'order_type': orderType,
            'order_date': orderDate,
            'order_time': orderTime,
            'number_of_guests': numberOfGuests,
            'selected_menu_items': selectedMenuItems,
            'total_price': totalPrice,
            'status': 'unpaid',
            'payment_status': 'unpaid',
            'payment_method': paymentMethod,
            'preparation_notes': preparationNotes,
            'created_at': now.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),
          })
          .select()
          .single();

      // Send confirmation email
      await _emailService.sendReservationConfirmation(
        customerEmail: customerEmail,
        customerName: customerName,
        eventType: 'Advance Order ($orderType)',
        eventDate: orderDate,
        startTime: orderTime,
        duration: 0.0,
        guests: numberOfGuests ?? 0,
      );

      // Send in-app notification to Admin & Kitchen
      await NotificationService.sendNotification(
        isForAdmin: true,
        actorName: customerName,
        actionType: 'created',
        reservationId: response['id'],
        eventType: 'Advance Order ($orderType)',
        customerEmail: customerEmail,
        startTime: orderTime,
        guestCount: numberOfGuests,
        eventDate: orderDate,
      );

      return response;
    } catch (e) {
      debugPrint('Error creating advance order: $e');
      throw Exception('Failed to create advance order: $e');
    }
  }

  /// Get customer advance orders
  Future<List<Map<String, dynamic>>> getCustomerAdvanceOrders(
    String customerEmail,
  ) async {
    try {
      final response = await _supabase
          .from('advance_orders')
          .select()
          .eq('customer_email', customerEmail)
          .order('order_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching advance orders: $e');
      return [];
    }
  }

  /// Cancel an advance order
  Future<bool> cancelAdvanceOrder({
    required String orderId,
    required String customerEmail,
    required String customerName,
    required String orderType,
    required String orderDate,
    required String cancellationReason,
  }) async {
    try {
      // Fetch order details for refund calculation
      final order = await _supabase
          .from('advance_orders')
          .select()
          .eq('id', orderId)
          .single();
          
      final double totalPrice = (order['total_price'] as num?)?.toDouble() ?? 0.0;
      final String paymentStatus = order['payment_status'] ?? 'unpaid';
      
      final refundService = RefundService();
      double? refundAmount;
      if (paymentStatus == 'paid' || paymentStatus == 'fully_paid') {
        refundAmount = refundService.calculateRefundAmount(
          eventDate: orderDate,
          paymentAmount: totalPrice,
        );
      }

      await _supabase
          .from('advance_orders')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'refund_amount': refundAmount,
          })
          .eq('id', orderId);

      // Create refund record via RefundService if applicable
      if (refundAmount != null && refundAmount > 0) {
        final paymongoPaymentId = order['paymongo_payment_id'] as String?;
        await refundService.requestAdvanceOrderRefund(
          orderId: orderId,
          customerEmail: customerEmail,
          customerName: customerName,
          orderType: orderType,
          orderDate: orderDate,
          cancellationReason: cancellationReason,
          paymentAmount: totalPrice,
          paymongoPaymentId: paymongoPaymentId,
        );
      }

      // Send cancellation email
      await _emailService.sendReservationCancelled(
        customerEmail: customerEmail,
        customerName: customerName,
        eventType: 'Advance Order ($orderType)',
        eventDate: orderDate,
        refundAmount: refundAmount,
      );

      return true;
    } catch (e) {
      debugPrint('Error cancelling advance order: $e');
      throw Exception('Failed to cancel advance order: $e');
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



  /// Set pricing for a reservation and send quotation with deadline
  Future<bool> setReservationPricing({
    required String reservationId,
    required double totalPrice,
    required double depositAmount,
    required String customerEmail,
    required String customerName,
    required String eventType,
    required String eventDate,
    required String startTime,
    required int durationHours,
    required int numberOfGuests,
    int deadlineHours = 24,
    DateTime? customDeadline,
  }) async {
    try {
      final now = DateTime.now();
      final currentUser = _supabase.auth.currentUser;
      final adminIdentifier = currentUser?.email ?? 'Admin';

      final quotationExpiresAt = customDeadline ?? now.add(Duration(hours: deadlineHours));

      // Update reservation with pricing details & deadline
      await _supabase
          .from('reservations')
          .update({
            'total_price': totalPrice,
            'deposit_amount': depositAmount,
            'payment_status': 'unpaid',
            'price_quotation_sent': true,
            'price_quotation_sent_at': now.toUtc().toIso8601String(),
            'quotation_expires_at': quotationExpiresAt.toUtc().toIso8601String(),
            'admin_set_price': true,
            'transacted_by': adminIdentifier,
            'updated_at': now.toUtc().toIso8601String(),
          })
          .eq('id', reservationId);

      final formattedDeadline = DateFormat('MMMM dd, yyyy • h:mm a').format(quotationExpiresAt.toLocal());

      // Send price quotation email with deadline
      await _emailService.sendPriceQuotation(
        customerEmail: customerEmail,
        customerName: customerName,
        eventType: eventType,
        eventDate: eventDate,
        startTime: startTime,
        duration: durationHours.toDouble(),
        guests: numberOfGuests,
        totalPrice: totalPrice,
        depositAmount: depositAmount,
        paymentDeadlineStr: formattedDeadline,
        reservationId: reservationId,
      );

      // Audit log entry
      await AuditLogService.logActivity(
        action: 'PRICE_QUOTATION',
        module: 'Reservations',
        description: 'Admin sent quotation of ₱${totalPrice.toStringAsFixed(2)} with deadline $formattedDeadline',
        entityId: reservationId,
        metadata: {
          'customer_email': customerEmail,
          'total_price': totalPrice,
          'deposit_amount': depositAmount,
          'deadline': quotationExpiresAt.toIso8601String(),
          'deadline_hours': deadlineHours,
        },
      );

      return true;
    } catch (e) {

      debugPrint('Error setting reservation pricing: $e');

      throw Exception('Failed to set reservation pricing: $e');

    }

  }



  /// Update reservation status

  Future<bool> updateReservationStatus({

    required String reservationId,

    required String status,

  }) async {

    try {

      await _supabase

          .from('reservations')

          .update({

            'status': status,

            'updated_at': DateTime.now().toUtc().toIso8601String(),

          })

          .eq('id', reservationId);



      return true;

    } catch (e) {

      debugPrint('Error updating reservation status: $e');

      return false;

    }

  }

  /// Validate whether a customer is eligible to create a new reservation
  Future<Map<String, dynamic>> validateCustomerBookingEligibility({
    String? userId,
    required String customerEmail,
    String? eventDate,
    String? startTime,
    String? proposedDate,
    String? proposedStartTime,
    double? proposedDurationHours,
    String? reservationType,
  }) async {
    try {
      final email = customerEmail.trim().toLowerCase();
      if (email.isEmpty) {
        return {'isEligible': true, 'eligible': true};
      }

      final now = DateTime.now();

      // 1. Check Customer Account Restriction Status in users table
      try {
        final userRes = await _supabase
            .from('users')
            .select('restriction_status, warning_count, restriction_reason, restriction_start, restriction_end')
            .ilike('email', email)
            .maybeSingle();

        if (userRes != null) {
          final status = (userRes['restriction_status'] ?? 'active').toString().toLowerCase();
          final restrictionEndStr = userRes['restriction_end']?.toString();
          DateTime? restrictionEnd;
          if (restrictionEndStr != null && restrictionEndStr.isNotEmpty) {
            restrictionEnd = DateTime.tryParse(restrictionEndStr)?.toLocal();
          }

          // If temporary restriction has expired, auto-unrestrict the customer
          if (status == 'temporarily_restricted' && restrictionEnd != null && now.isAfter(restrictionEnd)) {
            await _supabase.from('users').update({
              'restriction_status': 'active',
              'restriction_end': null,
              'restriction_reason': null,
            }).ilike('email', email);

            // Log auto-unrestriction in audit log
            await AuditLogService.logActivity(
              action: 'UNRESTRICT',
              module: 'Customer Accounts',
              description: 'Customer temporary restriction expired and was automatically removed.',
              entityId: email,
            );
          } else if (status == 'temporarily_restricted' || status == 'blocked' || status == 'suspended') {
            final reason = userRes['restriction_reason']?.toString() ?? 'Repeated abandoned or unpaid bookings';
            final expiryNotice = restrictionEnd != null
                ? ' until ${DateFormat('MMMM dd, yyyy • h:mm a').format(restrictionEnd)}'
                : '';
            final msg = 'Your account is temporarily restricted from creating new reservations$expiryNotice. Please review your existing reservations or contact the administrator for assistance.';

            return {
              'isEligible': false,
              'eligible': false,
              'reason': msg,
              'restriction_type': 'account_restricted',
              'status': status,
              'message': msg,
              'adminRemark': reason,
            };
          }
        }
      } catch (e) {
        debugPrint('Note: Account restriction check error (continuing): $e');
      }

      // 2. Check Existing Pending/Unconfirmed Inquiries against limit
      // Note: Confirmed/approved reservations on DIFFERENT dates do NOT count against this limit!
      int maxPendingBookings = AppSettingsService().getSetting<int>('max_active_reservations_per_customer') ?? 3;
      final activeReservations = await _supabase
          .from('reservations')
          .select('id, status, event_date, price_quotation_sent, payment_status, created_at')
          .ilike('customer_email', email)
          .inFilter('status', ['pending', 'confirmed', 'pending_admin_approval', 'awaiting_verification'])
          .eq('is_archived', false);

      final activeList = List<Map<String, dynamic>>.from(activeReservations);

      // Only count unconfirmed / pending requests awaiting quotation or approval
      final pendingInquiries = activeList.where((r) {
        final st = (r['status'] ?? '').toString().toLowerCase();
        return st == 'pending' || st == 'pending_admin_approval' || st == 'awaiting_verification';
      }).toList();

      if (pendingInquiries.length >= maxPendingBookings) {
        final msg = 'You currently have $maxPendingBookings pending reservation request${maxPendingBookings > 1 ? 's' : ''} awaiting review or quotation. Once confirmed or processed, you can submit bookings for other dates.';
        return {
          'isEligible': false,
          'eligible': false,
          'reason': msg,
          'activeCount': pendingInquiries.length,
          'maxAllowed': maxPendingBookings,
          'message': msg,
        };
      }

      // 3. Check if customer already has a quotation awaiting confirmation / payment
      final pendingQuotation = activeList.firstWhere(
        (r) {
          final status = (r['status'] ?? '').toString().toLowerCase();
          final quoteSent = r['price_quotation_sent'] == true;
          final paymentStatus = (r['payment_status'] ?? '').toString().toLowerCase();
          return status == 'pending' && quoteSent && paymentStatus == 'unpaid';
        },
        orElse: () => {},
      );

      if (pendingQuotation.isNotEmpty) {
        final msg = 'You currently have a quotation awaiting payment/confirmation. Please settle or confirm your existing quotation before submitting a new booking.';
        return {
          'isEligible': false,
          'eligible': false,
          'reason': msg,
          'reservationId': pendingQuotation['id'],
          'message': msg,
        };
      }

      // 4. Anti-spam rapid submission check (cooldown window)
      final recentReservations = await _supabase
          .from('reservations')
          .select('created_at')
          .ilike('customer_email', email)
          .order('created_at', ascending: false)
          .limit(1);

      if (recentReservations.isNotEmpty) {
        final lastCreatedStr = recentReservations[0]['created_at']?.toString();
        if (lastCreatedStr != null && lastCreatedStr.isNotEmpty) {
          final lastCreated = DateTime.tryParse(lastCreatedStr)?.toLocal();
          if (lastCreated != null) {
            final diffMinutes = now.difference(lastCreated).inMinutes;
            if (diffMinutes < 3) {
              const msg = 'Please wait a moment before submitting another reservation inquiry.';
              return {
                'isEligible': false,
                'eligible': false,
                'reason': msg,
                'message': msg,
              };
            }
          }
        }
      }

      return {'isEligible': true, 'eligible': true};
    } catch (e) {
      debugPrint('Error validating customer booking eligibility: $e');
      return {'isEligible': true, 'eligible': true}; // Graceful fallback
    }
  }

  /// Automatically check and expire unpaid quotations whose deadline has elapsed
  Future<int> checkAndExpireQuotations() async {
    try {
      final now = DateTime.now();

      // Query pending reservations with price quotation sent and unpaid
      final response = await _supabase
          .from('reservations')
          .select('id, customer_email, customer_name, event_type, event_date, quotation_expires_at, price_quotation_sent_at, total_price')
          .eq('status', 'pending')
          .eq('price_quotation_sent', true)
          .eq('payment_status', 'unpaid')
          .eq('is_archived', false);

      final list = List<Map<String, dynamic>>.from(response);
      int expiredCount = 0;

      for (final r in list) {
        DateTime? expiresAt;
        if (r['quotation_expires_at'] != null && r['quotation_expires_at'].toString().isNotEmpty) {
          expiresAt = DateTime.tryParse(r['quotation_expires_at'].toString())?.toLocal();
        } else if (r['price_quotation_sent_at'] != null && r['price_quotation_sent_at'].toString().isNotEmpty) {
          // Default 24-hour fallback if no explicit deadline was set
          final sentAt = DateTime.tryParse(r['price_quotation_sent_at'].toString())?.toLocal();
          if (sentAt != null) {
            expiresAt = sentAt.add(const Duration(hours: 24));
          }
        }

        if (expiresAt != null && now.isAfter(expiresAt)) {
          final resId = r['id'].toString();

          await _supabase.from('reservations').update({
            'status': 'expired',
            'updated_at': now.toUtc().toIso8601String(),
          }).eq('id', resId);

          // Log in Audit Trail
          await AuditLogService.logActivity(
            action: 'EXPIRE',
            module: 'Reservations',
            description: 'Quotation for ${r['customer_name'] ?? 'Customer'} automatically expired (Deadline passed at ${DateFormat('MMM dd, h:mm a').format(expiresAt)}). Slot released.',
            entityId: resId,
            metadata: {
              'customer_email': r['customer_email'],
              'event_type': r['event_type'],
              'event_date': r['event_date'],
              'total_price': r['total_price'],
            },
          );

          // Send in-app notification to customer
          await NotificationService.sendNotification(
            isForAdmin: false,
            actorName: 'Yang Chow System',
            actionType: 'expired',
            reservationId: resId,
            eventType: r['event_type'] ?? 'Reservation',
            customerEmail: r['customer_email'] ?? '',
            startTime: '',
            guestCount: 0,
            eventDate: r['event_date'] ?? '',
          );

          expiredCount++;
        }
      }

      return expiredCount;
    } catch (e) {
      debugPrint('Error expiring quotations: $e');
      return 0;
    }
  }

  /// Get comprehensive customer reservation reliability metrics & restriction status
  Future<Map<String, dynamic>> getCustomerReliabilityInfo({
    String? userId,
    String? email,
    String? customerEmail,
  }) async {
    try {
      final targetEmail = (customerEmail ?? email ?? '').trim().toLowerCase();
      if (targetEmail.isEmpty) {
        return {
          'total': 0,
          'completed': 0,
          'confirmed': 0,
          'cancelled': 0,
          'expired': 0,
          'unpaidQuotations': 0,
          'noShows': 0,
          'activeReservations': 0,
          'abandonedBookings': 0,
          'restrictionStatus': 'active',
          'warningCount': 0,
          'restrictionReason': null,
          'restrictionStart': null,
          'restrictionEnd': null,
          'restrictedBy': null,
          'isRestricted': false,
          'hasWarning': false,
          'isHighRisk': false,
          'history': <Map<String, dynamic>>[],
        };
      }

      // Fetch user restriction record from users table
      Map<String, dynamic>? userRecord;
      try {
        userRecord = await _supabase
            .from('users')
            .select('id, firstname, lastname, restriction_status, warning_count, restriction_reason, restriction_start, restriction_end, restricted_by')
            .ilike('email', targetEmail)
            .maybeSingle();
      } catch (e) {
        debugPrint('Error fetching user restriction record: $e');
      }

      final restrictionStatus = (userRecord?['restriction_status'] ?? 'active').toString().toLowerCase();
      final warningCount = (userRecord?['warning_count'] as num?)?.toInt() ?? 0;
      final restrictionReason = userRecord?['restriction_reason']?.toString();
      final restrictionStart = userRecord?['restriction_start'] != null ? DateTime.tryParse(userRecord!['restriction_start'])?.toLocal() : null;
      final restrictionEnd = userRecord?['restriction_end'] != null ? DateTime.tryParse(userRecord!['restriction_end'])?.toLocal() : null;
      final restrictedBy = userRecord?['restricted_by']?.toString();

      final isRestricted = (restrictionStatus == 'temporarily_restricted' ||
          restrictionStatus == 'blocked' ||
          restrictionStatus == 'suspended') &&
          (restrictionEnd == null || DateTime.now().isBefore(restrictionEnd));

      // Fetch reservations for this customer
      final res = await _supabase
          .from('reservations')
          .select('id, event_type, event_date, start_time, total_price, deposit_amount, status, payment_status, price_quotation_sent, quotation_expires_at, created_at')
          .ilike('customer_email', targetEmail)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(res);
      final total = list.length;
      final completed = list.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'completed').length;
      final confirmed = list.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'confirmed').length;
      final cancelled = list.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'cancelled').length;
      final expired = list.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'expired').length;
      final noShows = list.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'no_show').length;

      final unpaidQuotations = list.where((r) {
        final st = (r['status'] ?? '').toString().toLowerCase();
        final quoteSent = r['price_quotation_sent'] == true;
        final paySt = (r['payment_status'] ?? '').toString().toLowerCase();
        return (st == 'pending' || st == 'expired') && quoteSent && paySt == 'unpaid';
      }).length;

      final activeReservations = list.where((r) {
        final st = (r['status'] ?? '').toString().toLowerCase();
        return st == 'pending' || st == 'confirmed' || st == 'pending_admin_approval' || st == 'awaiting_verification';
      }).length;

      final abandonedBookings = expired + noShows + list.where((r) {
        final st = (r['status'] ?? '').toString().toLowerCase();
        final quoteSent = r['price_quotation_sent'] == true;
        return st == 'cancelled' && quoteSent;
      }).length;

      final isHighRisk = abandonedBookings >= 2 || noShows >= 1 || isRestricted;

      return {
        'total': total,
        'completed': completed,
        'confirmed': confirmed,
        'cancelled': cancelled,
        'expired': expired,
        'noShows': noShows,
        'unpaidQuotations': unpaidQuotations,
        'activeReservations': activeReservations,
        'abandonedBookings': abandonedBookings,
        'restrictionStatus': restrictionStatus,
        'restriction_status': restrictionStatus,
        'warningCount': warningCount,
        'warning_count': warningCount,
        'restrictionReason': restrictionReason,
        'restriction_reason': restrictionReason,
        'warning_reason': restrictionReason,
        'restrictionStart': restrictionStart,
        'restriction_start': restrictionStart,
        'restrictionEnd': restrictionEnd,
        'restriction_end': restrictionEnd,
        'restricted_until': restrictionEnd,
        'restrictedBy': restrictedBy,
        'restricted_by': restrictedBy,
        'isRestricted': isRestricted,
        'is_restricted': isRestricted,
        'hasWarning': warningCount > 0 || restrictionStatus == 'warning',
        'has_warning': warningCount > 0 || restrictionStatus == 'warning',
        'isHighRisk': isHighRisk,
        'is_high_risk': isHighRisk,
        'history': list,
      };
    } catch (e) {
      debugPrint('Error getting customer reliability info: $e');
      return {
        'total': 0,
        'completed': 0,
        'confirmed': 0,
        'cancelled': 0,
        'expired': 0,
        'unpaidQuotations': 0,
        'noShows': 0,
        'activeReservations': 0,
        'abandonedBookings': 0,
        'restrictionStatus': 'active',
        'warningCount': 0,
        'isRestricted': false,
        'hasWarning': false,
        'isHighRisk': false,
        'history': <Map<String, dynamic>>[],
      };
    }
  }

  /// Issue an official Warning to a customer
  Future<bool> issueCustomerWarning({
    String? userId,
    String? email,
    String? customerEmail,
    String? customerName,
    required String reason,
    String? adminName,
    String? adminEmail,
    bool sendEmail = true,
  }) async {
    try {
      final effectiveCustomerEmail = (customerEmail ?? email ?? '').trim();
      final effectiveCustomerName = customerName ?? 'Customer';
      final effectiveAdminEmail = adminEmail ?? Supabase.instance.client.auth.currentUser?.email ?? adminName ?? 'Admin';
      final now = DateTime.now();

      // Fetch current warning count
      final userRes = await _supabase
          .from('users')
          .select('warning_count, restriction_status')
          .ilike('email', effectiveCustomerEmail)
          .maybeSingle();

      int currentWarnings = (userRes?['warning_count'] as num?)?.toInt() ?? 0;
      final newWarningCount = currentWarnings + 1;
      final previousStatus = userRes?['restriction_status']?.toString() ?? 'active';

      // Update users table
      await _supabase.from('users').update({
        'warning_count': newWarningCount,
        'restriction_status': 'warning',
        'restriction_reason': reason,
        'restricted_by': effectiveAdminEmail,
        'restriction_start': now.toUtc().toIso8601String(),
      }).ilike('email', effectiveCustomerEmail);

      // Insert into customer_restrictions table
      try {
        await _supabase.from('customer_restrictions').insert({
          'customer_email': effectiveCustomerEmail,
          'customer_name': effectiveCustomerName,
          'action_type': 'warning',
          'previous_status': previousStatus,
          'new_status': 'warning',
          'reason': reason,
          'starts_at': now.toUtc().toIso8601String(),
          'created_by': effectiveAdminEmail,
          'created_at': now.toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Note: customer_restrictions insert fallback: $e');
      }

      // Log in AuditLogService
      await AuditLogService.logActivity(
        action: 'WARNING',
        module: 'Customer Accounts',
        description: 'Admin issued Warning #$newWarningCount to $effectiveCustomerName ($effectiveCustomerEmail). Reason: $reason',
        entityId: effectiveCustomerEmail,
        metadata: {
          'warning_count': newWarningCount,
          'reason': reason,
          'admin': effectiveAdminEmail,
        },
      );

      // Send in-app notification to Customer
      try {
        await NotificationService.sendNotification(
          recipientEmail: effectiveCustomerEmail,
          isForAdmin: false,
          actorName: 'Yang Chow Management',
          actionType: 'account_warning',
          reservationId: 'WARNING_$newWarningCount',
          eventType: 'Account Warning #$newWarningCount: $reason',
          customerEmail: effectiveCustomerEmail,
        );
      } catch (notifErr) {
        debugPrint('Note: In-app warning notification error: $notifErr');
      }

      // Send email notification
      if (sendEmail) {
        await _emailService.sendAccountWarningEmail(
          customerEmail: effectiveCustomerEmail,
          customerName: effectiveCustomerName,
          warningNumber: newWarningCount,
          reason: reason,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error issuing customer warning: $e');
      throw Exception('Failed to issue warning: $e');
    }
  }

  /// Restrict customer account (temporarily_restricted, blocked, suspended)
  Future<bool> restrictCustomerAccount({
    String? userId,
    String? email,
    String? customerEmail,
    String? customerName,
    String? status,
    String? restrictionType,
    dynamic duration,
    int? durationHours,
    int? durationDays,
    required String reason,
    String? adminName,
    String? adminEmail,
    bool sendEmail = true,
  }) async {
    try {
      final effectiveCustomerEmail = (customerEmail ?? email ?? '').trim();
      final effectiveCustomerName = customerName ?? 'Customer';
      final effectiveType = restrictionType ?? status ?? 'temporarily_restricted';
      final effectiveAdminEmail = adminEmail ?? Supabase.instance.client.auth.currentUser?.email ?? adminName ?? 'Admin';

      int? effectiveHours = durationHours;
      int? effectiveDays = durationDays;
      if (duration != null) {
        if (duration is Duration) {
          effectiveHours = duration.inHours;
        } else if (duration is String) {
          if (duration == '24_hours') effectiveHours = 24;
          else if (duration == '3_days') effectiveDays = 3;
          else if (duration == '7_days') effectiveDays = 7;
          else if (duration == '14_days') effectiveDays = 14;
          else if (duration == '30_days') effectiveDays = 30;
        }
      }

      final now = DateTime.now();
      DateTime? expiresAt;

      if (effectiveHours != null && effectiveHours > 0) {
        expiresAt = now.add(Duration(hours: effectiveHours));
      } else if (effectiveDays != null && effectiveDays > 0) {
        expiresAt = now.add(Duration(days: effectiveDays));
      }

      final userRes = await _supabase
          .from('users')
          .select('restriction_status')
          .ilike('email', effectiveCustomerEmail)
          .maybeSingle();

      final previousStatus = userRes?['restriction_status']?.toString() ?? 'active';

      // Update users table
      await _supabase.from('users').update({
        'restriction_status': effectiveType,
        'restriction_reason': reason,
        'restriction_start': now.toUtc().toIso8601String(),
        'restriction_end': expiresAt?.toUtc().toIso8601String(),
        'restricted_by': effectiveAdminEmail,
      }).ilike('email', effectiveCustomerEmail);

      // Insert into customer_restrictions table
      try {
        await _supabase.from('customer_restrictions').insert({
          'customer_email': effectiveCustomerEmail,
          'customer_name': effectiveCustomerName,
          'action_type': effectiveType,
          'previous_status': previousStatus,
          'new_status': effectiveType,
          'reason': reason,
          'duration_days': effectiveDays,
          'duration_hours': effectiveHours,
          'starts_at': now.toUtc().toIso8601String(),
          'expires_at': expiresAt?.toUtc().toIso8601String(),
          'created_by': effectiveAdminEmail,
          'created_at': now.toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Note: customer_restrictions insert fallback: $e');
      }

      // Log in AuditLogService
      await AuditLogService.logActivity(
        action: 'RESTRICT',
        module: 'Customer Accounts',
        description: 'Admin restricted account of $effectiveCustomerName ($effectiveCustomerEmail) to $effectiveType. Reason: $reason',
        entityId: effectiveCustomerEmail,
        metadata: {
          'restriction_type': effectiveType,
          'duration_days': effectiveDays,
          'duration_hours': effectiveHours,
          'expires_at': expiresAt?.toIso8601String(),
          'reason': reason,
          'admin': effectiveAdminEmail,
        },
      );

      // Send in-app notification to Customer
      try {
        await NotificationService.sendNotification(
          recipientEmail: effectiveCustomerEmail,
          isForAdmin: false,
          actorName: 'Yang Chow Management',
          actionType: 'account_restriction',
          reservationId: 'RESTRICTION_${effectiveType.toUpperCase()}',
          eventType: 'Account Restricted (${effectiveType.replaceAll('_', ' ')}): $reason',
          customerEmail: effectiveCustomerEmail,
        );
      } catch (notifErr) {
        debugPrint('Note: In-app restriction notification error: $notifErr');
      }

      // Send email notification
      if (sendEmail) {
        await _emailService.sendAccountRestrictedEmail(
          customerEmail: effectiveCustomerEmail,
          customerName: effectiveCustomerName,
          restrictionType: effectiveType.replaceAll('_', ' ').toUpperCase(),
          reason: reason,
          expiresAt: expiresAt,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error restricting customer account: $e');
      throw Exception('Failed to restrict customer account: $e');
    }
  }

  /// Remove restriction / Unrestrict customer account
  Future<bool> unrestrictCustomerAccount({
    String? userId,
    String? email,
    String? customerEmail,
    String? customerName,
    required String reason,
    String? adminName,
    String? adminEmail,
  }) async {
    try {
      final effectiveCustomerEmail = (customerEmail ?? email ?? '').trim();
      final effectiveCustomerName = customerName ?? 'Customer';
      final effectiveAdminEmail = adminEmail ?? Supabase.instance.client.auth.currentUser?.email ?? adminName ?? 'Admin';
      final now = DateTime.now();

      final userRes = await _supabase
          .from('users')
          .select('restriction_status')
          .ilike('email', effectiveCustomerEmail)
          .maybeSingle();

      final previousStatus = userRes?['restriction_status']?.toString() ?? 'active';

      // Update users table - resets restriction status and clears warning count back to 0
      await _supabase.from('users').update({
        'restriction_status': 'active',
        'warning_count': 0,
        'restriction_reason': null,
        'restriction_start': null,
        'restriction_end': null,
        'restricted_by': effectiveAdminEmail,
      }).ilike('email', effectiveCustomerEmail);

      // Insert into customer_restrictions table
      try {
        await _supabase.from('customer_restrictions').insert({
          'customer_email': effectiveCustomerEmail,
          'customer_name': effectiveCustomerName,
          'action_type': 'unrestrict',
          'previous_status': previousStatus,
          'new_status': 'active',
          'reason': reason,
          'starts_at': now.toUtc().toIso8601String(),
          'created_by': effectiveAdminEmail,
          'created_at': now.toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Note: customer_restrictions insert fallback: $e');
      }

      // Log in AuditLogService
      await AuditLogService.logActivity(
        action: 'UNRESTRICT',
        module: 'Customer Accounts',
        description: 'Admin removed restriction from $effectiveCustomerName ($effectiveCustomerEmail). Reason: $reason',
        entityId: effectiveCustomerEmail,
        metadata: {
          'previous_status': previousStatus,
          'reason': reason,
          'admin': effectiveAdminEmail,
        },
      );

      // Send in-app notification to Customer
      try {
        await NotificationService.sendNotification(
          recipientEmail: effectiveCustomerEmail,
          isForAdmin: false,
          actorName: 'Yang Chow Management',
          actionType: 'account_unrestricted',
          reservationId: 'UNRESTRICTED',
          eventType: 'Your account restriction has been lifted: $reason',
          customerEmail: effectiveCustomerEmail,
        );
      } catch (notifErr) {
        debugPrint('Note: In-app unrestricted notification error: $notifErr');
      }

      // Send email notification to Customer
      try {
        await _emailService.sendAccountUnrestrictedEmail(
          customerEmail: effectiveCustomerEmail,
          customerName: effectiveCustomerName,
          reason: reason,
        );
      } catch (emailErr) {
        debugPrint('Note: Unrestricted email error: $emailErr');
      }

      return true;
    } catch (e) {
      debugPrint('Error unrestricting customer account: $e');
      throw Exception('Failed to unrestrict customer account: $e');
    }
  }

  /// Fetch customer restriction history
  Future<List<Map<String, dynamic>>> getCustomerRestrictionsHistory({
    String? customerEmail,
    String? userId,
    String? email,
  }) async {
    try {
      final targetEmail = (customerEmail ?? email ?? '').trim();
      final query = _supabase
          .from('customer_restrictions')
          .select('*');

      final response = targetEmail.isNotEmpty
          ? await query.ilike('customer_email', targetEmail).order('created_at', ascending: false)
          : await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching customer restrictions history: $e');
      return [];
    }
  }



  /// Update payment status for a reservation or advance order
  Future<bool> updatePaymentStatus({
    required String id,
    required String paymentStatus,
    required String table, // 'reservations' or 'advance_orders'
    double? paymentAmount,
    String? paymentReference,
    String? receiptUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'payment_status': paymentStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      bool wasDepositPaid = false;
      double existingDepositAmount = 0.0;
      if (table == 'reservations') {
        try {
          final res = await getReservation(id);
          if (res != null && res['payment_status'] == 'deposit_paid') {
            wasDepositPaid = true;
            // Capture the original deposit so we can accumulate below
            existingDepositAmount = (res['deposit_amount'] as num?)?.toDouble() ??
                (res['payment_amount'] as num?)?.toDouble() ?? 0.0;
          }
        } catch (_) {}
      }

      if (table == 'reservations') {
        if (paymentReference != null) {
          updates['payment_reference'] = paymentReference;
        }
        if (receiptUrl != null) {
          updates['receipt_url'] = receiptUrl;
        }

        final reservation = await getReservation(id);
        final totalPrice = (reservation?['total_price'] as num?)?.toDouble() ?? 0.0;

        if (wasDepositPaid && paymentAmount != null) {
          // ── REMAINING BALANCE PAYMENT PATH ─────────────────────────────────
          // The customer already has a confirmed deposit. This submission is the
          // remaining balance payment. Do NOT overwrite deposit_amount — instead
          // accumulate: totalPaid = existingDeposit + thisPayment.
          final totalPaid = existingDepositAmount + paymentAmount;
          final isFinalSettlement = totalPrice <= 0 || totalPaid >= totalPrice;

          // Cumulative payment_amount reflects all money paid so far
          updates['payment_amount'] = isFinalSettlement
              ? (totalPrice > 0 ? totalPrice : totalPaid)
              : totalPaid;
          updates['remaining_balance'] = isFinalSettlement
              ? 0
              : (totalPrice - totalPaid).clamp(0.0, double.infinity);
          // Always explicitly store deposit_amount so admin-side can compute the
          // remaining balance receipt amount (total - deposit) even if deposit_amount
          // was null before this update.
          if (existingDepositAmount > 0) {
            updates['deposit_amount'] = existingDepositAmount;
          }

          if (paymentStatus == 'pending_verification') {
            updates['payment_status'] = 'pending_verification';
            updates['status'] = 'pending_admin_approval';
            if (isFinalSettlement) {
              // Signal to admin approval that this completes the full payment
              updates['payment_option'] = 'full';
            }
          }
        } else {
          // ── INITIAL PAYMENT PATH (deposit or one-shot full payment) ─────────
          if (paymentAmount != null) {
            updates['deposit_amount'] = paymentAmount;
            updates['payment_amount'] = paymentAmount;
          }

          final deposit = paymentAmount ??
              (reservation?['deposit_amount'] as num?)?.toDouble() ??
              (reservation?['payment_amount'] as num?)?.toDouble() ?? 0.0;
          // isFull: only based on actual payment amount vs total price.
          // Do NOT include reservation?['payment_option'] == 'full' here — that flag is set
          // by the REMAINING BALANCE path and would falsely trigger isFull on re-submissions,
          // causing deposit_amount to be overwritten to totalPrice (corruption bug).
          final isFull = paymentStatus == 'fully_paid' ||
              paymentStatus == 'paid' ||
              (totalPrice > 0 && deposit >= totalPrice);

          if (paymentStatus == 'pending_verification') {
            updates['payment_status'] = 'pending_verification';
            updates['status'] = 'pending_admin_approval';
            if (isFull) {
              updates['payment_option'] = 'full';
              updates['remaining_balance'] = 0;
              updates['deposit_amount'] = totalPrice > 0 ? totalPrice : deposit;
              updates['payment_amount'] = totalPrice > 0 ? totalPrice : deposit;
            } else {
              updates['remaining_balance'] = (totalPrice > deposit) ? (totalPrice - deposit) : 0;
            }
          } else if (isFull) {
            updates['payment_status'] = 'fully_paid';
            updates['payment_option'] = 'full';
            updates['remaining_balance'] = 0;
            updates['deposit_amount'] = totalPrice > 0 ? totalPrice : deposit;
            updates['payment_amount'] = totalPrice > 0 ? totalPrice : deposit;
            updates['status'] = 'pending_admin_approval';
          } else {
            updates['payment_status'] = 'deposit_paid';
            updates['remaining_balance'] = (totalPrice > deposit) ? (totalPrice - deposit) : 0;
            updates['status'] = 'pending_admin_approval';
          }
        }
      } else {
        // advance_orders: only update payment_status + status, never overwrite total_price
        if (paymentAmount != null) {
          updates['deposit_amount'] = paymentAmount;
        }
        if (paymentReference != null) {
          updates['payment_reference'] = paymentReference;
        }
        if (receiptUrl != null) {
          updates['receipt_url'] = receiptUrl;
        }
        if (paymentStatus == 'paid' || paymentStatus == 'fully_paid' || paymentStatus == 'pending_verification') {
          updates['status'] = 'awaiting_verification'; // Wait for admin
        }
      }

      await _supabase
          .from(table)
          .update(updates)
          .eq('id', id);

      // Send email & in-app notifications — wrapped in try-catch so a failed notification
      // never causes the payment update to report failure to the customer.
      try {
        final currentUser = _supabase.auth.currentUser;
        final actorName = currentUser?.userMetadata?['name'] ??
            currentUser?.email?.split('@')[0] ??
            'Customer';

        if (table == 'reservations') {
          final reservation = await getReservation(id);
          if (reservation != null) {
            // Determine action type and text based on effective status
            final effectiveStatus = updates['payment_status'] ?? paymentStatus;
            String actionType = 'paid';
            String eventPrefix = '';
            if (effectiveStatus == 'deposit_paid') {
              actionType = 'deposit_paid';
              eventPrefix = '(Deposit Paid) ';
            } else if (effectiveStatus == 'fully_paid' || effectiveStatus == 'paid') {
              if (wasDepositPaid) {
                actionType = 'balance_cleared';
                eventPrefix = '(Remaining Balance Paid) ';
              } else {
                actionType = 'fully_paid';
                eventPrefix = '(Fully Paid) ';
              }
            }

            // Notify admins about the payment
            await NotificationService.sendNotification(
              isForAdmin: true,
              actorName: actorName,
              actionType: actionType,
              reservationId: id,
              customerEmail: reservation['customer_email'],
              eventType: '$eventPrefix${reservation['event_type']}',
              eventDate: reservation['event_date'],
              startTime: reservation['start_time'],
              guestCount: reservation['number_of_guests'],
            );

            // Log activity to Audit Trail
            final shortRef = id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
            final eventName = reservation['event_type'] ?? 'Reservation';
            final custName = reservation['customer_name'] ?? actorName;
            String auditDesc = '';
            if (actionType == 'balance_cleared') {
              auditDesc = 'Customer $custName paid remaining balance for Reservation #$shortRef ($eventName)';
            } else if (actionType == 'deposit_paid') {
              auditDesc = 'Customer $custName paid 50% deposit for Reservation #$shortRef ($eventName)';
            } else if (actionType == 'fully_paid') {
              auditDesc = 'Customer $custName completed full payment for Reservation #$shortRef ($eventName)';
            } else {
              auditDesc = 'Payment received from $custName for Reservation #$shortRef ($eventName)';
            }

            await AuditLogService.logActivity(
              action: 'PAYMENT',
              module: 'Payments',
              description: auditDesc,
              entityId: id,
              customUserEmail: reservation['customer_email'],
              customUserName: custName,
              customUserRole: 'CUSTOMER',
              metadata: {
                'reservation_id': id,
                'payment_status': effectiveStatus,
                'payment_reference': paymentReference,
                'amount': paymentAmount,
                'event_type': reservation['event_type'],
              },
            );

            if (effectiveStatus == 'deposit_paid') {
              await _emailService.sendDepositPaymentConfirmation(
                customerEmail: reservation['customer_email'],
                customerName: reservation['customer_name'],
                eventType: reservation['event_type'],
                eventDate: reservation['event_date'],
                depositAmount:
                    paymentAmount ?? reservation['deposit_amount'] ?? 0.0,
              );
            } else if (effectiveStatus == 'fully_paid' || effectiveStatus == 'paid') {
              await _emailService.sendFullPaymentConfirmation(
                customerEmail: reservation['customer_email'],
                customerName: reservation['customer_name'],
                eventType: reservation['event_type'],
                eventDate: reservation['event_date'],
                totalAmount: paymentAmount ?? reservation['total_price'] ?? 0.0,
              );
            }
          }
        } else {
          final response = await _supabase
              .from('advance_orders')
              .select()
              .eq('id', id)
              .single();

          // Notify admins about the advance order payment (which is always a full payment)
          await NotificationService.sendNotification(
            isForAdmin: true,
            actorName: actorName,
            actionType: 'fully_paid',
            reservationId: id,
            customerEmail: response['customer_email'],
            eventType: '(Fully Paid) Advance Order (${response['order_type']})',
            eventDate: response['order_date'],
            startTime: response['order_time'],
            guestCount: response['number_of_guests'],
          );

          // Log advance order payment to Audit Trail
          final shortRef = id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
          final custName = response['customer_name'] ?? actorName;
          await AuditLogService.logActivity(
            action: 'PAYMENT',
            module: 'Payments',
            description: 'Customer $custName completed payment for Advance Order #$shortRef (${response['order_type'] ?? 'Takeout'})',
            entityId: id,
            customUserEmail: response['customer_email'],
            customUserName: custName,
            customUserRole: 'CUSTOMER',
            metadata: {
              'order_id': id,
              'order_type': response['order_type'],
              'total_price': response['total_price'],
            },
          );

          if (paymentStatus == 'paid' || paymentStatus == 'fully_paid') {
            await _emailService.sendFullPaymentConfirmation(
              customerEmail: response['customer_email'],
              customerName: response['customer_name'],
              eventType: 'Advance Order (${response['order_type']})',
              eventDate: response['order_date'],
              totalAmount: response['total_price']?.toDouble() ?? 0.0,
            );
          }
        }
      } catch (notifError) {
        // Log but do not rethrow — the DB update succeeded, payment is recorded.
        debugPrint('Warning: payment notification failed: $notifError');
      }

      return true;
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      throw Exception('Failed to update payment status: $e');
    }
  }



  /// Get pricing breakdown for a reservation

  Map<String, dynamic> getReservationPricing(Map<String, dynamic> reservation) {

    final durationHours = reservation['duration_hours'] as int? ?? 0;

    final numberOfGuests = reservation['number_of_guests'] as int? ?? 0;

    final totalPrice = reservation['total_price'] as double? ?? 0.0;

    final depositAmount = reservation['deposit_amount'] as double? ?? 0.0;

    final paymentStatus = reservation['payment_status'] as String? ?? 'unpaid';



    // Calculate suggested pricing if not set by admin

    if (totalPrice == 0.0 && durationHours > 0 && numberOfGuests > 0) {

      final suggestedPrice = _pricingService.calculateTotalPrice(

        durationHours: durationHours,

        numberOfGuests: numberOfGuests,

      );

      final suggestedDeposit = _pricingService.calculateDepositAmount(suggestedPrice);



      return {

        'totalPrice': suggestedPrice,

        'depositAmount': suggestedDeposit,

        'paymentStatus': paymentStatus,

        'remainingBalance': suggestedPrice - suggestedDeposit,

        'isPricingSet': false,

        'pricingBreakdown': _pricingService.getPricingBreakdown(

          durationHours: durationHours,

          numberOfGuests: numberOfGuests,

        ),

      };

    }



    return {

      'totalPrice': totalPrice,

      'depositAmount': depositAmount,

      'paymentStatus': paymentStatus,

      'remainingBalance': totalPrice - depositAmount,

      'isPricingSet': true,

      'pricingBreakdown': _pricingService.getPricingBreakdown(

        durationHours: durationHours,

        numberOfGuests: numberOfGuests,

        customBaseRate: _calculateBaseRate(totalPrice, durationHours, numberOfGuests),

      ),

    };

  }



  /// Calculate the effective base rate from total price

  double _calculateBaseRate(double totalPrice, int durationHours, int numberOfGuests) {

    if (durationHours == 0 || numberOfGuests == 0) return 500.0; // Default base rate

    

    // Use the pricing breakdown to reverse-calculate the base rate

    final breakdown = _pricingService.getPricingBreakdown(

      durationHours: durationHours,

      numberOfGuests: numberOfGuests,

    );

    

    final guestPremium = breakdown['guestPremium'] as double;

    final durationMultiplier = breakdown['durationMultiplier'] as double;

    

    return (totalPrice - guestPremium) / (durationHours * durationMultiplier);

  }



  /// Check if reservation needs pricing

  bool needsPricing(Map<String, dynamic> reservation) {

    final totalPrice = reservation['total_price'] as double? ?? 0.0;

    final adminSetPrice = reservation['admin_set_price'] as bool? ?? false;

    final status = reservation['status'] as String? ?? 'pending';

    

    return status == 'pending' && !adminSetPrice && totalPrice == 0.0;

  }



  /// Check if reservation needs deposit payment

  bool needsDepositPayment(Map<String, dynamic> reservation) {
    final status = (reservation['status'] as String? ?? 'pending').toLowerCase();
    if (status == 'confirmed' || status == 'completed' || status == 'cancelled' || status == 'expired') {
      return false;
    }

    final paymentStatus = reservation['payment_status'] as String? ?? 'unpaid';
    final priceQuotationSent = reservation['price_quotation_sent'] as bool? ?? false;
    final totalPrice = reservation['total_price'] as double? ?? 0.0;

    return priceQuotationSent && 
           totalPrice > 0.0 && 
           paymentStatus == 'unpaid';
  }



  /// Check if a time slot is already booked for a given date

  Future<bool> isTimeSlotOverlapping({

    required String eventDate,

    required String startTime,

    required double durationHours,

    String? excludeReservationId,

  }) async {

    try {

      // 1. Fetch all non-cancelled and non-expired reservations for that date
      final response = await _supabase
          .from('reservations')
          .select('id, start_time, duration_hours, status')
          .eq('event_date', eventDate);

      final List<Map<String, dynamic>> existingReservations = 
          List<Map<String, dynamic>>.from(response)
              .where((r) => r['status'] != 'cancelled' && r['status'] != 'expired')
              .toList();



      // 2. Parse requested time slot

      final DateTime requestedStart = _parseTime(startTime);

      final DateTime requestedEnd = requestedStart.add(

        Duration(minutes: (durationHours * 60).toInt()),

      );



      // 3. Check for overlaps

      for (var res in existingReservations) {

        // Skip if it's the same reservation (useful for rescheduling)

        if (excludeReservationId != null && res['id'].toString() == excludeReservationId) {

          continue;

        }



        final String existingStartTimeStr = res['start_time'] ?? '';

        final double existingDuration = (res['duration_hours'] as num?)?.toDouble() ?? 0.0;



        if (existingStartTimeStr.isEmpty || existingDuration <= 0) continue;



        final DateTime existingStart = _parseTime(existingStartTimeStr);

        final DateTime existingEnd = existingStart.add(

          Duration(minutes: (existingDuration * 60).toInt()),

        );



        // Overlap condition: (StartA < EndB) && (EndA > StartB)

        if (requestedStart.isBefore(existingEnd) && requestedEnd.isAfter(existingStart)) {

          return true; // Overlap found

        }

      }



      return false; // No overlap
    } catch (e) {
      debugPrint('Error checking time slot overlap: $e');
      return false; // Fallback to allow if error occurs
    }
  }

  /// Read-only helper to fetch active (non-cancelled, non-expired) reservations for a given date
  /// Used for UI preview. Does not alter any booking or validation logic.
  Future<List<Map<String, dynamic>>> getBookingsForDate(String eventDate) async {
    try {
      final response = await _supabase
          .from('reservations')
          .select('id, start_time, duration_hours, status, event_type')
          .eq('event_date', eventDate);

      return List<Map<String, dynamic>>.from(response)
          .where((r) => r['status'] != 'cancelled' && r['status'] != 'expired')
          .toList();
    } catch (e) {
      debugPrint('Error getting bookings for date $eventDate: $e');
      return [];
    }
  }

  /// Get dates that are fully booked for Event Place reservations
  Future<Set<String>> getFullyBookedEventDates() async {
    try {
      final response = await _supabase
          .from('reservations')
          .select('event_date, start_time, duration_hours, status');

      final List<Map<String, dynamic>> reservations =
          List<Map<String, dynamic>>.from(response)
              .where((r) => r['status'] != 'cancelled' && r['status'] != 'expired')
              .toList();

      // Group reservations by event_date
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var r in reservations) {
        final date = r['event_date']?.toString();
        if (date != null && date.isNotEmpty) {
          grouped.putIfAbsent(date, () => []).add(r);
        }
      }

      final Set<String> fullyBookedDates = {};

      for (var entry in grouped.entries) {
        final date = entry.key;
        final list = entry.value;

        // Calculate total booked hours on that date
        double totalBookedHours = 0;
        for (var res in list) {
          final duration = (res['duration_hours'] as num?)?.toDouble() ?? 0.0;
          totalBookedHours += duration;
        }

        // Operating hours range: 10:00 AM to 9:00 PM (11 hours total)
        // If booked hours >= 8 hours, mark date as fully booked
        if (totalBookedHours >= 8.0) {
          fullyBookedDates.add(date);
        }
      }

      return fullyBookedDates;
    } catch (e) {
      debugPrint('Error getting fully booked dates: $e');
      return {};
    }
  }



  /// Helper to parse time strings like "10:00 AM", "2:30 PM", or "16:00:00"
  DateTime _parseTime(String timeStr) {
    final cleanStr = timeStr.trim().replaceAll('\u202F', ' ').replaceAll('\u00A0', ' ');
    final now = DateTime.now();

    // Check for 24-hour SQL format (e.g. "16:00:00", "16:00", "09:30")
    final match24 = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(cleanStr);
    if (match24 != null) {
      final hour = int.tryParse(match24.group(1)!) ?? 0;
      final minute = int.tryParse(match24.group(2)!) ?? 0;
      return DateTime(now.year, now.month, now.day, hour, minute);
    }

    // Check for 12-hour AM/PM format (e.g. "1:00 PM", "10:30 AM")
    final match12 = RegExp(r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$', caseSensitive: false).firstMatch(cleanStr);
    if (match12 != null) {
      int hour = int.tryParse(match12.group(1)!) ?? 0;
      final minute = int.tryParse(match12.group(2)!) ?? 0;
      final period = match12.group(3)?.toUpperCase();
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return DateTime(now.year, now.month, now.day, hour, minute);
    }

    try {
      final DateFormat timeFormat = DateFormat.jm();
      final DateTime parsed = timeFormat.parse(cleanStr);
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    } catch (_) {
      // Fallback
      final parts = cleanStr.split(RegExp(r'[\s:]+'));
      if (parts.isNotEmpty) {
        int hour = int.tryParse(parts[0]) ?? 0;
        int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        final isPM = cleanStr.toUpperCase().contains('PM');
        final isAM = cleanStr.toUpperCase().contains('AM');
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
      return DateTime.now();
    }
  }




  /// Get reservations that need pricing (for admin dashboard)

  Future<List<Map<String, dynamic>>> getReservationsNeedingPricing() async {

    try {

      final response = await _supabase

          .from('reservations')

          .select('*')

          .eq('status', 'pending')

          .eq('admin_set_price', false)

          .eq('is_archived', false)

          .order('created_at', ascending: false);



      return List<Map<String, dynamic>>.from(response);

    } catch (e) {

      debugPrint('Error fetching reservations needing pricing: $e');

      return [];

    }

  }



  /// Get reservations with pending payments

  Future<List<Map<String, dynamic>>> getReservationsWithPendingPayments() async {

    try {

      final response = await _supabase

          .from('reservations')

          .select('*')

          .eq('price_quotation_sent', true)

          .eq('payment_status', 'unpaid')

          .neq('total_price', 0)

          .eq('is_archived', false)

          .order('created_at', ascending: false);



      return List<Map<String, dynamic>>.from(response);

    } catch (e) {

      debugPrint('Error fetching reservations with pending payments: $e');

      return [];

    }

  }



  /// Get reservations pending admin approval
  Future<List<Map<String, dynamic>>> getReservationsPendingApproval() async {
    try {
      final response = await _supabase
          .from('reservations')
          .select('*')
          .inFilter('status', ['pending_admin_approval', 'awaiting_verification'])
          .inFilter('payment_status', ['deposit_paid', 'fully_paid', 'pending_verification'])
          .eq('is_archived', false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching reservations pending approval: $e');
      return [];
    }
  }

  /// Get advance orders pending admin approval (both online verifying receipts and cash on site)
  Future<List<Map<String, dynamic>>> getAdvanceOrdersPendingApproval() async {
    try {
      final response = await _supabase
          .from('advance_orders')
          .select('*')
          .or('and(status.eq.awaiting_verification,payment_status.eq.pending_verification),and(payment_method.eq.cash,status.eq.unpaid,payment_status.eq.unpaid)')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching advance orders pending approval: $e');
      return [];
    }
  }

  /// Approve pending payment (admin action)
  Future<bool> approvePendingPayment({
    required String id,
    String table = 'reservations',
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (table == 'reservations') {
        final reservation = await getReservation(id);
        if (reservation != null) {
          final totalPrice = (reservation['total_price'] as num?)?.toDouble() ?? 0.0;
          final deposit = (reservation['deposit_amount'] as num?)?.toDouble() ?? (reservation['payment_amount'] as num?)?.toDouble() ?? 0.0;
          // Use DB-stored remaining_balance as primary source for accuracy
          final storedRemaining = (reservation['remaining_balance'] as num?)?.toDouble();

          // isFull requires payment_option == 'full' with sufficient deposit amount,
          // OR the record was already marked fully_paid by a prior approval.
          // 'paid' alone (pre-verification state) is NOT sufficient to mark as fully paid.
          // totalPaid tracks cumulative money received (deposit + any balance payments)
          final totalPaid = (reservation['payment_amount'] as num?)?.toDouble() ?? deposit;

          // isFull when:
          //   1. Already explicitly marked fully_paid, OR
          //   2. payment_option is 'full' (set by both initial full-pay and balance payment paths), OR
          //   3. remaining_balance was cleared to 0 (set by the balance payment accumulation path), OR
          //   4. cumulative payment_amount covers the total
          final isFull = reservation['payment_status'] == 'fully_paid' ||
              reservation['payment_option'] == 'full' ||
              (storedRemaining != null && storedRemaining <= 0 && totalPrice > 0) ||
              (totalPrice > 0 && totalPaid >= totalPrice);

          if (isFull) {
            updates['payment_status'] = 'fully_paid';
            updates['payment_option'] = 'full';
            updates['remaining_balance'] = 0;
          } else {
            updates['payment_status'] = 'deposit_paid';
            // Prefer DB-stored remaining_balance; fall back to computed value
            final computedRemaining = (totalPrice > deposit) ? (totalPrice - deposit) : 0.0;
            updates['remaining_balance'] = (storedRemaining != null && storedRemaining > 0)
                ? storedRemaining
                : computedRemaining;
          }
        }
        updates['status'] = 'confirmed';
      } else {
        updates['status'] = 'pending'; // To kitchen
        updates['payment_status'] = 'paid';
      }

      await _supabase
          .from(table)
          .update(updates)
          .eq('id', id);

      // Send notifications
      try {
        final record = await (table == 'reservations' 
            ? getReservation(id) 
            : _supabase.from('advance_orders').select().eq('id', id).single());
            
        if (record != null) {
          // 1. Notify Customer
          await NotificationService.sendNotification(
            recipientEmail: record['customer_email'],
            isForAdmin: false,
            actorName: 'Admin',
            actionType: 'paid', // Shows the payment icon
            reservationId: id,
            eventType: table == 'reservations' ? record['event_type'] : 'Advance Order (${record['order_type']})',
            eventDate: table == 'reservations' ? record['event_date'] : record['order_date'],
            startTime: table == 'reservations' ? record['start_time'] : record['order_time'],
            guestCount: record['number_of_guests'],
          );

          // 2. Notify Kitchen if advance order or menu-based event reservation
          bool isForKitchen = false;
          String kitchenEventType = '';
          
          if (table == 'advance_orders') {
            isForKitchen = true;
            kitchenEventType = 'Advance Order Menu Ticket: ${record['order_type']} on ${record['order_date']} at ${record['order_time']}';
          } else if (table == 'reservations' && record['is_menu_based'] == true) {
            isForKitchen = true;
            kitchenEventType = 'Event Reservation Menu Ticket: ${record['event_type']} on ${record['event_date']} at ${record['start_time']}';
          }
          
          if (isForKitchen) {
            await NotificationService.sendNotification(
              isForAdmin: true,
              actorName: 'System',
              actionType: 'advance_order_ticket',
              reservationId: 'Kitchen', // strictly routed to Kitchen
              eventType: kitchenEventType,
              customerEmail: record['customer_email'],
              startTime: table == 'reservations' ? record['start_time'] : record['order_time'],
              guestCount: record['number_of_guests'],
              eventDate: table == 'reservations' ? record['event_date'] : record['order_date'],
            );
          }
        }
      } catch (e) {
        debugPrint('Warning: payment approval notification failed: $e');
      }

      return true;
    } catch (e) {
      debugPrint('Error approving pending payment: $e');
      return false;
    }
  }

  /// Reject pending payment (admin action)
  Future<bool> rejectPendingPayment({
    required String id,
    String table = 'reservations',
    String? reason,
  }) async {
    try {
      final updates = <String, dynamic>{
        'payment_status': 'rejected',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (table == 'reservations') {
        updates['status'] = 'payment_rejected';
        updates['admin_notes'] = reason ?? 'Payment rejected by admin';
      } else {
        updates['status'] = 'cancelled';
        updates['preparation_notes'] = reason != null 
            ? 'REJECTED: $reason' 
            : 'REJECTED: Payment verification failed';
      }

      await _supabase
          .from(table)
          .update(updates)
          .eq('id', id);

      // Send notification to customer
      try {
        final record = await (table == 'reservations' 
            ? getReservation(id) 
            : _supabase.from('advance_orders').select().eq('id', id).single());
            
        if (record != null) {
          await NotificationService.sendNotification(
            recipientEmail: record['customer_email'],
            isForAdmin: false,
            actorName: 'Admin',
            actionType: 'rejected',
            reservationId: id,
            eventType: table == 'reservations' ? record['event_type'] : 'Advance Order (${record['order_type']})',
            eventDate: table == 'reservations' ? record['event_date'] : record['order_date'],
            startTime: table == 'reservations' ? record['start_time'] : record['order_time'],
            guestCount: record['number_of_guests'],
          );
        }
      } catch (e) {
        debugPrint('Warning: customer notification failed: $e');
      }

      return true;
    } catch (e) {
      debugPrint('Error rejecting pending payment: $e');
      return false;
    }
  }

  /// Get total count of completed reservations
  Future<int> getCompletedReservationsCount() async {
    try {
      final response = await _supabase
          .from('reservations')
          .select('id')
          .eq('status', 'completed')
          .count(CountOption.exact);
          
      return response.count;
    } catch (e) {
      debugPrint('Error counting completed reservations: $e');
      return 0;
    }
  }
}

