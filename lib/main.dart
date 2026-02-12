import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Pages
import 'pages/login_page.dart';
import 'pages/admin_dashboard.dart';
import 'pages/pos_page.dart';
import 'pages/staff_dashboard.dart';
import 'pages/inventory_page.dart';
import 'pages/sales_report_page.dart';
import 'pages/user_management.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Initialize Firebase (ALL platforms)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const YangChowApp());
}

class YangChowApp extends StatelessWidget {
  const YangChowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yang Chow POS System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      initialRoute: '/',
      routes: {
        // Auth
        '/': (context) => const LoginPage(),

        // Admin routes
        '/admin': (context) => const AdminMainPage(),
        '/pos': (context) => const AdminMainPage(),
        '/inventory': (context) => const InventoryPage(),
        '/dashboard': (context) => const DashboardPage(),

        // Staff routes
        '/staff-dashboard': (context) => const StaffDashboardPage(),
      },
    );
  }
}
