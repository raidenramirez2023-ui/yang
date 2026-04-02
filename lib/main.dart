import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_options.dart'; // Supabase configuration
import 'utils/app_theme.dart';
import 'services/app_settings_service.dart';

// Features
import 'pages/login_page.dart';
import 'pages/customer_registration_page.dart';
import 'pages/staff_login_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/landing_page.dart';
import 'pages/customer_dashboard.dart';
import 'pages/admin_main_page.dart';
import 'pages/admin_reservations_page.dart';
import 'pages/staff_dashboard.dart';
import 'pages/pagsanjaninv_dashboard.dart';
import 'pages/chef_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    await dotenv.load(fileName: '.env');
    debugPrint('✅ Environment variables loaded');
  } catch (e) {
    debugPrint('⚠️ Could not load .env file: $e');
  }

  try {
    // Initialize Supabase with platform-specific configuration
    await Supabase.initialize(
      url: SupabaseOptions.supabaseUrl,
      anonKey: SupabaseOptions.supabaseAnonKey,
      debug: true, // Enable debug mode for better error messages
    );
    debugPrint('✅ Supabase initialized successfully');

    // Initialize application settings from database
    try {
      final appSettings = AppSettingsService();
      await appSettings.initializeSettings();
      debugPrint('✅ Application settings loaded');
    } catch (e) {
      debugPrint('⚠️ Could not load app settings: $e (using defaults)');
    }
  } catch (e) {
    debugPrint('❌ Supabase initialization failed: $e');
    debugPrint(
      'Please check your Supabase configuration in lib/supabase_options.dart',
    );

    // Continue with app even if Supabase fails (for testing)
    debugPrint('⚠️ Continuing with app in offline mode...');
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
        '/': (context) => const LandingPage(),
        '/login': (context) => const LoginPage(),
        '/staff-login': (context) => const StaffLoginPage(),
        '/register': (context) => const CustomerRegistrationPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/customer-dashboard': (context) => const CustomerDashboardPage(),
        '/dashboard': (context) => const AdminMainPage(),
        '/admin-reservations': (context) => const AdminReservationsPage(),
        '/pagsanjaninv-dashboard': (context) => const PagsanjaninvDashboardPage(),
        '/staff-dashboard': (context) => const StaffDashboardPage(),
        '/chef-dashboard': (context) => const ChefDashboardPage(),
      },
    );
  }
}
