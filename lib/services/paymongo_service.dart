import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PayMongoService {
  static final _supabase = Supabase.instance.client;

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'PHP ',
  );

  static String formatAmount(double amount) {
    return _currencyFormat.format(amount);
  }

  static String generateReferenceNumber() {
    final now = DateTime.now();
    final random = (1000 + (now.microsecond % 9000)).toString();
    return 'YC-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  /// Create a payment link via Supabase RPC (Secure & CORS-friendly)
  static Future<Map<String, dynamic>> createPaymentLink({
    required double amount,
    required String description,
    String? returnUrl,
    String? cancelUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // ALWAYS use Supabase RPC to avoid CORS and hide the secret key
      final response = await _supabase.rpc(
        'create_paymongo_link',
        params: {
          'p_amount': amount,
          'p_description': description,
          'p_metadata': metadata ?? {},
        },
      );

      final checkoutUrl =
          response['data']?['attributes']?['checkout_url'] ??
          response['data']?['attributes']?['url'];

      if (checkoutUrl == null) {
        throw Exception('No checkout URL returned from PayMongo');
      }

      return {
        'success': true,
        'checkoutUrl': checkoutUrl,
        'data': response,
      };
    } catch (e) {
      debugPrint('Payment link creation failed via RPC: $e');
      throw Exception('Payment link creation failed: $e');
    }
  }

  /// Retrieve payment link status via Supabase RPC (Secure & CORS-friendly)
  static Future<Map<String, dynamic>> retrievePaymentLink(String linkId) async {
    try {
      final response = await _supabase.rpc(
        'retrieve_paymongo_link',
        params: {
          'p_link_id': linkId,
        },
      );

      // DEBUG: Print the whole response to see what PayMongo is sending
      debugPrint('--- PAYMONGO RPC DEBUG ---');
      debugPrint(jsonEncode(response));
      
      final attributes = response['data']?['attributes'];
      final status = attributes?['status'];
      
      // Handle both List and Map (Expanded) formats for payments
      final paymentsRaw = attributes?['payments'];
      List<dynamic> paymentList = [];
      if (paymentsRaw is List) {
        paymentList = paymentsRaw;
      } else if (paymentsRaw is Map && paymentsRaw['data'] is List) {
        paymentList = paymentsRaw['data'];
      }

      debugPrint('Link Status from PayMongo: $status');
      debugPrint('Number of payments found: ${paymentList.length}');
      
      // A link is paid if:
      // 1. Status is 'completed' or 'paid'
      // 2. OR it has at least one payment record that is 'paid' or 'completed'
      bool hasPaidPayment = false;
      for (var p in paymentList) {
        final pStatus = p['attributes']?['status'];
        debugPrint('Checking payment ID ${p['id']}: $pStatus');
        if (pStatus == 'paid' || pStatus == 'completed') {
          hasPaidPayment = true;
          break;
        }
      }

      bool isPaid = (status == 'completed' || status == 'paid') || hasPaidPayment;

      return {'success': true, 'isPaid': isPaid, 'data': response};
    } catch (e) {
      debugPrint('Payment link retrieval failed via RPC: $e');
      throw Exception('Payment link retrieval failed: $e');
    }
  }
}
