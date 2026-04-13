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
      title: 'GCash Payment Test',
      home: const GCashPaymentTestPage(),
    );
  }
}

class GCashPaymentTestPage extends StatefulWidget {
  const GCashPaymentTestPage({super.key});

  @override
  State<GCashPaymentTestPage> createState() => _GCashPaymentTestPageState();
}

class _GCashPaymentTestPageState extends State<GCashPaymentTestPage> {
  bool _isLoading = false;
  String _result = '';

  Future<void> _testGCashPayment() async {
    setState(() {
      _isLoading = true;
      _result = 'Creating GCash payment link...';
    });

    try {
      // Test GCash payment link creation
      final paymentLink = await PayMongoService.createGCashPaymentLink(
        amount: 3000.0 * 100, // 3,000 PHP in cents
        description: 'GCash Deposit for Birthday Party',
        returnUrl: 'https://yourapp.com/payment/success',
        metadata: {
          'test': 'true',
          'payment_method': 'gcash',
          'reservation_id': 'test_gcash_123',
        },
      );

      setState(() {
        if (paymentLink['success'] == true) {
          _result = '''
SUCCESS! GCash Payment Link Created

Payment Details:
- Amount: PHP 3,000.00
- Method: GCash Only
- Description: ${paymentLink['data']['attributes']['description']}
- Link ID: ${paymentLink['linkId']}

GCash Payment URL:
${paymentLink['checkoutUrl']}

How to Test GCash Payment:
1. Click the URL above or scan QR code
2. Login to your GCash account
3. Enter amount: PHP 3,000.00
4. Confirm payment (TEST MODE - no real charge)
5. Payment successful! Reservation confirmed

GCash Features:
- Instant payment confirmation
- No real money charged (test mode)
- Secure GCash integration
- Auto-reservation confirmation
          ''';
        } else {
          _result = '''
ERROR: GCash Payment Link Creation Failed

Error: ${paymentLink['error']}

Troubleshooting:
1. Check GCash API permissions
2. Verify test API keys
3. Ensure GCash is enabled in PayMongo
4. Check network connection
          ''';
        }
      });
    } catch (e) {
      setState(() {
        _result = '''
EXCEPTION: GCash Payment Test Failed

Error: $e

Possible Issues:
- Network connection problems
- Invalid API keys
- GCash service unavailable
- PayMongo API limits
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
        title: const Text('GCash Payment Test'),
        backgroundColor: Colors.blue,
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
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'GCash Payment Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Test GCash payment integration for 3,000 PHP deposit.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testGCashPayment,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.account_balance_wallet),
              label: Text(_isLoading ? 'Testing...' : 'Test GCash Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
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
                    _result.isEmpty ? 'Click "Test GCash Payment" to test the GCash integration.' : _result,
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
