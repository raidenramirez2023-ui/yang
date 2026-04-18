import 'package:flutter/material.dart';
import 'package:yang_chow/services/paymongo_service.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayMongo Test',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const PayMongoTestPage(),
    );
  }
}

class PayMongoTestPage extends StatefulWidget {
  const PayMongoTestPage({super.key});

  @override
  State<PayMongoTestPage> createState() => _PayMongoTestPageState();
}

class _PayMongoTestPageState extends State<PayMongoTestPage> {
  bool _isLoading = false;
  String _result = '';
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PayMongo Test'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test PayMongo Integration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Test Payment Methods
            ElevatedButton(
              onPressed: _isLoading ? null : _testPaymentMethods,
              child: const Text('Test Payment Methods'),
            ),
            
            const SizedBox(height: 10),
            
            // Test Payment Link Creation (QRPH)
            ElevatedButton(
              onPressed: _isLoading ? null : _testPaymentLink,
              child: const Text('Test Payment Link (QRPH)'),
            ),
            
            const SizedBox(height: 10),
            
            // Test Payment Intent (GCash)
            ElevatedButton(
              onPressed: _isLoading ? null : _testPaymentIntent,
              child: const Text('Test Payment Intent (GCash)'),
            ),
            
            const SizedBox(height: 20),
            
            // Results
            if (_isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              const Text('Testing...'),
            ],
            
            if (_result.isNotEmpty) ...[
              const Text(
                'Result:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(_result),
              ),
            ],
            
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Error:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _testPaymentMethods() async {
    setState(() {
      _isLoading = true;
      _result = '';
      _error = '';
    });

    try {
      final methods = await PayMongoService.getAvailablePaymentMethods();
      setState(() {
        final data = methods['data'] as List? ?? [];
        _result = 'Available Payment Methods:\n' +
            data.map((m) => '- ${m['attributes']['name'] ?? 'Unknown'}').join('\n');
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPaymentLink() async {
    setState(() {
      _isLoading = true;
      _result = '';
      _error = '';
    });

    try {
      final result = await PayMongoService.createPaymentLink(
        amount: 100.0,
        description: 'Test QRPH Payment',
        metadata: {
          'test': 'true',
          'payment_method': 'qrph',
        },
      );

      if (result['success']) {
        setState(() {
          _result = 'Payment Link Created Successfully!\n\n'
              'Checkout URL: ${result['checkoutUrl']}\n'
              'Link ID: ${result['linkId']}\n\n'
              'This should redirect to PayMongo with QRPH option.';
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Unknown error';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPaymentIntent() async {
    setState(() {
      _isLoading = true;
      _result = '';
      _error = '';
    });

    try {
      final result = await PayMongoService.createPaymentIntent(
        amount: 100.0,
        description: 'Test Payment Intent',
        metadata: {
          'test': 'true',
          'payment_method': 'gcash',
        },
      );

      if (result['success']) {
        setState(() {
          _result = 'Payment Intent Created Successfully!\n\n'
              'Payment Intent ID: ${result['paymentIntentId']}\n'
              'Client Key: ${result['clientKey']}\n\n'
              'Ready for GCash payment processing.';
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Unknown error';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
