import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yang_chow/services/paymongo_service.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  runApp(const DebugPayMongoApp());
}

class DebugPayMongoApp extends StatelessWidget {
  const DebugPayMongoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('PayMongo Error Debug')),
        body: const PayMongoDebugPage(),
      ),
    );
  }
}

class PayMongoDebugPage extends StatefulWidget {
  const PayMongoDebugPage({super.key});

  @override
  State<PayMongoDebugPage> createState() => _PayMongoDebugPageState();
}

class _PayMongoDebugPageState extends State<PayMongoDebugPage> {
  String _debugLog = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: _isLoading ? null : _testPaymentLinkCreation,
            child: const Text('Test Payment Link Creation'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _isLoading ? null : _testEnvironment,
            child: const Text('Check Environment'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _debugLog,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testEnvironment() async {
    setState(() {
      _isLoading = true;
      _debugLog = '=== ENVIRONMENT CHECK ===\n\n';
    });

    try {
      // Check environment variables
      final publicKey = dotenv.env['PAYMONGO_PUBLIC_KEY'];
      final secretKey = dotenv.env['PAYMONGO_SECRET_KEY'];
      
      _debugLog += 'PAYMONGO_PUBLIC_KEY: ${publicKey != null ? "Found (${publicKey.substring(0, 8)}...)" : "NOT FOUND"}\n';
      _debugLog += 'PAYMONGO_SECRET_KEY: ${secretKey != null ? "Found (${secretKey.substring(0, 8)}...)" : "NOT FOUND"}\n\n';
      
      if (publicKey == null || secretKey == null) {
        _debugLog += 'ERROR: PayMongo keys missing!\n';
      } else {
        _debugLog += 'SUCCESS: PayMongo keys found\n';
        _debugLog += 'Public Key starts with: ${publicKey.substring(0, 8)}\n';
        _debugLog += 'Secret Key starts with: ${secretKey.substring(0, 8)}\n';
      }
      
    } catch (e) {
      _debugLog += 'Environment check error: $e\n';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPaymentLinkCreation() async {
    setState(() {
      _isLoading = true;
      _debugLog = '=== PAYMENT LINK CREATION TEST ===\n\n';
    });

    try {
      _debugLog += 'Creating payment link with amount: 100.0\n';
      _debugLog += 'Description: Test Payment\n\n';
      
      final result = await PayMongoService.createPaymentLink(
        amount: 100.0,
        description: 'Test Payment',
        metadata: {
          'test': 'true',
          'source': 'debug_app',
        },
      );

      _debugLog += '=== RESULT ===\n';
      _debugLog += 'Success: ${result['success']}\n\n';
      
      if (result['success']) {
        _debugLog += 'Checkout URL: ${result['checkoutUrl']}\n';
        _debugLog += 'Link ID: ${result['linkId']}\n\n';
        _debugLog += 'SUCCESS: Payment link created successfully!\n';
      } else {
        _debugLog += 'ERROR: ${result['error']}\n\n';
        _debugLog += 'This is likely causing the "Failed to initialize payment" error.\n';
      }
      
    } catch (e) {
      _debugLog += 'EXCEPTION: $e\n\n';
      _debugLog += 'This exception is causing the payment initialization to fail.\n';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
