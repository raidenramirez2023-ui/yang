import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'developer_theme.dart';

class UserMonitoringPage extends StatefulWidget {
  const UserMonitoringPage({super.key});

  @override
  State<UserMonitoringPage> createState() => _UserMonitoringPageState();
}

class _UserMonitoringPageState extends State<UserMonitoringPage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  static const int _pageSize = 30;

  String _searchQuery = '';
  String _selectedRoleFilter = 'All Roles';

  final List<String> _roles = [
    'All Roles',
    'developer',
    'admin',
    'staff',
    'chef',
    'pagsanjaninv',
    'inventory staff',
    'customer',
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select()
          .order('created_at', ascending: false)
          .limit(1000);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
          final totalPages = (_users.length / _pageSize).ceil().clamp(1, 99999);
          if (_currentPage > totalPages) {
            _currentPage = 1;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load users list: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _getRoleBadgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'developer':
        return DeveloperTheme.accentCyan;
      case 'admin':
        return DeveloperTheme.accentRose;
      case 'chef':
        return DeveloperTheme.accentAmber;
      case 'pagsanjaninv':
      case 'inventory staff':
        return DeveloperTheme.accentPurple;
      case 'staff':
      case 'cashier':
      case 'waitstaff':
        return DeveloperTheme.accentIndigo;
      case 'customer':
      default:
        return DeveloperTheme.accentEmerald;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter users
    final filteredUsers = _users.where((user) {
      final role = (user['role'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final name = '${user['firstname'] ?? ''} ${user['lastname'] ?? ''} ${user['name'] ?? ''}'.toLowerCase();

      final matchesRole = _selectedRoleFilter == 'All Roles' || role == _selectedRoleFilter.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          email.contains(_searchQuery.toLowerCase()) ||
          name.contains(_searchQuery.toLowerCase());

      return matchesRole && matchesSearch;
    }).toList();

    // Counts by role
    final developerCount = _users.where((u) => (u['role'] ?? '').toString().toLowerCase() == 'developer').length;
    final adminCount = _users.where((u) => (u['role'] ?? '').toString().toLowerCase() == 'admin').length;
    final staffCount = _users.where((u) {
      final r = (u['role'] ?? '').toString().toLowerCase();
      return r == 'staff' || r == 'cashier' || r == 'waitstaff';
    }).length;
    final chefCount = _users.where((u) => (u['role'] ?? '').toString().toLowerCase() == 'chef').length;
    final customerCount = _users.where((u) => (u['role'] ?? '').toString().toLowerCase() == 'customer').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User & Role Monitoring', style: DeveloperTheme.headingLarge()),
                  const SizedBox(height: 4),
                  Text(
                    'Technical inspection of assigned permissions, active roles, and user registry',
                    style: DeveloperTheme.bodySmall(),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() => _currentPage = 1);
                        _loadUsers();
                      },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh Directory'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DeveloperTheme.accentIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Role Distribution Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return GridView.count(
                crossAxisCount: isWide ? 5 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.0 : 1.8,
                children: [
                  _buildRoleCard('Developers', developerCount, DeveloperTheme.accentCyan, Icons.code),
                  _buildRoleCard('Admins', adminCount, DeveloperTheme.accentRose, Icons.admin_panel_settings_rounded),
                  _buildRoleCard('Staff & POS', staffCount, DeveloperTheme.accentIndigo, Icons.badge_rounded),
                  _buildRoleCard('Chefs & Kitchen', chefCount, DeveloperTheme.accentAmber, Icons.restaurant_rounded),
                  _buildRoleCard('Customers', customerCount, DeveloperTheme.accentEmerald, Icons.people_alt_rounded),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: DeveloperTheme.cardDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() {
                      _searchQuery = val.trim();
                      _currentPage = 1;
                    }),
                    style: GoogleFonts.inter(fontSize: 13, color: DeveloperTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search user by email or name...',
                      hintStyle: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 18, color: DeveloperTheme.textMuted),
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: DeveloperTheme.bgDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: DeveloperTheme.borderSubtle),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: DeveloperTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DeveloperTheme.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRoleFilter,
                      dropdownColor: DeveloperTheme.bgCard,
                      icon: const Icon(Icons.arrow_drop_down, color: DeveloperTheme.textSecondary, size: 20),
                      style: DeveloperTheme.bodySmall(color: DeveloperTheme.textPrimary),
                      items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedRoleFilter = val;
                            _currentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Users List
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: DeveloperTheme.accentIndigo))
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: GoogleFonts.inter(color: DeveloperTheme.accentRose)))
                  : filteredUsers.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          decoration: DeveloperTheme.cardDecoration(),
                          alignment: Alignment.center,
                          child: Text('No users match the search criteria',
                              style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted)),
                        )
                      : Builder(
                            builder: (context) {
                              final totalItems = filteredUsers.length;
                              final totalPages = (totalItems / _pageSize).ceil().clamp(1, 99999);
                              final currentPage = _currentPage.clamp(1, totalPages);
                              final startIndex = totalItems == 0 ? 0 : (currentPage - 1) * _pageSize;
                              final endIndex = (startIndex + _pageSize > totalItems) ? totalItems : startIndex + _pageSize;
                              final paginatedUsers = totalItems == 0 ? <Map<String, dynamic>>[] : filteredUsers.sublist(startIndex, endIndex);

                              return Container(
                                decoration: DeveloperTheme.cardDecoration(),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: paginatedUsers.length,
                                        separatorBuilder: (_, __) => const Divider(
                                          height: 1,
                                          color: DeveloperTheme.borderSubtle,
                                        ),
                                        itemBuilder: (context, index) {
                                          final user = paginatedUsers[index];
                                          final role = (user['role'] ?? 'customer').toString();
                                          final roleColor = _getRoleBadgeColor(role);
                                          final email = user['email'] ?? 'No email';
                                          final name = '${user['firstname'] ?? ''} ${user['lastname'] ?? ''}'.trim();
                                          final displayName = name.isNotEmpty ? name : (user['name'] ?? email.split('@').first);
                                          final createdAt = user['created_at'] != null
                                              ? DateTime.tryParse(user['created_at'].toString())
                                              : null;

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: roleColor.withValues(alpha: 0.15),
                                                  child: Text(
                                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                                    style: GoogleFonts.inter(
                                                      fontWeight: FontWeight.bold,
                                                      color: roleColor,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        displayName,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                          color: DeveloperTheme.textPrimary,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        email,
                                                        style: DeveloperTheme.monoText(
                                                          fontSize: 11,
                                                          color: DeveloperTheme.textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Role Tag
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: roleColor.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text(
                                                    role.toUpperCase(),
                                                    style: DeveloperTheme.monoText(
                                                      fontSize: 11,
                                                      color: roleColor,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                // Registered Date
                                                if (createdAt != null)
                                                  Text(
                                                    'Joined ${DateFormat('yyyy-MM-dd').format(createdAt)}',
                                                    style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const Divider(height: 1, color: DeveloperTheme.borderSubtle),
                                    _buildPaginationFooter(
                                      totalItems: totalItems,
                                      startIndex: totalItems == 0 ? 0 : startIndex + 1,
                                      endIndex: endIndex,
                                      currentPage: currentPage,
                                      totalPages: totalPages,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DeveloperTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: DeveloperTheme.monoText(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: DeveloperTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter({
    required int totalItems,
    required int startIndex,
    required int endIndex,
    required int currentPage,
    required int totalPages,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: DeveloperTheme.bgDark,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 560;
          final infoText = Text(
            totalItems == 0
                ? '0 users'
                : 'Showing $startIndex–$endIndex of $totalItems users',
            style: DeveloperTheme.monoText(
              fontSize: 12,
              color: DeveloperTheme.textSecondary,
            ),
          );

          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 20),
                tooltip: 'First Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage > 1
                    ? () => setState(() => _currentPage = 1)
                    : null,
                color: DeveloperTheme.accentIndigo,
                disabledColor: DeveloperTheme.textMuted.withValues(alpha: 0.3),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage > 1
                    ? () => setState(() => _currentPage = currentPage - 1)
                    : null,
                color: DeveloperTheme.accentIndigo,
                disabledColor: DeveloperTheme.textMuted.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: DeveloperTheme.bgCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: DeveloperTheme.borderSubtle),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: DeveloperTheme.monoText(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: DeveloperTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage < totalPages
                    ? () => setState(() => _currentPage = currentPage + 1)
                    : null,
                color: DeveloperTheme.accentIndigo,
                disabledColor: DeveloperTheme.textMuted.withValues(alpha: 0.3),
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 20),
                tooltip: 'Last Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage < totalPages
                    ? () => setState(() => _currentPage = totalPages)
                    : null,
                color: DeveloperTheme.accentIndigo,
                disabledColor: DeveloperTheme.textMuted.withValues(alpha: 0.3),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                infoText,
                const SizedBox(height: 8),
                controls,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              infoText,
              controls,
            ],
          );
        },
      ),
    );
  }
}
