import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/admin_dashboard.dart';        // Admin landing/dashboard (optional)
import 'pages/pos_page.dart';               // AdminMainPage (POS + Inventory + ...)
import 'pages/staff_dashboard.dart';
import 'pages/inventory_page.dart';         // Real InventoryPage
import 'pages/sales_report_page.dart';      // Sales Report Page
import 'pages/user_management.dart';        // User Management

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

        // Admin routes
        '/admin': (context) => const AdminMainPage(),      // Main admin hub (POS + Inventory + ...)
        '/pos': (context) => const AdminMainPage(),        // Alias for admin main hub
        '/inventory': (context) => const InventoryPage(),  // Optional direct inventory route
        // SalesReportPage and UserManagementPage are accessed inside AdminMainPage

        // Staff routes
        '/staff-dashboard': (context) => const StaffDashboardPage(),

        // Optional admin landing page (DashboardPage)
        '/dashboard': (context) => const DashboardPage(),
      },
    );
  }
}
