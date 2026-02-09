import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/admin_dashboard.dart';
import 'pages/pos_page.dart';
import 'pages/staff_dashboard.dart';
import 'pages/inventory_page.dart';
import 'pages/sales_report_page.dart'; // Add this import

void main() {
  runApp(const YangChowApp());
}

class YangChowApp extends StatelessWidget {
  const YangChowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yang Chow POS System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/pos': (context) => const AdminMainPage(),
        '/staff-dashboard': (context) => const StaffDashboardPage(),
        '/inventory': (context) => const InventoryPage(),
        '/sales-report': (context) => const SalesReportPage(),
      },
    );
  }
}