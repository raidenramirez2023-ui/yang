import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Load environment variables
  await dotenv.load(fileName: '.env');

  debugPrint('=== PayMongo Environment Check ===');
  
  // Check PayMongo keys
  final publicKey = dotenv.env['PAYMONGO_PUBLIC_KEY'];
  final secretKey = dotenv.env['PAYMONGO_SECRET_KEY'];
  
  debugPrint('Public Key: ${publicKey != null ? "Found (${publicKey.substring(0, 8)}...)" : "NOT FOUND"}');
  debugPrint('Secret Key: ${secretKey != null ? "Found" : "NOT FOUND"}');
  
  if (publicKey == null || secretKey == null) {
    debugPrint('\nERROR: PayMongo keys are missing!');
    debugPrint('Please copy .env.example to .env and add your PayMongo API keys.');
    debugPrint('\nGet your keys from: https://dashboard.paymongo.com/');
  } else {
    debugPrint('\nSUCCESS: PayMongo keys are configured!');
    
    // Check if keys are in test mode
    if (publicKey.startsWith('pk_test_')) {
      debugPrint('Mode: TEST (Good for development)');
    } else if (publicKey.startsWith('pk_live_')) {
      debugPrint('Mode: LIVE (Production mode - be careful!)');
    } else {
      debugPrint('Warning: Unusual key format detected');
    }
  }
  
  debugPrint('\n=== Supabase Environment Check ===');
  
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
  
  debugPrint('Supabase URL: ${supabaseUrl != null ? "Found" : "NOT FOUND"}');
  debugPrint('Supabase Anon Key: ${supabaseAnonKey != null ? "Found" : "NOT FOUND"}');
  
  if (supabaseUrl == null || supabaseAnonKey == null) {
    debugPrint('\nWARNING: Supabase keys are missing!');
  } else {
    debugPrint('\nSUCCESS: Supabase keys are configured!');
  }
}
