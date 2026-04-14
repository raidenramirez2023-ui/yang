import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yang_chow/services/paymongo_service.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  runApp(const DebugApp());
}

class DebugApp extends StatelessWidget {
  const DebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('PayMongo Debug')),
        body: const PaymentDebugPage(),
      ),
    );
  }
}

class PaymentDebugPage extends StatefulWidget {
  const PaymentDebugPage({super.key});

  @override
  State<PaymentDebugPage> createState() => _PaymentDebugPageState();
}

class _PaymentDebugPageState extends State<PaymentDebugPage> {
  String _debugInfo = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: _isLoading ? null : _debugEnvironment,
            child: const Text('Debug Environment'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _isLoading ? null : _testPaymentLink,
            child: const Text('Test Payment Link'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _debugInfo,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _debugEnvironment() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Checking environment...\n\n';
    });

    try {
      // Check PayMongo keys
      final publicKey = dotenv.env['PAYMONGO_PUBLIC_KEY'];
      final secretKey = dotenv.env['PAYMONGO_SECRET_KEY'];
      
      setState(() {
        _debugInfo += 'PAYMONGO_PUBLIC_KEY: ${publicKey != null ? "Found (${publicKey.substring(0, 8)}...)" : "NOT FOUND"}\n';
        _debugInfo += 'PAYMONGO_SECRET_KEY: ${secretKey != null ? "Found" : "NOT FOUND"}\n\n';
        
        if (publicKey == null || secretKey == null) {
          _debugInfo += 'ERROR: PayMongo keys are missing!\n';
          _debugInfo += 'Please add them to your .env file:\n';
          _debugInfo += 'PAYMONGO_PUBLIC_KEY=pk_test_your_key_here\n';
          _debugInfo += 'PAYMONGO_SECRET_KEY=sk_test_your_key_here\n';
        } else {
          _debugInfo += 'SUCCESS: PayMongo keys are configured!\n';
          
          if (publicKey.startsWith('pk_test_')) {
            _debugInfo += 'Mode: TEST\n';
          } else if (publicKey.startsWith('pk_live_')) {
            _debugInfo += 'Mode: LIVE\n';
          } else {
            _debugInfo += 'WARNING: Invalid key format\n';
          }
        }
      });
    } catch (e) {
      setState(() {
        _debugInfo += 'Error checking environment: $e\n';
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
      _debugInfo = 'Testing payment link creation...\n\n';
    });

    try {
      final result = await PayMongoService.createPaymentLink(
        amount: 100.0,
        description: 'Test Payment',
        metadata: {'test': 'true'},
      );

      setState(() {
        if (result['success']) {
          _debugInfo += 'SUCCESS: Payment link created!\n\n';
          _debugInfo += 'Checkout URL: ${result['checkoutUrl']}\n';
          _debugInfo += 'Link ID: ${result['linkId']}\n';
        } else {
          _debugInfo += 'ERROR: Payment link creation failed!\n\n';
          _debugInfo += 'Error: ${result['error']}\n';
        }
      });
    } catch (e) {
      setState(() {
        _debugInfo += 'Exception: $e\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
