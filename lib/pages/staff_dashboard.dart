import 'package:flutter/material.dart';
import 'package:yang_chow/widgets/shared_pos_widget.dart';
import 'package:yang_chow/pages/staff_order_history_page.dart';
import 'package:yang_chow/main.dart'; // Import themeNotifier

class StaffDashboardPage extends StatelessWidget {
  const StaffDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        surfaceTintColor: theme.appBarTheme.backgroundColor,
        elevation: 0.5,
        toolbarHeight: 50,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(Icons.point_of_sale, color: Colors.red.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              'Staff POS System',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Current user info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(
                color: isDark ? Colors.white : Colors.grey.shade400,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person, color: theme.hintColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Staff',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.history, color: theme.hintColor),
            tooltip: 'Order History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StaffOrderHistoryPage(),
                ),
              );
            },
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentMode, child) {
              final isDarkTheme = currentMode == ThemeMode.dark;
              return IconButton(
                icon: Icon(
                  isDarkTheme ? Icons.light_mode : Icons.dark_mode,
                  color: theme.hintColor,
                ),
                tooltip: isDarkTheme ? 'Light Mode' : 'Dark Mode',
                onPressed: () {
                  themeNotifier.value =
                      isDarkTheme ? ThemeMode.light : ThemeMode.dark;
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: theme.hintColor),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/');
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: const SharedPOSWidget(userRole: 'Staff'),
    );
  }
}