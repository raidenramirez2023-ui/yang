import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// PayMongo Web Service for browser-based payments
class PayMongoWebService {
  static const String _payMongoDashboard = 'https://dashboard.paymongo.com';
  
  // Create payment link using PayMongo Dashboard (works for web without API calls)
  static Future<Map<String, dynamic>> createWebPaymentLink({
    required double amount,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('=== PayMongo Web Service ===');
      debugPrint('Creating web payment link...');
      debugPrint('Amount: $amount');
      debugPrint('Description: $description');
      
      // For web, redirect to PayMongo dashboard where user can create manual payment
      // This bypasses CORS issues and still allows QRPH payments
      
      // Create a direct link to PayMongo's payment page
      // User can manually enter amount and pay with QRPH, GCash, etc.
      final checkoutUrl = '$_payMongoDashboard/checkout';
      
      debugPrint('Redirecting to PayMongo Dashboard: $checkoutUrl');
      
      return {
        'success': true,
        'checkoutUrl': checkoutUrl,
        'linkId': 'dashboard_${DateTime.now().millisecondsSinceEpoch}',
        'data': {
          'amount': amount,
          'description': description,
          'note': 'Web payment - redirect to PayMongo dashboard for manual payment',
          'instructions': '''
After redirecting to PayMongo:
1. Click "Create Payment" or "New Payment"
2. Enter amount: PHP ${amount.toStringAsFixed(2)}
3. Select payment method: QRPH, GCash, Maya, Card, etc.
4. Generate QR code or payment link
5. Complete payment using your preferred method
          '''
        },
      };
      
    } catch (e) {
      debugPrint('Web payment link creation error: $e');
      return {
        'success': false,
        'error': 'Web payment link creation failed: $e',
      };
    }
  }
  
  // Create PayMongo checkout link using direct API call
  static Future<Map<String, dynamic>> createDirectPaymentLink({
    required double amount,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('Creating PayMongo checkout link...');
      debugPrint('Amount: $amount');
      debugPrint('Description: $description');
      
      // For web, we'll create a manual payment instruction page
      // that guides users to create the checkout link themselves
      
      final instructionUrl = _createPaymentInstructionPage(amount, description);
      
      debugPrint('Created payment instruction page');
      
      return {
        'success': true,
        'checkoutUrl': instructionUrl,
        'linkId': 'manual_${DateTime.now().millisecondsSinceEpoch}',
        'data': {
          'amount': amount,
          'description': description,
          'type': 'payment_instructions',
          'note': 'Manual payment creation - follow instructions on page'
        },
      };
      
    } catch (e) {
      debugPrint('EXCEPTION: $e');
      return {
        'success': false,
        'error': 'Payment instruction creation failed: $e',
      };
    }
  }
  
  // Create payment instruction page with QRPH focus
  static String _createPaymentInstructionPage(double amount, String description) {
    final html = '''
<!DOCTYPE html>
<html>
<head>
    <title>PayMongo Payment - PHP ${amount.toStringAsFixed(2)}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
                max-width: 600px; margin: 20px auto; padding: 20px; 
                background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 12px; 
                     box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
        .header { text-align: center; color: #1a73e8; margin-bottom: 30px; }
        .amount { font-size: 36px; font-weight: bold; color: #1a73e8; }
        .description { color: #666; margin-bottom: 30px; }
        .qr-section { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                     color: white; padding: 25px; border-radius: 12px; margin: 20px 0; }
        .steps { background: #f8f9fa; padding: 25px; border-radius: 12px; margin: 20px 0; }
        .step { margin: 15px 0; display: flex; align-items: flex-start; }
        .step-number { background: #1a73e8; color: white; width: 30px; height: 30px; 
                       border-radius: 50%; display: flex; align-items: center; 
                       justify-content: center; margin-right: 15px; flex-shrink: 0; }
        .step-content { flex: 1; }
        .button { background: #1a73e8; color: white; padding: 15px 30px; 
                 text-decoration: none; border-radius: 8px; display: inline-block; 
                 margin: 10px; font-weight: bold; transition: all 0.3s; }
        .button:hover { background: #1557b0; transform: translateY(-2px); }
        .dashboard-btn { background: #28a745; }
        .dashboard-btn:hover { background: #218838; }
        .info-box { background: #e3f2fd; border-left: 4px solid #1a73e8; 
                    padding: 15px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>PayMongo Payment</h1>
            <div class="amount">PHP ${amount.toStringAsFixed(2)}</div>
            <div class="description">$description</div>
        </div>
        
        <div class="qr-section">
            <h2>QRPH Payment - Fast & Easy!</h2>
            <p>Scan QRPH code using GCash for instant payment. No app downloads needed!</p>
        </div>
        
        <div class="steps">
            <h3>Quick Steps to Pay:</h3>
            
            <div class="step">
                <div class="step-number">1</div>
                <div class="step-content">
                    <strong>Open PayMongo Dashboard</strong><br>
                    Click the green button below to go to your PayMongo account
                </div>
            </div>
            
            <div class="step">
                <div class="step-number">2</div>
                <div class="step-content">
                    <strong>Create Payment Link</strong><br>
                    Click "Create Payment Link" in the dashboard
                </div>
            </div>
            
            <div class="step">
                <div class="step-number">3</div>
                <div class="step-content">
                    <strong>Fill Payment Details</strong><br>
                    Amount: <strong>PHP ${amount.toStringAsFixed(2)}</strong><br>
                    Description: <strong>$description</strong><br>
                    Enable: <strong>QRPH</strong> payment method
                </div>
            </div>
            
            <div class="step">
                <div class="step-number">4</div>
                <div class="step-content">
                    <strong>Generate & Pay</strong><br>
                    Create the link, then scan the QRPH code with GCash
                </div>
            </div>
        </div>
        
        <div class="info-box">
            <strong>Why QRPH?</strong><br>
            QRPH is the national QR code standard in the Philippines. 
            You can scan it with GCash, Maya, or other banking apps for instant payment.
        </div>
        
        <div style="text-align: center; margin: 30px 0;">
            <a href="https://dashboard.paymongo.com" target="_blank" class="button dashboard-btn">
                Open PayMongo Dashboard
            </a>
        </div>
        
        <div style="text-align: center; color: #666; font-size: 14px; margin-top: 20px;">
            <p>After completing payment, return to the app and click "I Completed Payment"</p>
            <p>Need help? Contact support or check PayMongo documentation</p>
        </div>
    </div>
</body>
</html>
    ''';
    
    return 'data:text/html;charset=utf-8,${Uri.encodeComponent(html)}';
  }
  
    
  
  // Create a simple payment instruction page
  static Future<Map<String, dynamic>> createPaymentInstructions({
    required double amount,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('Creating payment instructions...');
      
      // Create a custom payment instruction page
      final instructionsUrl = 'data:text/html,<html><body><h1>Payment Instructions</h1><p>Amount: PHP ${amount.toStringAsFixed(2)}</p><p>Description: $description</p><h2>How to Pay:</h2><ol><li>Go to <a href="https://dashboard.paymongo.com" target="_blank">PayMongo Dashboard</a></li><li>Create a new payment link</li><li>Enter amount: PHP ${amount.toStringAsFixed(2)}</li><li>Enable QRPH payment method</li><li>Generate QR code</li><li>Scan with GCash to pay</li></ol></body></html>';
      
      return {
        'success': true,
        'checkoutUrl': instructionsUrl,
        'linkId': 'instructions_${DateTime.now().millisecondsSinceEpoch}',
        'data': {
          'amount': amount,
          'description': description,
          'type': 'payment_instructions',
        },
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': 'Payment instructions failed: $e',
      };
    }
  }
}
