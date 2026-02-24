// Supabase configuration file
// Replace with your actual Supabase project credentials
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class SupabaseOptions {
  // 🔑 Replace these with your actual Supabase project credentials
  // Get these from: Supabase Dashboard → Project Settings → API
  static const String supabaseUrl = 'https://tvzbsvqaikjkxrqykrhw.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2emJzdnFhaWtqa3hycXlrcmh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MTIwNzQsImV4cCI6MjA4NzQ4ODA3NH0.5cE-OTWEgLTP2vgteqk6-8bfw-ZGahdc8dBJOaUtzrQ';
  
  // Get current platform configuration (similar to Firebase)
  static Map<String, dynamic> get currentPlatform {
    if (kIsWeb) {
      return _webConfig;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidConfig;
      case TargetPlatform.iOS:
        return _iosConfig;
      case TargetPlatform.macOS:
        return _macosConfig;
      case TargetPlatform.windows:
        return _windowsConfig;
      case TargetPlatform.linux:
        return _linuxConfig;
      default:
        throw UnsupportedError(
          'Supabase options have not been configured for this platform',
        );
    }
  }

  // Platform-specific configurations (if needed)
  static const Map<String, dynamic> _webConfig = {
    'url': supabaseUrl,
    'anonKey': supabaseAnonKey,
  };

  static const Map<String, dynamic> _androidConfig = {
    'url': supabaseUrl,
    'anonKey': supabaseAnonKey,
  };

  static const Map<String, dynamic> _iosConfig = {
    'url': supabaseUrl,
    'anonKey': supabaseAnonKey,
  };

  static const Map<String, dynamic> _macosConfig = {
    'url': supabaseUrl,
    'anonKey': supabaseAnonKey,
  };

  static const Map<String, dynamic> _windowsConfig = {
    'url': supabaseUrl,
    'anonKey': supabaseAnonKey,
  };

  static const Map<String, dynamic> _linuxConfig = {
    'url': supabaseUrl,
    'anonKey': supabaseAnonKey,
  };
}
