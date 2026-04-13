import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';


class PayMongoService {

  static const String _baseUrl = 'https://api.paymongo.com/v1';

  static final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'PHP ');

  static String formatAmount(double amount) {
    return _currencyFormat.format(amount);
  }

  static String generateReferenceNumber() {
    final now = DateTime.now();
    final random = (1000 + (now.microsecond % 9000)).toString();
    return 'YC-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  

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



  static const Map<String, String> _headers = {

    'Content-Type': 'application/json',

    'Accept': 'application/json',

  };



  static Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String description,
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

              'amount': amount.round(), // Convert to centavos

              'payment_method_allowed': ['gcash', 'card', 'paymaya'],

              'description': description,

              'statement_descriptor': 'YANG RESTAURANT',

              'currency': 'PHP',

              'metadata': metadata ?? {},

            }

          }

        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final clientKey = data['data']['attributes']['client_key'];

        final paymentIntentId = data['data']['id'];

        

        return {
          'success': true,
          'clientKey': clientKey,
          'paymentIntentId': paymentIntentId,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to create payment intent: ${response.body}',
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

        return jsonDecode(response.body);

      } else {

        throw Exception('Failed to retrieve payment intent: ${response.body}');

      }

    } catch (e) {

      throw Exception('Payment intent retrieval failed: $e');

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



  static Future<Map<String, dynamic>> getAvailablePaymentMethods() async {
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
              ...?details != null ? {'details': details} : null,
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'paymentMethodId': data['data']['id'],
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to create payment method: ${response.body}',
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
              ...?returnUrl != null ? {'return_url': returnUrl} : null,
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
        return {
          'success': false,
          'error': 'Failed to attach payment method: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Attach payment method failed: $e',
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
        final attributes = data['data']?['attributes'];
        final payments = attributes?['payments'] as List?;
        bool isPaid = payments?.any((p) => p['attributes']?['status'] == 'paid') ?? false;
        
        return {
          'success': true,
          'isPaid': isPaid,
          'data': data,
        };
      } else {
        throw Exception('Failed to retrieve payment link: ${response.body}');
      }
    } catch (e) {
      throw Exception('Payment link retrieval failed: $e');
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
