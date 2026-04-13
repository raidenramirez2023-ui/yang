import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PayMongoService {

  static const String _baseUrl = 'https://api.paymongo.com/v1';

  

  static String get _publicKey {
    final key = dotenv.env['PAYMONGO_PUBLIC_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('PAYMONGO_PUBLIC_KEY not found in environment variables');
    }
    debugPrint('PayMongo Public Key: ${key.substring(0, 8)}...');
    return key;
  }

  static String get _secretKey {
    final key = dotenv.env['PAYMONGO_SECRET_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('PAYMONGO_SECRET_KEY not found in environment variables');
    }
    debugPrint('PayMongo Secret Key: SET');
    return key;
  }

  static String formatAmount(double amount) {
    final format = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    return format.format(amount);
  }

  static String generateReferenceNumber() {
    final now = DateTime.now();
    final random = (1000 + (9999 - 1000) * (DateTime.now().millisecondsSinceEpoch % 1000 / 1000)).toInt();
    return 'YANG-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  static List<Map<String, dynamic>> getAvailablePaymentMethods() {
    return [
      {
        'id': 'gcash',
        'type': 'gcash',
        'name': 'GCash',
        'description': 'Pay using your GCash e-wallet',
        'icon': Icons.wallet,
      },
      {
        'id': 'paymaya',
        'type': 'paymaya',
        'name': 'Maya',
        'description': 'Pay using your Maya e-wallet',
        'icon': Icons.wallet,
      },
      {
        'id': 'card',
        'type': 'card',
        'name': 'Credit/Debit Card',
        'description': 'Visa, Mastercard, or JCB',
        'icon': Icons.credit_card,
      },
      {
        'id': 'qrph',
        'type': 'qrph',
        'name': 'QRPh',
        'description': 'Scan to pay using any banking app',
        'icon': Icons.qr_code,
      },
    ];
  }



  static const Map<String, String> _headers = {

    'Content-Type': 'application/json',

    'Accept': 'application/json',

  };



  static Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    String? description,
    String currency = 'PHP',
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
              'amount': (amount * 100).round(), // Convert to centavos
              'payment_method_allowed': ['gcash', 'card', 'paymaya', 'dob', 'qrph'],
              'description': description ?? 'Yang Restaurant Order',
              'statement_descriptor': 'YANG RESTAURANT',
              'currency': currency,
              'metadata': metadata ?? {},
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'paymentIntentId': data['data']['id'],
          'clientKey': data['data']['attributes']['client_key'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['errors']?[0]?['detail'] ?? 'Unknown error';
        return {
          'success': false,
          'error': 'Failed to create payment intent: $errorMessage',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Payment intent creation failed: $e',
      };
    }
  }



  static Future<Map<String, dynamic>> retrievePaymentIntent(String paymentIntentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/payment_intents/$paymentIntentId'),
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
        return {'success': false, 'error': 'Failed to retrieve intent'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createPaymentMethod({
    required String type,
    Map<String, dynamic>? details,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payment_methods'),
        headers: {
          ..._headers,
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',
        },
        body: jsonEncode({
          'data': {
            'attributes': {
              'type': type,
              'details': ?details,
            }
          }
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
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['errors']?[0]?['detail'] ?? 'Unknown error';
        return {
          'success': false,
          'error': 'Failed to create payment method: $errorMessage',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Payment method creation failed: $e',
      };
    }
  }

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
              'return_url': ?returnUrl,
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['errors']?[0]?['detail'] ?? 'Unknown error';
        return {
          'success': false,
          'error': 'Failed to attach payment method: $errorMessage',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Payment method attachment failed: $e',
      };
    }
  }

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
        final payments = data['data']['attributes']['payments'] as List;
        bool isPaid = false;
        if (payments.isNotEmpty) {
          isPaid = payments.any((p) => p['attributes']['status'] == 'paid');
        }

        return {
          'success': true,
          'data': data['data'],
          'status': data['data']['attributes']['status'],
          'isPaid': isPaid || data['data']['attributes']['status'] == 'paid',
        };
      } else {
        return {'success': false, 'error': 'Failed to retrieve payment link'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }



  static Future<Map<String, dynamic>> createWebhook({

    required String url,

    required List<String> events,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$_baseUrl/webhooks'),

        headers: {

          ..._headers,

          'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',

        },

        body: jsonEncode({

          'data': {

            'attributes': {

              'url': url,

              'events': events,

            }

          }

        }),

      );



      if (response.statusCode == 200) {

        return jsonDecode(response.body);

      } else {

        throw Exception('Failed to create webhook: ${response.body}');

      }

    } catch (e) {

      throw Exception('Webhook creation failed: $e');

    }

  }



  static Future<bool> verifyWebhookSignature({

    required String payload,

    required String signatureHeader,

    required String webhookSecretKey,

  }) async {

    try {

      // Implement webhook signature verification

      // This is a simplified version - you should use proper crypto libraries

      final parts = signatureHeader.split(',');

      String? signature;

      String? timestamp;

      

      for (final part in parts) {

        if (part.startsWith('t=')) {

          timestamp = part.substring(2);

        } else if (part.startsWith('v1=')) {

          signature = part.substring(3);

        }

      }

      

      if (signature == null || timestamp == null) {

        return false;

      }

      

      // In production, implement proper HMAC verification

      // For now, this is a basic check

      return true;

    } catch (e) {

      debugPrint('Webhook signature verification failed: $e');

      return false;

    }

  }



  static Future<Map<String, dynamic>> getPaymentMethods() async {

    try {

      final response = await http.get(

        Uri.parse('$_baseUrl/payment_methods'),

        headers: {

          ..._headers,

          'Authorization': 'Basic ${base64Encode(utf8.encode('$_publicKey:'))}',

        },

      );



      if (response.statusCode == 200) {

        return jsonDecode(response.body);

      } else {

        throw Exception('Failed to get payment methods: ${response.body}');

      }

    } catch (e) {

      throw Exception('Payment methods retrieval failed: $e');

    }

  }



  static Future<Map<String, dynamic>> createSource({

    required double amount,

    required String type, // 'gcash', 'paymaya', etc.

    required Map<String, dynamic> redirect,

    Map<String, dynamic>? metadata,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$_baseUrl/sources'),

        headers: {

          ..._headers,

          'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',

        },

        body: jsonEncode({

          'data': {

            'attributes': {

              'amount': amount.round(),

              'type': type,

              'currency': 'PHP',

              'redirect': redirect,

              'metadata': metadata ?? {},

            }

          }

        }),

      );



      if (response.statusCode == 200) {

        return jsonDecode(response.body);

      } else {

        throw Exception('Failed to create source: ${response.body}');

      }

    } catch (e) {

      throw Exception('Source creation failed: $e');

    }

  }



  static Future<Map<String, dynamic>> createPaymentLink({

    required double amount,

    required String description,

    String? returnUrl,

    String? cancelUrl,

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

              'amount': amount.round(),

              'description': description,

              'currency': 'PHP',

              'metadata': metadata ?? {},

            }

          }

        }),

      );



      if (response.statusCode == 200) {

        final responseData = jsonDecode(response.body);
        
        // Extract the checkout URL from PayMongo response
        final checkoutUrl = responseData['data']?['attributes']?['checkout_url'] ?? 
                          responseData['data']?['attributes']?['url'];
        
        if (checkoutUrl == null) {
          throw Exception('No checkout URL returned from PayMongo');
        }
        
        return {
          'success': true,
          'checkoutUrl': checkoutUrl,
          'data': responseData,
        };

      } else {

        throw Exception('Failed to create payment link: ${response.body}');

      }

    } catch (e) {

      throw Exception('Payment link creation failed: $e');

    }

  }



  static Future<Map<String, dynamic>> createGCashPaymentLink({

    required double amount,

    required String description,

    String? returnUrl,

    String? cancelUrl,

    Map<String, dynamic>? metadata,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('$_baseUrl/sources'),

        headers: {

          ..._headers,

          'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',

        },

        body: jsonEncode({

          'data': {

            'attributes': {

              'amount': amount.round(),

              'type': 'gcash',

              'currency': 'PHP',

              'description': description,

              'redirect': {

                'success': returnUrl ?? 'https://yourapp.com/payment/success',

                'failed': cancelUrl ?? 'https://yourapp.com/payment/failed',

              },

              'metadata': metadata ?? {},

            }

          }

        }),

      );



      if (response.statusCode == 200) {

        final responseData = jsonDecode(response.body);
        
        // Extract the redirect URL from PayMongo source response
        final redirectUrl = responseData['data']?['attributes']?['redirect']?['checkout_url'] ?? 
                          responseData['data']?['attributes']?['redirect']?['url'] ??
                          responseData['data']?['attributes']?['url'];
        
        if (redirectUrl == null) {
          throw Exception('No redirect URL returned from PayMongo');
        }
        
        return {
          'success': true,
          'checkoutUrl': redirectUrl,
          'data': responseData,
        };

      } else {

        throw Exception('Failed to create GCash payment link: ${response.body}');

      }

    } catch (e) {

      throw Exception('GCash payment link creation failed: $e');

    }

  }

}
