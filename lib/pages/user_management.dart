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

  // GROUPED STAFF DATA WITH DISPLAY TYPE
  final Map<String, Map<String, dynamic>> staffByRole = const {
    'Supervisor': {
      'count': 2,
      'displayType': 'card', // Card layout for supervisors
    },
    'Cook': {
      'count': 2,
      'displayType': 'card', // Card layout for culinary team
    },
    'Dishwasher': {
      'count': 1,
      'displayType': 'list', // Table-like layout for service & support
    },
    'Cutter': {
      'count': 2,
      'displayType': 'list',
    },
    'Cashier & Food Server': {
      'count': 2,
      'displayType': 'list',
    },
    'Dine-in Food Server': {
      'count': 3,
      'displayType': 'list',
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.withValues(alpha: 0.05),
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

            // STAFF SECTIONS
            Expanded(
              child: ListView(
                children: staffByRole.entries.map((entry) {
                  final role = entry.key;
                  final data = entry.value;
                  final count = data['count'] as int;
                  final displayType = data['displayType'] as String;

                  return _RoleSection(
                    role: role,
                    count: count,
                    displayType: displayType,
                    searchQuery: _searchQuery,
                  );
                }).toList(),
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
          'PERSONNEL DIRECTORY',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.mediumGrey,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Staff List',
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
            color: Colors.black.withValues(alpha: 0.05),
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
}

class _RoleSection extends StatelessWidget {
  final String role;
  final int count;
  final String displayType;
  final String searchQuery;

  const _RoleSection({
    required this.role,
    required this.count,
    required this.displayType,
    required this.searchQuery,
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

  String _getMockImage(String role, int index) {
    final Map<String, List<String>> mockImages = {
      'Cook': [
        'https://picsum.photos/seed/gordon/200/200.jpg',
        'https://picsum.photos/seed/jamie/200/200.jpg'
      ],
      'Dishwasher': ['https://picsum.photos/seed/john/200/200.jpg'],
      'Cutter': [
        'https://picsum.photos/seed/edward/200/200.jpg',
        'https://picsum.photos/seed/wolverine/200/200.jpg'
      ],
      'Cashier & Food Server': [
        'https://picsum.photos/seed/spongebob/200/200.jpg',
        'https://picsum.photos/seed/squidward/200/200.jpg'
      ],
      'Dine-in Food Server': [
        'https://picsum.photos/seed/sanji/200/200.jpg',
        'https://picsum.photos/seed/peter/200/200.jpg',
        'https://picsum.photos/seed/clark/200/200.jpg'
      ],
      'Supervisor': [
        'https://picsum.photos/seed/tony/200/200.jpg',
        'https://picsum.photos/seed/steve/200/200.jpg'
      ],
    };

    if (mockImages.containsKey(role) && index < mockImages[role]!.length) {
      return mockImages[role]![index];
    }
    return 'https://picsum.photos/seed/default/200/200.jpg'; // Fallback image
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION HEADER
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.md),
          child: Text(
            '$role ($count)',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),

        // STAFF DISPLAY BASED ON TYPE
        if (displayType == 'card')
          _buildCardLayout(context)
        else
          _buildListLayout(context),

        const SizedBox(height: AppTheme.xl),
      ],
    );
  }

  Widget _buildCardLayout(BuildContext context) {
    // Filter staff based on search query
    List<int> filteredIndices = [];
    for (int i = 0; i < count; i++) {
      final mockName = _getMockName(role, i).toLowerCase();
      if (searchQuery.isEmpty || 
          mockName.contains(searchQuery) || 
          role.toLowerCase().contains(searchQuery)) {
        filteredIndices.add(i);
      }
    }

    if (filteredIndices.isEmpty && searchQuery.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No staff members found matching "$searchQuery"',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.mediumGrey,
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.6,
      ),
      itemCount: searchQuery.isEmpty ? count : filteredIndices.length,
      itemBuilder: (context, index) {
        final actualIndex = searchQuery.isEmpty ? index : filteredIndices[index];
        final mockName = _getMockName(role, actualIndex);
        final mockImage = _getMockImage(role, actualIndex);
        final employeeId = 1000 + actualIndex * 7 + role.hashCode.abs() % 100;

        return Card(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showStaffDialog(context, mockName, role, employeeId, mockImage),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: NetworkImage(mockImage),
                    child: mockImage.isEmpty ? Icon(_icon, size: 28, color: AppTheme.primaryRed) : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mockName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: $employeeId',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                  const Spacer(),
                  _buildActiveStatus(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListLayout(BuildContext context) {
    // Filter staff based on search query
    List<int> filteredIndices = [];
    for (int i = 0; i < count; i++) {
      final mockName = _getMockName(role, i).toLowerCase();
      if (searchQuery.isEmpty || 
          mockName.contains(searchQuery) || 
          role.toLowerCase().contains(searchQuery)) {
        filteredIndices.add(i);
      }
    }

    if (filteredIndices.isEmpty && searchQuery.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No staff members found matching "$searchQuery"',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.mediumGrey,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(
          searchQuery.isEmpty ? count : filteredIndices.length,
          (index) {
            final actualIndex = searchQuery.isEmpty ? index : filteredIndices[index];
            final mockName = _getMockName(role, actualIndex);
            final mockImage = _getMockImage(role, actualIndex);
            final employeeId = 1000 + actualIndex * 7 + role.hashCode.abs() % 100;
            final isLast = index == (searchQuery.isEmpty ? count : filteredIndices.length) - 1;

            return Column(
              children: [
                InkWell(
                  onTap: () => _showStaffDialog(context, mockName, role, employeeId, mockImage),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: NetworkImage(mockImage),
                          child: mockImage.isEmpty ? Text(
                            mockName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.primaryRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mockName,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                role,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'ID: $employeeId',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.mediumGrey,
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildActiveStatus(),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            // More options
                          },
                          icon: const Icon(Icons.more_vert, color: AppTheme.mediumGrey),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveStatus() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Active',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showStaffDialog(BuildContext context, String name, String role, int employeeId, [String? imageUrl]) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey[200],
                backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                child: imageUrl == null || imageUrl.isEmpty ? Icon(_icon, size: 36, color: AppTheme.primaryRed) : null,
              ),
              const SizedBox(height: 16),
              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  role,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn(context, 'Shift', 'Morning'),
                  _buildStatColumn(context, 'Status', 'Active'),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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