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
      title: 'PayMongo API Test',
      home: const PayMongoAPITestPage(),
    );
  }
}

class PayMongoAPITestPage extends StatefulWidget {
  const PayMongoAPITestPage({super.key});

  @override
  State<PayMongoAPITestPage> createState() => _PayMongoAPITestPageState();
}

class _PayMongoAPITestPageState extends State<PayMongoAPITestPage> {
  bool _isLoading = false;
  String _result = '';

  Future<void> _testPayMongoAPI() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing PayMongo API...';
    });

    try {
      // Test creating a payment link
      final result = await PayMongoService.createPaymentLink(
        amount: 5000.0, // 50.00 PHP in cents
        description: 'Test payment for Yang Chow Restaurant',
        returnUrl: 'https://yourapp.com/payment/success',
        metadata: {
          'test': 'true',
          'customer': 'test_user',
          'reservation_id': 'test_123',
        },
      );

      setState(() {
        if (result['success'] == true) {
          _result = '''
SUCCESS! Payment link created:

Link ID: ${result['linkId']}
Checkout URL: ${result['checkoutUrl']}

You can test this payment by:
1. Opening the checkout URL
2. Making a test payment
3. Verifying the payment works
          ''';
        } else {
          _result = '''
ERROR: Payment link creation failed

Error: ${result['error']}

Please check:
1. Your API keys are correct
2. You have internet connection
3. PayMongo test mode is enabled
          ''';
        }
      });
    } catch (e) {
      setState(() {
        _result = 'EXCEPTION: $e';
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
        title: const Text('PayMongo API Test'),
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
                        'PayMongo API Test',
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
                    'This will test your PayMongo API integration with real test keys.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testPayMongoAPI,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.api),
              label: Text(_isLoading ? 'Testing...' : 'Test PayMongo API'),
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
                    _result.isEmpty ? 'Click "Test PayMongo API" to begin testing.' : _result,
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
