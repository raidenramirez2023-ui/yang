import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yang_chow/services/app_settings_service.dart';

import 'package:yang_chow/services/email_notification_service.dart';

import 'package:yang_chow/services/pricing_service.dart';



/// Service to manage reservation operations (create, cancel, reschedule, etc.)

class ReservationService {

  static final ReservationService _instance = ReservationService._internal();

  static final SupabaseClient _supabase = Supabase.instance.client;

  static final AppSettingsService _appSettings = AppSettingsService();

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
      final now = DateTime.now().toIso8601String();
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
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
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
      
      double? refundAmount;
      if (paymentStatus == 'paid' || paymentStatus == 'fully_paid') {
        refundAmount = _calculateRefundAmount(
          eventDate: orderDate,
          paymentAmount: totalPrice,
        );
      }

      await _supabase
          .from('advance_orders')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
            'refund_amount': refundAmount,
          })
          .eq('id', orderId);

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



      // Update reservation with pricing details

      await _supabase

          .from('reservations')

          .update({

            'total_price': totalPrice,

            'deposit_amount': depositAmount,

            'payment_status': 'unpaid',

            'price_quotation_sent': true,

            'price_quotation_sent_at': now.toIso8601String(),

            'admin_set_price': true,

            'updated_at': now.toIso8601String(),

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

            'updated_at': DateTime.now().toIso8601String(),

          })

          .eq('id', reservationId);



      return true;

    } catch (e) {

      debugPrint('Error updating reservation status: $e');

      return false;

    }

  }



  /// Update payment status for a reservation or advance order
  Future<bool> updatePaymentStatus({
    required String id,
    required String paymentStatus,
    required String table, // 'reservations' or 'advance_orders'
    double? paymentAmount,
    String? paymentReference,
  }) async {
    try {
      final updates = <String, dynamic>{
        'payment_status': paymentStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (table == 'reservations') {
        // Only write reservation-specific columns
        if (paymentAmount != null) {
          updates['deposit_amount'] = paymentAmount;
          updates['payment_amount'] = paymentAmount;
        }
        if (paymentReference != null) {
          updates['payment_reference'] = paymentReference;
        }
        // Set status to pending admin approval on deposit paid
        if (paymentStatus == 'deposit_paid') {
          updates['status'] = 'pending_admin_approval';
        }
      } else {
        // advance_orders: only update payment_status + status, never overwrite total_price
        if (paymentStatus == 'paid' || paymentStatus == 'fully_paid') {
          updates['status'] = 'pending'; // Send to kitchen
        } else if (paymentStatus == 'pending_verification') {
          updates['status'] = 'awaiting_verification'; // Wait for admin
        }
      }

      await _supabase
          .from(table)
          .update(updates)
          .eq('id', id);

      // Send email notifications — wrapped in try-catch so a failed email
      // never causes the payment update to report failure to the customer.
      try {
        if (table == 'reservations') {
          final reservation = await getReservation(id);
          if (reservation != null) {
            if (paymentStatus == 'deposit_paid') {
              await _emailService.sendDepositPaymentConfirmation(
                customerEmail: reservation['customer_email'],
                customerName: reservation['customer_name'],
                eventType: reservation['event_type'],
                eventDate: reservation['event_date'],
                depositAmount: paymentAmount ?? reservation['deposit_amount'] ?? 0.0,
              );
            } else if (paymentStatus == 'fully_paid') {
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
      } catch (emailError) {
        // Log but do not rethrow — the DB update succeeded, payment is recorded.
        debugPrint('Warning: payment notification email failed: $emailError');
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
          .eq('status', 'pending_admin_approval')
          .eq('payment_status', 'deposit_paid')
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
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (table == 'reservations') {
        updates['status'] = 'confirmed';
      } else {
        updates['status'] = 'pending'; // To kitchen
        updates['payment_status'] = 'paid';
      }

      await _supabase
          .from(table)
          .update(updates)
          .eq('id', id);

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
        'updated_at': DateTime.now().toIso8601String(),
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

