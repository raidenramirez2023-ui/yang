import 'dart:async';
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_options.dart'; // Supabase configuration

import 'utils/app_theme.dart';

import 'services/app_settings_service.dart';

// Features

import 'pages/login_page.dart';

import 'pages/customer/customer_registration_page.dart';

import 'pages/staff/staff_login_page.dart';

import 'pages/forgot_password_page.dart';

import 'pages/simple_password_reset.dart';

import 'utils/deep_link_service.dart';

import 'pages/test_email_template.dart';

import 'pages/template_fix_complete.dart';

import 'pages/otp_password_reset.dart';

import 'pages/landing_page.dart';

import 'pages/customer/customer_dashboard.dart';

import 'pages/admin/admin_main_page.dart';

import 'pages/admin/admin_reservations_page.dart';

import 'pages/staff/staff_dashboard.dart';

import 'pages/admin/pagsanjaninv_dashboard.dart';

import 'pages/staff/chef_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Don't block app initialization on Supabase/Settings loading
  // Initialize these in the background instead
  _initializeServices();

  runApp(const YangChowApp());
}

/// Initialize Supabase and app settings in the background
Future<void> _initializeServices() async {
  try {
    // Add a timeout to Supabase initialization to prevent hanging
    await Supabase.initialize(
      url: SupabaseOptions.supabaseUrl,
      anonKey: SupabaseOptions.supabaseAnonKey,
      debug: true,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint('⚠️ Supabase initialization timed out');
        throw TimeoutException('Supabase initialization timed out');
      },
    );

    debugPrint('✅ Supabase initialized successfully');

    // Initialize application settings from database with timeout
    try {
      final appSettings = AppSettingsService();
      await appSettings.initializeSettings().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ App settings initialization timed out');
        },
      );
      debugPrint('✅ Application settings loaded');
    } catch (e) {
      debugPrint('⚠️ Could not load app settings: $e (using defaults)');
    }
  } catch (e) {
    debugPrint('❌ Background initialization error: $e');
    // App continues to run with offline mode
  }
}

class YangChowApp extends StatelessWidget {
  const YangChowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yang Chow Restaurant',

      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      initialRoute: '/',

      routes: {
        '/': (context) => const LandingPage(),

        '/login': (context) => const LoginPage(),

        '/staff-login': (context) => const StaffLoginPage(),

        '/register': (context) => const CustomerRegistrationPage(),

        '/forgot-password': (context) => const ForgotPasswordPage(),

        '/reset-password': (context) => const SimplePasswordResetPage(),

        '/test-email-template': (context) => const TestEmailTemplate(),

        '/template-fix-complete': (context) => const TemplateFixComplete(),

        '/otp-password-reset': (context) {
          final email = ModalRoute.of(context)?.settings.arguments as String? ?? '';
          return OtpPasswordResetPage(email: email);
        },

        '/customer-dashboard': (context) => const CustomerDashboardPage(),

        '/dashboard': (context) => const AdminMainPage(),

        '/admin-reservations': (context) => const AdminReservationsPage(),

        '/pagsanjaninv-dashboard': (context) =>
            const PagsanjaninvDashboardPage(),

        '/staff-dashboard': (context) => const StaffDashboardPage(),

        '/chef-dashboard': (context) => const ChefDashboardPage(),
      },
    );
  }
}
