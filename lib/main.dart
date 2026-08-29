import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_options.dart'; // Supabase configuration

import 'utils/app_theme.dart';
import 'utils/global_messenger.dart';

import 'services/app_settings_service.dart';

// Auth Guard
import 'widgets/auth_guard.dart';

// Features

import 'pages/login_page.dart';

import 'pages/customer/customer_registration_page.dart';

import 'pages/staff/staff_login_page.dart';

import 'pages/forgot_password_page.dart';

import 'pages/simple_password_reset.dart';

import 'pages/test_email_template.dart';

import 'pages/template_fix_complete.dart';

import 'pages/privacy_policy_page.dart';

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
  usePathUrlStrategy();

  // Initialize environment variables
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Environment variables loaded');
  } catch (e) {
    debugPrint('⚠️ Error loading .env file: $e');
  }

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
      navigatorKey: GlobalMessenger.navigatorKey,
      scaffoldMessengerKey: GlobalMessenger.key,
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

        '/privacy': (context) => const PrivacyPolicyPage(),

        '/otp-password-reset': (context) {
          final email = ModalRoute.of(context)?.settings.arguments as String? ?? '';
          return OtpPasswordResetPage(email: email);
        },

        // ==========================================
        // Admin Portal Routes (with Deep Linking)
        // ==========================================
        '/admin/dashboard': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 0),
        ),
        '/admin/sales-reports': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 1),
        ),
        '/admin/inventory': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 2),
        ),
        '/admin/inventory-forecast': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 3),
        ),
        '/admin/menu-management': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 4),
        ),
        '/admin/reservations': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 5),
        ),
        '/admin/payment-management': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 6),
        ),
        '/admin/employee-management': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 7),
        ),
        '/admin/customers-reviews': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 8),
        ),
        '/admin/announcements': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 9),
        ),
        '/admin/customer-chat': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 10),
        ),
        '/admin/petty-cash': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 11),
        ),
        '/admin/refunds-reschedules': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 12),
        ),
        '/admin/audit-logs': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 13),
        ),
        '/admin/backup-restore': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(initialIndex: 14),
        ),

        // ==========================================
        // Chef Portal Routes (with Deep Linking)
        // ==========================================
        '/chef/dashboard': (context) => const AuthGuard(
          allowedRoles: ['chef'],
          redirectRoute: '/staff-login',
          child: ChefDashboardPage(initialTab: 0),
        ),
        '/chef/kitchen': (context) => const AuthGuard(
          allowedRoles: ['chef'],
          redirectRoute: '/staff-login',
          child: ChefDashboardPage(initialTab: 0),
        ),
        '/chef/events': (context) => const AuthGuard(
          allowedRoles: ['chef'],
          redirectRoute: '/staff-login',
          child: ChefDashboardPage(initialTab: 1),
        ),
        '/chef/finished': (context) => const AuthGuard(
          allowedRoles: ['chef'],
          redirectRoute: '/staff-login',
          child: ChefDashboardPage(initialTab: 2),
        ),
        '/chef/requests': (context) => const AuthGuard(
          allowedRoles: ['chef'],
          redirectRoute: '/staff-login',
          child: ChefDashboardPage(initialTab: 3),
        ),
        '/chef/stock': (context) => const AuthGuard(
          allowedRoles: ['chef'],
          redirectRoute: '/staff-login',
          child: ChefDashboardPage(initialTab: 4),
        ),

        // ==========================================
        // Main Inventory Portal Routes (with Deep Linking)
        // ==========================================
        '/inventory/dashboard': (context) => const AuthGuard(
          allowedRoles: ['pagsanjaninv', 'inventory staff'],
          redirectRoute: '/staff-login',
          child: PagsanjaninvDashboardPage(initialIndex: 0),
        ),
        '/inventory/kitchen-requests': (context) => const AuthGuard(
          allowedRoles: ['pagsanjaninv', 'inventory staff'],
          redirectRoute: '/staff-login',
          child: PagsanjaninvDashboardPage(initialIndex: 1),
        ),
        '/inventory/manage-inventory': (context) => const AuthGuard(
          allowedRoles: ['pagsanjaninv', 'inventory staff'],
          redirectRoute: '/staff-login',
          child: PagsanjaninvDashboardPage(initialIndex: 2),
        ),
        '/inventory/storage-room': (context) => const AuthGuard(
          allowedRoles: ['pagsanjaninv', 'inventory staff'],
          redirectRoute: '/staff-login',
          child: PagsanjaninvDashboardPage(initialIndex: 3),
        ),
        '/inventory/petty-cash': (context) => const AuthGuard(
          allowedRoles: ['pagsanjaninv', 'inventory staff'],
          redirectRoute: '/staff-login',
          child: PagsanjaninvDashboardPage(initialIndex: 4),
        ),
        '/inventory/spoilage-waste': (context) => const AuthGuard(
          allowedRoles: ['pagsanjaninv', 'inventory staff'],
          redirectRoute: '/staff-login',
          child: PagsanjaninvDashboardPage(initialIndex: 5),
        ),

        // ==========================================
        // Customer Portal Routes (with Deep Linking)
        // ==========================================
        '/customer/dashboard': (context) => const AuthGuard(
          allowedRoles: ['customer'],
          redirectRoute: '/login',
          child: CustomerDashboardPage(initialIndex: 0),
        ),
        '/customer/home': (context) => const AuthGuard(
          allowedRoles: ['customer'],
          redirectRoute: '/login',
          child: CustomerDashboardPage(initialIndex: 0),
        ),
        '/customer/reservations': (context) => const AuthGuard(
          allowedRoles: ['customer'],
          redirectRoute: '/login',
          child: CustomerDashboardPage(initialIndex: 1),
        ),
        '/customer/transactions': (context) => const AuthGuard(
          allowedRoles: ['customer'],
          redirectRoute: '/login',
          child: CustomerDashboardPage(initialIndex: 2),
        ),
        '/customer/activity': (context) => const AuthGuard(
          allowedRoles: ['customer'],
          redirectRoute: '/login',
          child: CustomerDashboardPage(initialIndex: 3),
        ),
        '/customer/order-list': (context) => const AuthGuard(
          allowedRoles: ['customer'],
          redirectRoute: '/login',
          child: CustomerDashboardPage(initialIndex: 4),
        ),
        '/customer/profile': (context) => const AuthGuard(
          allowedRoles: ['customer'],
          redirectRoute: '/login',
          child: CustomerDashboardPage(initialIndex: 5),
        ),

        // ==========================================
        // Staff POS Portal Routes
        // ==========================================
        '/staff/dashboard': (context) => const AuthGuard(
          allowedRoles: ['staff'],
          redirectRoute: '/staff-login',
          child: StaffDashboardPage(),
        ),

        // ==========================================
        // Legacy Route Aliases (For backward compatibility)
        // ==========================================
        '/customer-dashboard': (context) => const AuthGuard(
          allowedRoles: ['customer'],
          redirectRoute: '/login',
          child: CustomerDashboardPage(),
        ),

        '/dashboard': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminMainPage(),
        ),

        '/admin-reservations': (context) => const AuthGuard(
          allowedRoles: ['admin'],
          redirectRoute: '/staff-login',
          child: AdminReservationsPage(),
        ),

        '/pagsanjaninv-dashboard': (context) => const AuthGuard(
          allowedRoles: ['pagsanjaninv', 'inventory staff'],
          redirectRoute: '/staff-login',
          child: PagsanjaninvDashboardPage(),
        ),

        '/staff-dashboard': (context) => const AuthGuard(
          allowedRoles: ['staff'],
          redirectRoute: '/staff-login',
          child: StaffDashboardPage(),
        ),

        '/chef-dashboard': (context) => const AuthGuard(
          allowedRoles: ['chef'],
          redirectRoute: '/staff-login',
          child: ChefDashboardPage(),
        ),


      },
    );
  }
}
