import 'package:flutter/material.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  // GROUPED STAFF DATA (ROLE : COUNT)
  final Map<String, int> staffByRole = const {
    'Cook': 2,
    'Dishwasher': 1,
    'Cutter': 2,
    'Cashier & Food Server': 2,
    'Dine-in Food Server': 3,
    'Supervisor': 2,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Staff List',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.sm),
            Text(
              'Grouped by role',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppTheme.mediumGrey),
            ),
            const SizedBox(height: AppTheme.xl),

            // Grouped List
            Expanded(
              child: ListView(
                children: staffByRole.entries.map((entry) {
                  final role = entry.key;
                  final count = entry.value;

                  return _RoleSection(
                    role: role,
                    count: count,
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

class _RoleSection extends StatelessWidget {
  final String role;
  final int count;

  const _RoleSection({
    required this.role,
    required this.count,
  });

  IconData get _icon {
    switch (role) {
      case 'Cook':
        return Icons.restaurant;
      case 'Dishwasher':
        return Icons.cleaning_services;
      case 'Cutter':
        return Icons.content_cut;
      case 'Cashier & Food Server':
        return Icons.point_of_sale;
      case 'Dine-in Food Server':
        return Icons.room_service;
      case 'Supervisor':
        return Icons.supervisor_account;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION HEADER
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.sm),
          child: Text(
            '$role ($count)',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        // STAFF ROWS
        ...List.generate(
          count,
          (index) => Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            margin: const EdgeInsets.only(bottom: AppTheme.sm),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.15),
                child: Icon(_icon, color: AppTheme.primaryRed),
              ),
              title: Text(
                role,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),

        const SizedBox(height: AppTheme.lg),
      ],
    );
  }
}