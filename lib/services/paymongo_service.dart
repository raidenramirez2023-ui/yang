import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

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

  static String get _clientKey {
    final key = dotenv.env['PAYMONGO_PUBLIC_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('PAYMONGO_PUBLIC_KEY not found in environment variables');
    }
    return key;
  }



  static const Map<String, String> _headers = {

    'Content-Type': 'application/json',

    'Accept': 'application/json',

  };



static Future<Map<String, String>> createPaymentIntent({
    required double amount,
    required String description,
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
          'client_key': clientKey,
          'payment_intent_id': paymentIntentId,
        };
      } else {
        throw Exception('Failed to create payment intent: ${response.body}');
      }
    } catch (e) {
      throw Exception('Payment intent creation failed: $e');
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

  static Future<Map<String, dynamic>> createSource({

    required double amount,

    required String type, // 'gcash', 'paymaya', etc.

    required Map<String, dynamic> redirect,

    required String url,

    required List<String> events,

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

    }

        throw Exception('Failed to create source: ${response.body}');

      }

      

      throw Exception('Source creation failed: $e');

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

          'Authorization': 'Basic ${base64Encode(utf8.encode('$_publicKey:'))}',

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


  // Create Payment Method
  static Future<Map<String, dynamic>> createPaymentMethod({
    required String type,
    required Map<String, dynamic> details,
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
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final paymentMethodId = responseData['data']['id'];
        
        return {
          'success': true,
          'paymentMethodId': paymentMethodId,
          'data': responseData,
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

  // Attach Payment Method to Payment Intent
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
          'Authorization': 'Basic ${base64Encode(utf8.encode('$clientKey:'))}',
        },
        body: jsonEncode({
          'data': {
            'attributes': {
              'payment_method': paymentMethodId,
              'return_url': returnUrl,
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        return {
          'success': true,
          'data': responseData,
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
        'error': 'Payment method attachment failed: $e',
      };
    }
  }

  // Retrieve Payment Link
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
        final responseData = jsonDecode(response.body);
        final attributes = responseData['data']['attributes'];
        final status = attributes['status'];
        final isPaid = status == 'paid';
        
        return {
          'success': true,
          'isPaid': isPaid,
          'status': status,
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to retrieve payment link: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Payment link retrieval failed: $e',
      };
    }
  }

  // Generate Reference Number
  static String generateReferenceNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond.toString().substring(0, 3);
    return 'YANG${timestamp}$random';
  }

  // Format Amount for Display
  static String formatAmount(double amount) {
    return 'PHP ${amount.toStringAsFixed(2)}';
  }

  // Get Available Payment Methods
  static List<Map<String, dynamic>> getAvailablePaymentMethods() {
    return [
      {
        'id': 'gcash',
        'type': 'gcash',
        'name': 'GCash',
        'description': 'Pay using GCash e-wallet',
        'icon': 'gcash',
      },
      {
        'id': 'paymaya',
        'type': 'paymaya',
        'name': 'Maya',
        'description': 'Pay using Maya e-wallet',
        'icon': 'paymaya',
      },
      {
        'id': 'qrph',
        'type': 'qrph',
        'name': 'QRPH',
        'description': 'Pay using QRPH (QR Philippines)',
        'icon': 'qrph',
      },
      {
        'id': 'card',
        'type': 'card',
        'name': 'Credit/Debit Card',
        'description': 'Pay using Visa, Mastercard, or JCB',
        'icon': 'card',
      },
      {
        'id': 'bank_transfer',
        'type': 'bank_transfer',
        'name': 'Bank Transfer',
        'description': 'Pay via online banking',
        'icon': 'bank',
      },
    ];
  }

  // Updated createPaymentIntent to match the expected signature
  static Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
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
              'currency': currency,
              'description': 'Yang Chow Restaurant Payment',
              'statement_descriptor': 'YANG RESTAURANT',
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
          'data': data,
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

  // Updated createPaymentLink to return consistent format
  static Future<Map<String, dynamic>> createPaymentLink({
    required double amount,
    required String description,
    String? returnUrl,
    String? cancelUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('=== PayMongo Debug ===');
      debugPrint('Creating payment link...');
      debugPrint('Amount: $amount');
      debugPrint('Description: $description');
      debugPrint('Base URL: $_baseUrl');
      
      // Check if secret key is available
      try {
        final secretKey = _secretKey;
        debugPrint('Secret Key: ${secretKey.substring(0, 8)}...');
      } catch (e) {
        debugPrint('ERROR getting secret key: $e');
        return {
          'success': false,
          'error': 'Secret key not available: $e',
        };
      }
      
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

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Extract the checkout URL from PayMongo response
        final checkoutUrl = responseData['data']?['attributes']?['checkout_url'] ?? 
                          responseData['data']?['attributes']?['url'];
        
        debugPrint('Checkout URL: $checkoutUrl');
        
        if (checkoutUrl == null) {
          debugPrint('ERROR: No checkout URL in response');
          return {
            'success': false,
            'error': 'No checkout URL returned from PayMongo',
          };
        }
        
        debugPrint('SUCCESS: Payment link created');
        return {
          'success': true,
          'checkoutUrl': checkoutUrl,
          'linkId': responseData['data']['id'],
          'data': responseData,
        };

      } else {
        debugPrint('ERROR: API call failed with status ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to create payment link: ${response.body}',
        };
      }

    } catch (e) {
      debugPrint('EXCEPTION: $e');
      return {
        'success': false,
        'error': 'Payment link creation failed: $e',
      };
    }
  }

}
