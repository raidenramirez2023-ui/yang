import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Load environment variables
  await dotenv.load(fileName: '.env');

  print('=== PayMongo Environment Check ===');
  
  // Check PayMongo keys
  final publicKey = dotenv.env['PAYMONGO_PUBLIC_KEY'];
  final secretKey = dotenv.env['PAYMONGO_SECRET_KEY'];
  
  print('Public Key: ${publicKey != null ? "Found (${publicKey.substring(0, 8)}...)" : "NOT FOUND"}');
  print('Secret Key: ${secretKey != null ? "Found" : "NOT FOUND"}');
  
  if (publicKey == null || secretKey == null) {
    print('\nERROR: PayMongo keys are missing!');
    print('Please copy .env.example to .env and add your PayMongo API keys.');
    print('\nGet your keys from: https://dashboard.paymongo.com/');
  } else {
    print('\nSUCCESS: PayMongo keys are configured!');
    
    // Check if keys are in test mode
    if (publicKey.startsWith('pk_test_')) {
      print('Mode: TEST (Good for development)');
    } else if (publicKey.startsWith('pk_live_')) {
      print('Mode: LIVE (Production mode - be careful!)');
    } else {
      print('Warning: Unusual key format detected');
    }
  }
  
  print('\n=== Supabase Environment Check ===');
  
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
  
  print('Supabase URL: ${supabaseUrl != null ? "Found" : "NOT FOUND"}');
  print('Supabase Anon Key: ${supabaseAnonKey != null ? "Found" : "NOT FOUND"}');
  
  if (supabaseUrl == null || supabaseAnonKey == null) {
    print('\nWARNING: Supabase keys are missing!');
  } else {
    print('\nSUCCESS: Supabase keys are configured!');
  }
}
