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
    required String returnUrl,
    required String cancelUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
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
                'success': returnUrl,
                'failed': cancelUrl,
              },
              'billing': {
                'name': 'Customer',
                'email': 'customer@example.com',
                'phone': '+639123456789',
              },
              if (metadata != null) 'metadata': metadata,
              'payment_method_types': ['gcash', 'paymaya', 'card', 'bank_transfer'],
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
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
              'currency': currency.toLowerCase(),
              'payment_method_allowed': ['gcash', 'paymaya', 'card', 'bank_transfer'],
              'payment_method_options': {
                'card': {'request_three_d_secure': 'any'},
              },
              if (metadata != null) 'metadata': metadata,
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
              if (metadata != null) 'metadata': metadata,
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
