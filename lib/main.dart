import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';  // Keep this import
import 'utils/app_theme.dart';

// Features
import 'pages/login_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/admin_main_page.dart';
import 'pages/staff_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (ALL platforms) - Keep this
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
