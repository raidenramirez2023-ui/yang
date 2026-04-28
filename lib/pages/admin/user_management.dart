import 'package:flutter/material.dart';
import 'package:yang_chow/utils/app_theme.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ORG CHART HIERARCHICAL STRUCTURE
  final List<Map<String, dynamic>> orgHierarchy = [
    {
      'title': 'Restaurant Manager',
      'name': 'Tony Stark',
      'role': 'Supervisor',
      'level': 0,
      'icon': Icons.account_balance,
      'color': AppTheme.primaryColor,
      'image': 'https://picsum.photos/seed/tony/200/200.jpg',
      'id': 'EMP001',
    },
    {
      'title': 'Operations Supervisor',
      'name': 'Steve Rogers',
      'role': 'Supervisor',
      'level': 1,
      'icon': Icons.supervisor_account,
      'color': AppTheme.primaryColor,
      'image': 'https://picsum.photos/seed/steve/200/200.jpg',
      'id': 'EMP002',
    },
    {
      'title': 'Head Chef',
      'name': 'Gordon Ramsay',
      'role': 'Cook',
      'level': 2,
      'icon': Icons.restaurant,
      'color': Colors.orange,
      'image': 'https://picsum.photos/seed/gordon/200/200.jpg',
      'id': 'EMP003',
    },
    {
      'title': 'Sous Chef',
      'name': 'Jamie Oliver',
      'role': 'Cook',
      'level': 2,
      'icon': Icons.restaurant,
      'color': Colors.orange,
      'image': 'https://picsum.photos/seed/jamie/200/200.jpg',
      'id': 'EMP004',
    },
    {
      'title': 'Kitchen Prep',
      'name': 'Edward Scissorhands',
      'role': 'Cutter',
      'level': 3,
      'icon': Icons.content_cut,
      'color': Colors.green,
      'image': 'https://picsum.photos/seed/edward/200/200.jpg',
      'id': 'EMP005',
    },
    {
      'title': 'Kitchen Prep',
      'name': 'Wolverine',
      'role': 'Cutter',
      'level': 3,
      'icon': Icons.content_cut,
      'color': Colors.green,
      'image': 'https://picsum.photos/seed/wolverine/200/200.jpg',
      'id': 'EMP006',
    },
    {
      'title': 'Cashier',
      'name': 'Spongebob Squarepants',
      'role': 'Cashier & Food Server',
      'level': 2,
      'icon': Icons.point_of_sale,
      'color': Colors.purple,
      'image': 'https://picsum.photos/seed/spongebob/200/200.jpg',
      'id': 'EMP007',
    },
    {
      'title': 'Food Server',
      'name': 'Squidward Tentacles',
      'role': 'Cashier & Food Server',
      'level': 2,
      'icon': Icons.point_of_sale,
      'color': Colors.purple,
      'image': 'https://picsum.photos/seed/squidward/200/200.jpg',
      'id': 'EMP008',
    },
    {
      'title': 'Waitstaff',
      'name': 'Sanji',
      'role': 'Dine-in Food Server',
      'level': 2,
      'icon': Icons.room_service,
      'color': Colors.blue,
      'image': 'https://picsum.photos/seed/sanji/200/200.jpg',
      'id': 'EMP009',
    },
    {
      'title': 'Waitstaff',
      'name': 'Peter Parker',
      'role': 'Dine-in Food Server',
      'level': 2,
      'icon': Icons.room_service,
      'color': Colors.blue,
      'image': 'https://picsum.photos/seed/peter/200/200.jpg',
      'id': 'EMP010',
    },
    {
      'title': 'Waitstaff',
      'name': 'Clark Kent',
      'role': 'Dine-in Food Server',
      'level': 2,
      'icon': Icons.room_service,
      'color': Colors.blue,
      'image': 'https://picsum.photos/seed/clark/200/200.jpg',
      'id': 'EMP011',
    },
    {
      'title': 'Kitchen Utility',
      'name': 'John Doe',
      'role': 'Dishwasher',
      'level': 3,
      'icon': Icons.cleaning_services,
      'color': Colors.grey,
      'image': 'https://picsum.photos/seed/john/200/200.jpg',
      'id': 'EMP012',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.withOpacity(0.05),
      body: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER SECTION
            _buildHeader(context),
            const SizedBox(height: AppTheme.lg),

            // SEARCH BAR
            _buildSearchBar(context),
            const SizedBox(height: AppTheme.lg),

            // ORG CHART
            Expanded(
              child: SingleChildScrollView(
                child: _buildOrgChart(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ORGANIZATIONAL CHART',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.mediumGrey,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Staff Hierarchy',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search staff members...',
          hintStyle: TextStyle(color: AppTheme.mediumGrey),
          prefixIcon: Icon(Icons.search, color: AppTheme.mediumGrey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.md,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildOrgChart(BuildContext context) {
    // Filter staff based on search query
    final filteredStaff = orgHierarchy.where((staff) {
      if (_searchQuery.isEmpty) return true;
      final name = staff['name'].toString().toLowerCase();
      final role = staff['role'].toString().toLowerCase();
      final title = staff['title'].toString().toLowerCase();
      return name.contains(_searchQuery) || 
             role.contains(_searchQuery) || 
             title.contains(_searchQuery);
    }).toList();

    if (filteredStaff.isEmpty && _searchQuery.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 64, color: AppTheme.mediumGrey),
              const SizedBox(height: 16),
              Text(
                'No staff members found matching "$_searchQuery"',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.mediumGrey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Simple column layout for all staff
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredStaff.length,
      itemBuilder: (context, index) => _buildOrgBox(context, filteredStaff[index], 0),
    );
  }

  
  
  Widget _buildOrgBox(BuildContext context, Map<String, dynamic> staff, int level) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: (staff['color'] as Color).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _showStaffDialog(
          context, 
          staff['name'] as String, 
          staff['role'] as String, 
          staff['id'] as String,
          staff['image'] as String,
          staff['title'] as String,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: (staff['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: (staff['image'] as String).isNotEmpty
                      ? Image.network(
                          staff['image'] as String,
                          fit: BoxFit.cover,
                          width: 45,
                          height: 45,
                          errorBuilder: (context, error, stackTrace) => 
                            Icon(staff['icon'] as IconData, 
                                 color: staff['color'] as Color, 
                                 size: 22),
                        )
                      : Icon(staff['icon'] as IconData, 
                             color: staff['color'] as Color, 
                             size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      staff['name'] as String,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      staff['title'] as String,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumGrey,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Role Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (staff['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (staff['color'] as Color).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        staff['role'] as String,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: staff['color'] as Color,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Employee ID with icon
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.work_outline, size: 12, color: AppTheme.mediumGrey),
                      const SizedBox(width: 3),
                      Text(
                        staff['id'] as String,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.mediumGrey,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Active Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  
  void _showStaffDialog(BuildContext context, String name, String role, String employeeId, String? imageUrl, [String? title]) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Icon(Icons.person, size: 30, color: AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mediumGrey,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  role,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn(context, 'Employee ID', employeeId),
                  _buildStatColumn(context, 'Status', 'Active'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.mediumGrey,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
