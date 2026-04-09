import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';



class PayMongoService {

  static const String _baseUrl = 'https://api.paymongo.com/v1';

  

  static String get _publicKey => dotenv.env['PAYMONGO_PUBLIC_KEY'] ?? '';

  static String get _secretKey => dotenv.env['PAYMONGO_SECRET_KEY'] ?? '';



  static const Map<String, String> _headers = {

    'Content-Type': 'application/json',

    'Accept': 'application/json',

  };



  // Create a payment link

  static Future<Map<String, dynamic>> createPaymentLink({

    required double amount,

    required String description,

    String? returnUrl,

    String? cancelUrl,

    Map<String, dynamic>? metadata,

  }) async {

    try {

      // Use provided URLs or default to deep links (handled by PaymentPage for Web)

      final successUrl = returnUrl ?? 'yangchow://payment/success';

      final failedUrl = cancelUrl ?? 'yangchow://payment/cancel';



      final response = await http.post(

        Uri.parse('$_baseUrl/links'),

        headers: {

          ..._headers,

          'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',

        },

        body: jsonEncode({

          'data': {

            'attributes': {

              'amount': (amount * 100).round(), // Convert to cents

              'description': description,

              'remarks': 'Payment for Yang Chow Restaurant',

              'redirect': {

                'success': successUrl,

                'failed': failedUrl,

              },

              'billing': {

                'name': 'Customer',

                'email': 'customer@example.com',

                'phone': '+639123456789',

              },

              'metadata': metadata,

              'payment_method_types': ['gcash', 'paymaya', 'card', 'bank_transfer', 'brankas', 'dob', 'dob_ubp', 'grab_pay'],

            },

          },

        }),

      );



      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        return {

          'success': true,

          'data': data['data'],

          'linkId': data['data']['id'],

          'checkoutUrl': data['data']['attributes']['checkout_url'],

        };

      } else {

        return {

          'success': false,

          'error': jsonDecode(response.body)['errors']?[0]?['detail'] ?? 'Payment link creation failed',

        };

      }

    } catch (e) {

      return {

        'success': false,

        'error': 'Network error: ${e.toString()}',

      };

    }

  }



  // Retrieve payment link status

  static Future<Map<String, dynamic>> retrievePaymentLink(String linkId) async {

    try {

      final response = await http.get(

        Uri.parse('$_baseUrl/links/$linkId'),

        headers: {

          ..._headers,

          'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',

        },

      );



      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        final status = data['data']['attributes']['status'];

        final payments = data['data']['attributes']['payments'] as List;

        

        // A link is "paid" if its status is 'paid'

        return {

          'success': true,

          'status': status,

          'isPaid': status == 'paid',

          'payments': payments,

        };

      } else {

        return {

          'success': false,

          'error': jsonDecode(response.body)['errors']?[0]?['detail'] ?? 'Status retrieval failed',

        };

      }

    } catch (e) {

      return {

        'success': false,

        'error': 'Network error: ${e.toString()}',

      };

    }

  }



  // Create a payment intent for direct payment processing

  static Future<Map<String, dynamic>> createPaymentIntent({

    required double amount,

    required String currency,

    Map<String, dynamic>? metadata,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$_baseUrl/payment_intents'),

        headers: {

          ..._headers,

          'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',

        },

        body: jsonEncode({

          'data': {

            'attributes': {

              'amount': (amount * 100).round(), // Convert to cents

              'currency': currency.toUpperCase(),

              'payment_method_allowed': ['gcash', 'paymaya', 'card', 'bank_transfer'],

              'payment_method_options': {

                'card': {'request_three_d_secure': 'any'},

              },

               'metadata': metadata,

            },

          },

        }),

      );



      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        return {

          'success': true,

          'data': data['data'],

          'clientKey': data['data']['attributes']['client_key'],

        };

      } else {

        return {

          'success': false,

          'error': jsonDecode(response.body)['errors']?[0]?['detail'] ?? 'Payment intent creation failed',

        };

      }

    } catch (e) {

      return {

        'success': false,

        'error': 'Network error: ${e.toString()}',

      };

    }

  }



  // Attach payment method to payment intent
  static Future<Map<String, dynamic>> attachPaymentMethod({
    required String paymentIntentId,
    required String paymentMethodId,
    required String clientKey,
    String? returnUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payment_intents/$paymentIntentId/attach'),
        headers: {
          ..._headers,
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',
        },
        body: jsonEncode({
          'data': {
            'attributes': {
              'payment_method': paymentMethodId,
              'client_key': clientKey,
              if (returnUrl != null) 'return_url': returnUrl,
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'status': data['data']['attributes']['status'],
        };
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['errors']?[0]?['detail'] ?? 'Payment method attachment failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }



  // Create payment method (for GCash, PayMaya, etc.)

  static Future<Map<String, dynamic>> createPaymentMethod({

    required String type,

    required Map<String, dynamic> details,

    Map<String, dynamic>? metadata,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$_baseUrl/payment_methods'),

        headers: {

          ..._headers,

          'Authorization': 'Basic ${base64Encode(utf8.encode('$_publicKey:'))}',

        },

        body: jsonEncode({

          'data': {

            'attributes': {

              'type': type,

              'details': details,

               'metadata': metadata,

            },

          },

        }),

      );



      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        return {

          'success': true,

          'data': data['data'],

          'paymentMethodId': data['data']['id'],

        };

      } else {

        return {

          'success': false,

          'error': jsonDecode(response.body)['errors'][0]['detail'] ?? 'Payment method creation failed',

        };

      }

    } catch (e) {

      return {

        'success': false,

        'error': 'Network error: ${e.toString()}',

      };

    }

  }



  // Retrieve payment status

  static Future<Map<String, dynamic>> getPaymentStatus(String paymentId) async {

    try {

      final response = await http.get(

        Uri.parse('$_baseUrl/payments/$paymentId'),

        headers: {

          ..._headers,

          'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',

        },

      );



      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        return {

          'success': true,

          'data': data['data'],

          'status': data['data']['attributes']['status'],

        };

      } else {

        return {

          'success': false,

          'error': 'Payment status retrieval failed',

        };

      }

    } catch (e) {

      return {

        'success': false,

        'error': 'Network error: ${e.toString()}',

      };

    }

  }



  // Get available payment methods

  static List<Map<String, dynamic>> getAvailablePaymentMethods() {

    return [

      {

        'id': 'qrph',

        'name': 'QRPh',

        'icon': 'assets/images/qrph_logo.png',

        'type': 'qrph',

        'description': 'Scan to Pay using GCash, Maya, etc.',

      },

      {

        'id': 'gcash',

        'name': 'GCash',

        'icon': 'assets/images/gcash_logo.png',

        'type': 'gcash',

        'description': 'Pay with GCash wallet',

      },

      {

        'id': 'paymaya',

        'name': 'Maya',

        'icon': 'assets/images/paymaya_logo.png',

        'type': 'paymaya',

        'description': 'Pay with Maya wallet',

      },

      {

        'id': 'card',

        'name': 'Credit/Debit Card',

        'icon': 'assets/images/card_logo.png',

        'type': 'card',

        'description': 'Visa, Mastercard, JCB',

      },

      {

        'id': 'bank_transfer',

        'name': 'Bank Transfer',

        'icon': 'assets/images/bank_logo.png',

        'type': 'bank_transfer',

        'description': 'Direct bank transfer',

      },

    ];

  }



  // Format amount for display

  static String formatAmount(double amount) {

    return '₱$amount';

  }



  // Validate payment amount

  static bool isValidAmount(double amount) {

    return amount > 0 && amount <= 1000000; // Max 1M PHP

  }



  // Generate unique reference number

  static String generateReferenceNumber() {

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final random = DateTime.now().second;

    return 'YANG$timestamp$random';

  }

}

