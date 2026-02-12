import 'package:flutter/material.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  final Map<String, int> staffAssignment = const {
    'Kitchen': 4,
    'Waiter': 3,
    'Cashier': 3,
    'Manager': 2,
  };

  int get totalStaff =>
      staffAssignment.values.fold(0, (sum, count) => sum + count);

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Staff Assignment Overview',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.sm),
            Text(
              'Current staff distribution by department',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppTheme.mediumGrey),
            ),
            const SizedBox(height: AppTheme.xl),

            // Total Staff Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.xl),
                child: Row(
                  children: [
                    const Icon(Icons.people, size: 40),
                    const SizedBox(width: AppTheme.lg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Staff',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          totalStaff.toString(),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.xl),

            // Assignment Cards
            Expanded(
              child: GridView.count(
                crossAxisCount: isMobile ? 1 : 2,
                crossAxisSpacing: AppTheme.lg,
                mainAxisSpacing: AppTheme.lg,
                childAspectRatio: 2.5,
                children: staffAssignment.entries.map((entry) {
                  return _RoleCard(
                    role: entry.key,
                    count: entry.value,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String role;
  final int count;

  const _RoleCard({
    required this.role,
    required this.count,
  });

  IconData get _icon {
    switch (role) {
      case 'Kitchen':
        return Icons.restaurant;
      case 'Waiter':
        return Icons.room_service;
      case 'Cashier':
        return Icons.point_of_sale;
      case 'Manager':
        return Icons.supervisor_account;
      default:
        return Icons.people;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primaryRed.withOpacity(0.15),
              child: Icon(_icon, color: AppTheme.primaryRed),
            ),
            const SizedBox(width: AppTheme.lg),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  role,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.sm),
                Text(
                  '$count assigned',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.mediumGrey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
