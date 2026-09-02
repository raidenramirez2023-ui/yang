import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yang_chow/services/email_notification_service.dart';

import 'package:yang_chow/services/pricing_service.dart';
import 'package:yang_chow/services/notification_service.dart';
import 'package:yang_chow/services/refund_service.dart';
import 'package:yang_chow/services/audit_log_service.dart';



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
    String? transactedBy,
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
            'uploaded_id_url': uploadedIdUrl,
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
    String? transactedBy,
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

            'uploaded_id_url': uploadedIdUrl,
            'transacted_by': transactedBy,

            'created_at': now.toUtc().toIso8601String(),

            'updated_at': now.toUtc().toIso8601String(),

            // Menu-based pricing fields

            'total_price': totalMenuPrice,

            'deposit_amount': depositAmount,

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
    required String? reviewText,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _supabase.from('reviews').upsert({
        'reservation_id': reservationId,
        'customer_email': customerEmail,
        'rating': overallRating,
        'food_quality': foodQuality,
        'service_quality': serviceQuality,
        'ambiance': ambiance,
        'review_text': reviewText,
        'updated_at': now,
      }, onConflict: 'customer_email');

      return true;
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

  /// Check if a customer is eligible to leave a review (has at least one completed reservation)
  Future<bool> isEligibleForReview(String customerEmail) async {
    try {
      final reservations = await getCustomerReservations(customerEmail);
      final advanceOrders = await getCustomerAdvanceOrders(customerEmail);
      
      final hasCompletedRes = reservations.any((r) => r['status'] == 'completed');
      final hasCompletedAdv = advanceOrders.any((o) => o['status'] == 'done' || o['status'] == 'completed');
      
      return hasCompletedRes || hasCompletedAdv;
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



  /// Set pricing for a reservation and send quotation

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

  }) async {

    try {

      final now = DateTime.now();
      final currentUser = _supabase.auth.currentUser;
      final adminIdentifier = currentUser?.email ?? 'Admin';

      // Update reservation with pricing details

      await _supabase

          .from('reservations')

          .update({

            'total_price': totalPrice,

            'deposit_amount': depositAmount,

            'payment_status': 'unpaid',

            'price_quotation_sent': true,

            'price_quotation_sent_at': now.toUtc().toIso8601String(),

            'admin_set_price': true,

            'transacted_by': adminIdentifier,

            'updated_at': now.toUtc().toIso8601String(),

          })

          .eq('id', reservationId);



      // Send price quotation email

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

  /// Get reliability metrics and no-show count for a customer by email
  Future<Map<String, dynamic>> getCustomerReliabilityInfo(String customerEmail) async {
    try {
      if (customerEmail.isEmpty) {
        return {
          'total': 0,
          'noShows': 0,
          'completed': 0,
          'cancelled': 0,
          'isHighRisk': false,
          'hasWarning': false,
        };
      }
      final res = await _supabase
          .from('reservations')
          .select('id, status')
          .eq('customer_email', customerEmail.trim());

      final list = List<Map<String, dynamic>>.from(res);
      final total = list.length;
      final noShows = list.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'no_show').length;
      final completed = list.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'completed').length;
      final cancelled = list.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'cancelled').length;

      return {
        'total': total,
        'noShows': noShows,
        'completed': completed,
        'cancelled': cancelled,
        'isHighRisk': noShows >= 2,
        'hasWarning': noShows == 1,
      };
    } catch (e) {
      debugPrint('Error getting customer reliability info: $e');
      return {
        'total': 0,
        'noShows': 0,
        'completed': 0,
        'cancelled': 0,
        'isHighRisk': false,
        'hasWarning': false,
      };
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
      if (table == 'reservations') {
        try {
          final res = await getReservation(id);
          if (res != null && res['payment_status'] == 'deposit_paid') {
            wasDepositPaid = true;
          }
        } catch (_) {}
      }

      if (table == 'reservations') {
        // Only write reservation-specific columns
        if (paymentAmount != null) {
          updates['deposit_amount'] = paymentAmount;
          updates['payment_amount'] = paymentAmount;
        }
        if (paymentReference != null) {
          updates['payment_reference'] = paymentReference;
        }
        if (receiptUrl != null) {
          updates['receipt_url'] = receiptUrl;
        }

        final reservation = await getReservation(id);
        final totalPrice = (reservation?['total_price'] as num?)?.toDouble() ?? 0.0;
        final deposit = paymentAmount ?? (reservation?['deposit_amount'] as num?)?.toDouble() ?? (reservation?['payment_amount'] as num?)?.toDouble() ?? 0.0;
        final isFull = paymentStatus == 'fully_paid' || 
            paymentStatus == 'paid' || 
            (totalPrice > 0 && deposit >= totalPrice) || 
            reservation?['payment_option'] == 'full';

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

      // 1. Fetch all non-cancelled reservations for that date

      final response = await _supabase

          .from('reservations')

          .select('id, start_time, duration_hours')

          .eq('event_date', eventDate)

          .not('status', 'eq', 'cancelled');



      final List<Map<String, dynamic>> existingReservations = 

          List<Map<String, dynamic>>.from(response);



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

  /// Get dates that are fully booked for Event Place reservations
  Future<Set<String>> getFullyBookedEventDates() async {
    try {
      final response = await _supabase
          .from('reservations')
          .select('event_date, start_time, duration_hours')
          .not('status', 'eq', 'cancelled');

      final List<Map<String, dynamic>> reservations =
          List<Map<String, dynamic>>.from(response);

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



  /// Helper to parse time strings like "10:00 AM" or "2:30 PM"

  DateTime _parseTime(String timeStr) {

    try {

      final DateFormat timeFormat = DateFormat.jm(); // Matches "10:00 AM"

      final DateTime parsed = timeFormat.parse(timeStr);

      final DateTime now = DateTime.now();

      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);

    } catch (e) {

      debugPrint('Error parsing time string "$timeStr": $e');

      // Fallback: try manual parsing if DateFormat fails

      final parts = timeStr.split(' ');

      if (parts.length >= 1) {

        final timeParts = parts[0].split(':');

        int hour = int.tryParse(timeParts[0]) ?? 0;

        int minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;

        

        if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {

          hour += 12;

        } else if (parts.length > 1 && parts[1].toUpperCase() == 'AM' && hour == 12) {

          hour = 0;

        }

        

        final now = DateTime.now();

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

  /// Get advance orders pending admin approval
  Future<List<Map<String, dynamic>>> getAdvanceOrdersPendingApproval() async {
    try {
      final response = await _supabase
          .from('advance_orders')
          .select('*')
          .eq('status', 'awaiting_verification')
          .eq('payment_status', 'pending_verification')
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
          final isFull = reservation['payment_status'] == 'fully_paid' ||
              reservation['payment_status'] == 'paid' ||
              reservation['payment_option'] == 'full' ||
              (totalPrice > 0 && deposit >= totalPrice);

          if (isFull) {
            updates['payment_status'] = 'fully_paid';
            updates['payment_option'] = 'full';
            updates['remaining_balance'] = 0;
          } else {
            updates['payment_status'] = 'deposit_paid';
            updates['remaining_balance'] = (totalPrice > deposit) ? (totalPrice - deposit) : 0;
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

