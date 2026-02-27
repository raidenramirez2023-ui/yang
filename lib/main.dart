import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_options.dart';  // Supabase configuration
import 'utils/app_theme.dart';

// Features
import 'pages/login_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/update_password_page.dart';
import 'pages/admin_main_page.dart';
import 'pages/staff_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Supabase with platform-specific configuration
    await Supabase.initialize(
      url: SupabaseOptions.supabaseUrl,
      anonKey: SupabaseOptions.supabaseAnonKey,
      debug: true, // Enable debug mode for better error messages
    );
    print('✅ Supabase initialized successfully');
  } catch (e) {
    print('❌ Supabase initialization failed: $e');
    print('Please check your Supabase configuration in lib/supabase_options.dart');
    
    // Continue with app even if Supabase fails (for testing)
    print('⚠️ Continuing with app in offline mode...');
  }

  runApp(const YangChowApp());
}

class YangChowApp extends StatelessWidget {
  const YangChowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yang Chow Restaurant Management System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        // Auth routes
        '/': (context) => const LoginPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),

        // Admin routes
        '/dashboard': (context) => const AdminMainPage(),

        // Staff routes
        '/staff-dashboard': (context) => const StaffDashboardPage(),
      },
    );
  }
}
