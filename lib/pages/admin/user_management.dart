import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/utils/responsive_utils.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDept = 'All';

  // Color constants
  static const _darkBg = Color(0xFF0F172A);
  static const _emerald = Color(0xFF14332E);
  static const _gold = Color(0xFFD9A441);
  static const _slate = Color(0xFF64748B);
  static const _slateLight = Color(0xFFE2E8F0);

  // Departments for filter
  static const _departments = [
    'All',
    'Management',
    'Kitchen',
    'Service',
    'Operations',
  ];

  // ORG CHART DATA — Structured staff directory
  final List<Map<String, dynamic>> _staff = [
    {
      'title': 'Restaurant Manager',
      'name': 'Tony Stark',
      'role': 'Supervisor',
      'dept': 'Management',
      'level': 0,
      'icon': Icons.account_balance_rounded,
      'colorHex': 0xFF14332E,
      'image': 'https://picsum.photos/seed/tony/200/200.jpg',
      'id': 'EMP001',
      'status': 'active',
      'phone': '+63 912 345 6789',
    },
    {
      'title': 'Operations Supervisor',
      'name': 'Steve Rogers',
      'role': 'Supervisor',
      'dept': 'Management',
      'level': 1,
      'icon': Icons.supervisor_account_rounded,
      'colorHex': 0xFF0284C7,
      'image': 'https://picsum.photos/seed/steve/200/200.jpg',
      'id': 'EMP002',
      'status': 'active',
      'phone': '+63 917 234 5678',
    },
    {
      'title': 'Head Chef',
      'name': 'Gordon Ramsay',
      'role': 'Cook',
      'dept': 'Kitchen',
      'level': 2,
      'icon': Icons.restaurant_rounded,
      'colorHex': 0xFFD97706,
      'image': 'https://picsum.photos/seed/gordon/200/200.jpg',
      'id': 'EMP003',
      'status': 'active',
      'phone': '+63 922 111 2222',
    },
    {
      'title': 'Sous Chef',
      'name': 'Jamie Oliver',
      'role': 'Cook',
      'dept': 'Kitchen',
      'level': 2,
      'icon': Icons.restaurant_rounded,
      'colorHex': 0xFFD97706,
      'image': 'https://picsum.photos/seed/jamie/200/200.jpg',
      'id': 'EMP004',
      'status': 'active',
      'phone': '+63 933 456 7890',
    },
    {
      'title': 'Kitchen Prep',
      'name': 'Edward Scissorhands',
      'role': 'Cutter',
      'dept': 'Kitchen',
      'level': 3,
      'icon': Icons.content_cut_rounded,
      'colorHex': 0xFF15803D,
      'image': 'https://picsum.photos/seed/edward/200/200.jpg',
      'id': 'EMP005',
      'status': 'active',
      'phone': '+63 945 678 9012',
    },
    {
      'title': 'Kitchen Prep',
      'name': 'Wolverine',
      'role': 'Cutter',
      'dept': 'Kitchen',
      'level': 3,
      'icon': Icons.content_cut_rounded,
      'colorHex': 0xFF15803D,
      'image': 'https://picsum.photos/seed/wolverine/200/200.jpg',
      'id': 'EMP006',
      'status': 'on-leave',
      'phone': '+63 956 789 0123',
    },
    {
      'title': 'Cashier',
      'name': 'Spongebob Squarepants',
      'role': 'Cashier & Food Server',
      'dept': 'Operations',
      'level': 2,
      'icon': Icons.point_of_sale_rounded,
      'colorHex': 0xFF7C3AED,
      'image': 'https://picsum.photos/seed/spongebob/200/200.jpg',
      'id': 'EMP007',
      'status': 'active',
      'phone': '+63 961 890 1234',
    },
    {
      'title': 'Food Server',
      'name': 'Squidward Tentacles',
      'role': 'Cashier & Food Server',
      'dept': 'Service',
      'level': 2,
      'icon': Icons.room_service_rounded,
      'colorHex': 0xFF0891B2,
      'image': 'https://picsum.photos/seed/squidward/200/200.jpg',
      'id': 'EMP008',
      'status': 'active',
      'phone': '+63 972 901 2345',
    },
    {
      'title': 'Waitstaff',
      'name': 'Sanji',
      'role': 'Dine-in Food Server',
      'dept': 'Service',
      'level': 2,
      'icon': Icons.room_service_rounded,
      'colorHex': 0xFF0891B2,
      'image': 'https://picsum.photos/seed/sanji/200/200.jpg',
      'id': 'EMP009',
      'status': 'active',
      'phone': '+63 983 012 3456',
    },
    {
      'title': 'Waitstaff',
      'name': 'Peter Parker',
      'role': 'Dine-in Food Server',
      'dept': 'Service',
      'level': 2,
      'icon': Icons.room_service_rounded,
      'colorHex': 0xFF0891B2,
      'image': 'https://picsum.photos/seed/peter/200/200.jpg',
      'id': 'EMP010',
      'status': 'inactive',
      'phone': '+63 994 123 4567',
    },
    {
      'title': 'Waitstaff',
      'name': 'Clark Kent',
      'role': 'Dine-in Food Server',
      'dept': 'Service',
      'level': 2,
      'icon': Icons.room_service_rounded,
      'colorHex': 0xFF0891B2,
      'image': 'https://picsum.photos/seed/clark/200/200.jpg',
      'id': 'EMP011',
      'status': 'active',
      'phone': '+63 905 234 5678',
    },
    {
      'title': 'Kitchen Utility',
      'name': 'John Doe',
      'role': 'Dishwasher',
      'dept': 'Kitchen',
      'level': 3,
      'icon': Icons.cleaning_services_rounded,
      'colorHex': 0xFF64748B,
      'image': 'https://picsum.photos/seed/john/200/200.jpg',
      'id': 'EMP012',
      'status': 'active',
      'phone': '+63 916 345 6789',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredStaff {
    return _staff.where((s) {
      final name = s['name'].toString().toLowerCase();
      final role = s['role'].toString().toLowerCase();
      final title = s['title'].toString().toLowerCase();
      final dept = s['dept'].toString();
      final q = _searchQuery.toLowerCase();

      final matchesSearch =
          q.isEmpty || name.contains(q) || role.contains(q) || title.contains(q);
      final matchesDept =
          _selectedDept == 'All' || dept == _selectedDept;
      return matchesSearch && matchesDept;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final filtered = _filteredStaff;

    // Count stats
    final activeCount = _staff.where((s) => s['status'] == 'active').length;
    final onLeaveCount = _staff.where((s) => s['status'] == 'on-leave').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 24,
          vertical: isMobile ? 14 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- HEADER ----
            _buildHeader(isMobile),
            const SizedBox(height: 16),

            // ---- ANALYTICS TILES ----
            _buildStatsRow(isMobile, activeCount, onLeaveCount),
            const SizedBox(height: 16),

            // ---- SEARCH + DEPT FILTER ----
            _buildSearchAndFilter(isMobile),
            const SizedBox(height: 20),

            // ---- STAFF SECTION HEADER ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Directory',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.w800,
                        color: _darkBg,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      '${filtered.length} member${filtered.length == 1 ? '' : 's'} found',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _slate,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ---- STAFF CARDS ----
            if (filtered.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _buildStaffCard(filtered[index], isMobile),
              ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // HEADER
  // -------------------------------------------------------------------------
  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _emerald.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.badge_rounded, color: _gold, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Staff Management',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 17 : 20,
                          fontWeight: FontWeight.w800,
                          color: _darkBg,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: _gold.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Org Chart',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9E6D10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Browse the full hierarchy of restaurant personnel',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _slate,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // STATS ROW
  // -------------------------------------------------------------------------
  Widget _buildStatsRow(bool isMobile, int active, int onLeave) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            label: 'Total Staff',
            value: _staff.length.toString(),
            icon: Icons.groups_rounded,
            bgTint: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF15803D),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            label: 'Active',
            value: active.toString(),
            icon: Icons.verified_rounded,
            bgTint: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            label: 'On Leave',
            value: onLeave.toString(),
            icon: Icons.event_busy_rounded,
            bgTint: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
    required Color bgTint,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _darkBg,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: _slate,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SEARCH + DEPT FILTER
  // -------------------------------------------------------------------------
  Widget _buildSearchAndFilter(bool isMobile) {
    return Column(
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _slateLight),
            boxShadow: [
              BoxShadow(
                color: _darkBg.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: _darkBg,
            ),
            decoration: InputDecoration(
              hintText: 'Search staff by name, title, or role...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: _slate, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Department filter pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _departments.map((dept) {
              final isSelected = _selectedDept == dept;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedDept = dept),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? _emerald : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? _emerald : _slateLight,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _emerald.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      dept,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // STAFF CARD
  // -------------------------------------------------------------------------
  Widget _buildStaffCard(Map<String, dynamic> staff, bool isMobile) {
    final accentColor = Color(staff['colorHex'] as int);
    final status = staff['status'] as String;
    final levelLabel = _getLevelLabel(staff['level'] as int);

    Color statusColor;
    IconData statusIcon;
    String statusText;
    switch (status) {
      case 'on-leave':
        statusColor = const Color(0xFFD97706);
        statusIcon = Icons.event_busy_rounded;
        statusText = 'On Leave';
        break;
      case 'inactive':
        statusColor = const Color(0xFFDC2626);
        statusIcon = Icons.cancel_rounded;
        statusText = 'Inactive';
        break;
      case 'active':
      default:
        statusColor = const Color(0xFF15803D);
        statusIcon = Icons.circle;
        statusText = 'Active';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight),
        boxShadow: [
          BoxShadow(
            color: _darkBg.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent bar  with level indicator
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),

            Expanded(
              child: InkWell(
                onTap: () => _showStaffModal(staff),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 18,
                    vertical: isMobile ? 14 : 16,
                  ),
                  child: Row(
                    children: [
                      // Avatar with network image + fallback
                      Container(
                        width: isMobile ? 48 : 56,
                        height: isMobile ? 48 : 56,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            staff['image'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Center(
                              child: Icon(
                                staff['icon'] as IconData,
                                color: accentColor,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Main Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    staff['name'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: isMobile ? 14 : 15,
                                      fontWeight: FontWeight.w800,
                                      color: _darkBg,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Level badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    levelLabel,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              staff['title'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: _slate,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _miniChip(
                                  staff['role'] as String,
                                  accentColor.withValues(alpha: 0.1),
                                  accentColor,
                                ),
                                _miniChip(
                                  staff['dept'] as String,
                                  const Color(0xFFF1F5F9),
                                  _slate,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Right — ID + Status
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              staff['id'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _slate,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                  color:
                                      statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon,
                                    size: 8, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Icon(Icons.chevron_right_rounded,
                              size: 16, color: Color(0xFFCBD5E1)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  String _getLevelLabel(int level) {
    switch (level) {
      case 0:
        return 'L1 · EXEC';
      case 1:
        return 'L2 · SR. MGR';
      case 2:
        return 'L3 · STAFF';
      case 3:
        return 'L4 · SUPPORT';
      default:
        return 'L${level + 1}';
    }
  }

  // -------------------------------------------------------------------------
  // EMPTY STATE
  // -------------------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 52, color: _gold),
            ),
            const SizedBox(height: 16),
            Text(
              'No Staff Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _darkBg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search or department filter.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: _slate,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // STAFF DETAIL MODAL
  // -------------------------------------------------------------------------
  void _showStaffModal(Map<String, dynamic> staff) {
    final accentColor = Color(staff['colorHex'] as int);
    final status = staff['status'] as String;

    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (status) {
      case 'on-leave':
        statusColor = const Color(0xFFD97706);
        statusText = 'On Leave';
        statusIcon = Icons.event_busy_rounded;
        break;
      case 'inactive':
        statusColor = const Color(0xFFDC2626);
        statusText = 'Inactive';
        statusIcon = Icons.block_rounded;
        break;
      case 'active':
      default:
        statusColor = const Color(0xFF15803D);
        statusText = 'Active';
        statusIcon = Icons.verified_rounded;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EMPLOYEE PROFILE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 1.2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white60, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          staff['image'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Center(
                            child: Icon(staff['icon'] as IconData,
                                size: 34, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      staff['name'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      staff['title'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            staff['role'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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

              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2-column stat tiles
                    Row(
                      children: [
                        Expanded(
                          child: _modalStatBox(
                            label: 'Employee ID',
                            value: staff['id'] as String,
                            icon: Icons.badge_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _modalStatBox(
                            label: 'Department',
                            value: staff['dept'] as String,
                            icon: Icons.business_center_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _modalDetailRow(Icons.phone_rounded, 'Mobile',
                        staff['phone'] as String),
                    _modalDetailRow(Icons.work_rounded, 'Role',
                        staff['role'] as String),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalStatBox({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _slateLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _slate),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _darkBg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modalDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: _slate),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _darkBg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
