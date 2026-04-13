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
      title: 'PayMongo Test',
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

  Future<void> _testPayMongo() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final result = await PayMongoService.createPaymentLink(
        amount: 5000.0, // 50.00 PHP in cents
        description: 'Test payment for Yang Chow Restaurant',
        returnUrl: 'https://yourapp.com/payment/success',
        metadata: {
          'test': 'true',
          'customer': 'test_user',
        },
      );

      setState(() {
        _result = 'Result: ${result.toString()}';
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
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
        title: const Text('PayMongo Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testPayMongo,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test PayMongo Integration'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _result,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
