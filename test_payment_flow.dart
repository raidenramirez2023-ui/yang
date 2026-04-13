import 'package:flutter/material.dart';
import 'package:yang_chow/services/paymongo_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Payment Flow Test',
      home: const PaymentFlowTestPage(),
    );
  }
}

class PaymentFlowTestPage extends StatefulWidget {
  const PaymentFlowTestPage({super.key});

  @override
  State<PaymentFlowTestPage> createState() => _PaymentFlowTestPageState();
}

class _PaymentFlowTestPageState extends State<PaymentFlowTestPage> {
  bool _isLoading = false;
  String _result = '';

  Future<void> _testPaymentFlow() async {
    setState(() {
      _isLoading = true;
      _result = 'Creating payment link...';
    });

    try {
      // Simulate a reservation data
      final reservation = {
        'id': 'test_reservation_123',
        'event_type': 'Birthday Party',
        'event_date': '2024-05-15',
        'customer_email': 'test@example.com',
        'total_price': 10000.00,
      };

      final depositAmount = reservation['total_price'] * 0.5; // 50% deposit

      // Create PayMongo payment link (same as in customer_dashboard.dart)
      final paymentLink = await PayMongoService.createPaymentLink(
        amount: depositAmount * 100, // Convert to cents
        description: 'Deposit for ${reservation['event_type']} on ${reservation['event_date']}',
        returnUrl: 'https://yourapp.com/payment/success',
        metadata: {
          'reservation_id': reservation['id'],
          'customer_email': reservation['customer_email'],
          'event_type': reservation['event_type'],
          'payment_type': 'deposit',
        },
      );

      setState(() {
        if (paymentLink['success'] == true) {
          _result = '''
✅ PAYMENT LINK CREATED SUCCESSFULLY!

📋 Payment Details:
• Amount: PHP ${(depositAmount as double).toStringAsFixed(2)}
• Description: ${paymentLink['data']['attributes']['description']}
• Link ID: ${paymentLink['linkId']}

🔗 Payment URL:
${paymentLink['checkoutUrl']}

💡 To test:
1. Copy the URL above
2. Open in browser
3. Pay with test card: 4123456789012345
4. Use any future expiry date
5. Use any 3-digit CVV

🎉 This is the exact same flow your customers will experience!
          ''';
        } else {
          _result = '''
❌ PAYMENT LINK CREATION FAILED

Error: ${paymentLink['error']}

🔧 Troubleshooting:
1. Check API keys are correct
2. Verify internet connection
3. Ensure PayMongo test mode is enabled
4. Check if API keys have proper permissions
          ''';
        }
      });
    } catch (e) {
      setState(() {
        _result = '''
💥 EXCEPTION OCCURRED

Error: $e

🔧 This might be:
• Network connection issue
• Invalid API keys
• PayMongo service unavailable
• CORS or firewall issues
        ''';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Flow Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payment, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Payment Flow Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This simulates the exact payment flow when customers click "Proceed to Payment".',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testPaymentFlow,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isLoading ? 'Testing...' : 'Test Payment Flow'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _result.isEmpty ? 'Click "Test Payment Flow" to simulate the payment process.' : _result,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
