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
    return Padding(
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

  String _getMockName(String role, int index) {
    final Map<String, List<String>> mockNames = {
      'Cook': ['Gordon Ramsay', 'Jamie Oliver'],
      'Dishwasher': ['John Doe'],
      'Cutter': ['Edward Scissorhands', 'Wolverine'],
      'Cashier & Food Server': ['Spongebob Squarepants', 'Squidward Tentacles'],
      'Dine-in Food Server': ['Sanji', 'Peter Parker', 'Clark Kent'],
      'Supervisor': ['Tony Stark', 'Steve Rogers'],
    };

    if (mockNames.containsKey(role) && index < mockNames[role]!.length) {
      return mockNames[role]![index];
    }
    
    // Fallback names
    final fallbacks = ['Alice', 'Bob', 'Charlie', 'David', 'Eve'];
    return '${fallbacks[index % fallbacks.length]} (Staff ${index + 1})';
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
          (index) {
            final mockName = _getMockName(role, index);
            final initials = mockName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();

            return Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              margin: const EdgeInsets.only(bottom: AppTheme.sm),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: 4),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.15),
                              child: Icon(_icon, size: 36, color: AppTheme.primaryRed),
                            ),
                            const SizedBox(height: AppTheme.md),
                            Text(
                              mockName,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppTheme.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.sm,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: Text(
                                role,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primaryRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTheme.lg),
                            const Divider(),
                            const SizedBox(height: AppTheme.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatColumn(context, 'Shift', 'Morning'),
                                _buildStatColumn(context, 'Status', 'Active'),
                              ],
                            ),
                            const SizedBox(height: AppTheme.xl),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primaryRed,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close Profile'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.1),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  mockName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '$role • ID: ${1000 + index * 7 + role.hashCode.abs() % 100}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumGrey,
                      ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right, size: 20, color: AppTheme.mediumGrey),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: AppTheme.lg),
      ],
    );
  }

  Widget _buildStatColumn(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.mediumGrey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}