import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yang_chow/services/staff_service.dart';
import 'package:yang_chow/services/audit_log_service.dart';
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

  // Departments for filter — mutable so custom depts added in modal appear here too
  List<String> _departments = [
    'All',
    'Management',
    'Kitchen',
    'Service',
    'Operations',
  ];

  // Persisted custom roles list
  List<String> _customRoles = [];

  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaffData();
    _loadCustomLists();
  }

  Future<void> _loadStaffData() async {
    try {
      final list = await StaffService.loadStaffList();
      setState(() {
        _staff = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _staff = List<Map<String, dynamic>>.from(StaffService.defaultStaff);
        _isLoading = false;
      });
    }
  }

  /// Load persisted custom departments & roles, merge into filter lists
  Future<void> _loadCustomLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final depts = prefs.getStringList('yang_custom_departments') ?? [];
      final roles = prefs.getStringList('yang_custom_roles') ?? [];
      if (depts.isNotEmpty || roles.isNotEmpty) {
        setState(() {
          for (final d in depts) {
            if (!_departments.contains(d)) _departments.add(d);
          }
          _customRoles = roles;
        });
      }
    } catch (e) {
      debugPrint('Error loading custom lists: $e');
    }
  }

  /// Persist custom departments (everything after the 5 base ones)
  Future<void> _saveCustomDepartments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base = {'All', 'Management', 'Kitchen', 'Service', 'Operations'};
      final custom = _departments.where((d) => !base.contains(d)).toList();
      await prefs.setStringList('yang_custom_departments', custom);
    } catch (e) {
      debugPrint('Error saving custom departments: $e');
    }
  }

  /// Persist custom roles
  Future<void> _saveCustomRoles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('yang_custom_roles', _customRoles);
    } catch (e) {
      debugPrint('Error saving custom roles: $e');
    }
  }

  Future<void> _saveStaffData() async {
    try {
      await StaffService.saveStaffList(_staff);
    } catch (e) {
      debugPrint('Error saving staff to prefs: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredStaff {
    return _staff.where((s) {
      // Exclude archived staff from active directory
      if ((s['status'] ?? 'active').toString().toLowerCase() == 'archived') {
        return false;
      }
      final name = (s['name'] ?? s['full_name'] ?? '').toString().toLowerCase();
      final role = (s['role'] ?? '').toString().toLowerCase();
      final title = (s['title'] ?? '').toString().toLowerCase();
      final dept = (s['dept'] ?? '').toString();
      final id = (s['id'] ?? s['employee_id'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesSearch = q.isEmpty ||
          name.contains(q) ||
          role.contains(q) ||
          title.contains(q) ||
          id.contains(q);
      final matchesDept = _selectedDept == 'All' || dept == _selectedDept;
      return matchesSearch && matchesDept;
    }).toList();
  }

  List<Map<String, dynamic>> get _archivedStaff {
    return _staff.where((s) => (s['status'] ?? '').toString().toLowerCase() == 'archived').toList();
  }

  int get _nextEmpNumber {
    // Count only active (non-archived) staff
    final activeCount = _staff.where(
      (s) => (s['status'] ?? 'active').toString().toLowerCase() != 'archived',
    ).length;
    // Next number = active staff count + 1
    return activeCount + 1;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final filtered = _filteredStaff;

    // Count stats
    final activeCount = _staff.where((s) => s['status'] == 'active').length;
    final onLeaveCount = _staff.where((s) => s['status'] == 'on-leave').length;
    final inactiveCount = _staff.where((s) => s['status'] == 'inactive').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _emerald))
          : SingleChildScrollView(
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
                  _buildStatsRow(isMobile, activeCount, onLeaveCount, inactiveCount),
                  const SizedBox(height: 16),

                  // ---- SEARCH + DEPT FILTER ----
                  _buildSearchAndFilter(isMobile),
                  const SizedBox(height: 20),

                  // ---- STAFF SECTION HEADER WITH ADD BUTTON ----
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
                      // Action Buttons
                      Row(
                        children: [
                          // 📦 Archived Staff Button
                          OutlinedButton.icon(
                            onPressed: _showArchivedStaffModal,
                            icon: const Icon(Icons.archive_outlined, size: 15, color: Color(0xFFD97706)),
                            label: Text(
                              isMobile ? '(${_archivedStaff.length})' : 'Archived (${_archivedStaff.length})',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: const Color(0xFFD97706).withValues(alpha: 0.5)),
                              backgroundColor: const Color(0xFFFFFBEB),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 10 : 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // ➕ Add Staff Action Button
                          ElevatedButton.icon(
                            onPressed: () => _showAddEditStaffModal(null),
                            icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                            label: Text(
                              isMobile ? 'Add' : 'Add New Staff',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _emerald,
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              shadowColor: _emerald.withValues(alpha: 0.3),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _gold.withValues(alpha: 0.3)),
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
                  'Manage, add, edit, and organize restaurant staff personnel with real photos',
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
  // STATS ROW (Responsive Carousel on Mobile)
  // -------------------------------------------------------------------------
  Widget _buildStatsRow(bool isMobile, int active, int onLeave, int inactive) {
    if (isMobile) {
      return SizedBox(
        height: 72,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            Container(
              width: 155,
              margin: const EdgeInsets.only(right: 8),
              child: _statTile(
                label: 'Total Staff',
                value: _staff.length.toString(),
                icon: Icons.groups_rounded,
                bgTint: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF15803D),
              ),
            ),
            Container(
              width: 155,
              margin: const EdgeInsets.only(right: 8),
              child: _statTile(
                label: 'Active Personnel',
                value: active.toString(),
                icon: Icons.verified_rounded,
                bgTint: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
              ),
            ),
            Container(
              width: 155,
              margin: const EdgeInsets.only(right: 8),
              child: _statTile(
                label: 'On Leave',
                value: onLeave.toString(),
                icon: Icons.event_busy_rounded,
                bgTint: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
              ),
            ),
            Container(
              width: 155,
              margin: const EdgeInsets.only(right: 8),
              child: _statTile(
                label: 'Inactive',
                value: inactive.toString(),
                icon: Icons.person_off_rounded,
                bgTint: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      );
    }

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _darkBg,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
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
  // SEARCH & FILTER
  // -------------------------------------------------------------------------
  Widget _buildSearchAndFilter(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search staff by name, title, role, or ID...',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF94A3B8),
                fontSize: 13,
              ),
              prefixIcon: const Icon(Icons.search_rounded, color: _slate, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: _slate),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),

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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
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
  // PHOTO RENDERER HELPER (Supports Base64 Data, Network URLs & Initials)
  // -------------------------------------------------------------------------
  Widget _buildStaffAvatar(String? image, String name, Color accentColor, {double size = 48}) {
    if (image != null && image.isNotEmpty) {
      if (image.startsWith('data:image') || (image.length > 200 && !image.startsWith('http'))) {
        try {
          String cleanBase64 = image;
          if (image.contains(',')) {
            cleanBase64 = image.split(',').last;
          }
          final bytes = base64Decode(cleanBase64);
          return ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.26),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => _buildInitialsAvatar(name, accentColor, size),
            ),
          );
        } catch (e) {
          debugPrint('Base64 decode error: $e');
        }
      } else if (image.startsWith('http://') || image.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.26),
          child: Image.network(
            image,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _buildInitialsAvatar(name, accentColor, size),
          ),
        );
      }
    }
    return _buildInitialsAvatar(name, accentColor, size);
  }

  Widget _buildInitialsAvatar(String name, Color accentColor, double size) {
    final parts = name.trim().split(' ');
    String initials = 'ST';
    if (parts.length >= 2) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor, accentColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.plusJakartaSans(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // STAFF CARD WITH DIRECT QUICK ACTIONS
  // -------------------------------------------------------------------------
  Widget _buildStaffCard(Map<String, dynamic> staff, bool isMobile) {
    final accentColor = Color(staff['colorHex'] as int? ?? 0xFF14332E);
    final status = (staff['status'] ?? 'active').toString();
    final levelLabel = _getLevelLabel(staff['level'] as int? ?? 2);
    // Support both 'full_name' and legacy 'name' key
    final name = (staff['full_name'] ?? staff['name']) as String? ?? 'Unnamed Staff';
    final photo = staff['image'] as String?;

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
            // Left accent bar
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
                    horizontal: isMobile ? 12 : 18,
                    vertical: isMobile ? 12 : 16,
                  ),
                  child: Row(
                    children: [
                      // Avatar Photo with real preview
                      Container(
                        width: isMobile ? 46 : 54,
                        height: isMobile ? 46 : 54,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: _buildStaffAvatar(photo, name, accentColor, size: isMobile ? 46 : 54),
                      ),
                      const SizedBox(width: 12),

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
                                    name,
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                              staff['title'] as String? ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: _slate,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _tagPill(staff['role'] as String? ?? '', const Color(0xFF0284C7)),
                                _tagPill(staff['dept'] as String? ?? '', const Color(0xFF64748B)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Right Side: Status Badge + Action Menu
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            staff['id'] as String? ?? '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 8, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),

                      // 3-Dot Quick Action Menu (View Info / Edit / Change Status / Archive)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: _slate),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) {
                          if (val == 'details') {
                            _showStaffDetailsDialog(staff);
                          } else if (val == 'edit') {
                            _showAddEditStaffModal(staff);
                          } else if (val == 'change_status') {
                            _showChangeStatusDialog(staff);
                          } else if (val == 'archive') {
                            _showArchiveDialog(staff);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'details',
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0F172A)),
                                const SizedBox(width: 8),
                                Text('View Information', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF0284C7)),
                                const SizedBox(width: 8),
                                Text('Edit Details & Photo', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'change_status',
                            child: Row(
                              children: [
                                const Icon(Icons.sync_alt_rounded, size: 16, color: Color(0xFFD97706)),
                                const SizedBox(width: 8),
                                Text('Change Status', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                const Icon(Icons.archive_outlined, size: 16, color: Color(0xFFD97706)),
                                const SizedBox(width: 8),
                                Text('Archive Staff', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFD97706))),
                              ],
                            ),
                          ),
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

  Widget _tagPill(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// Returns hierarchy label. Higher level number = higher rank.
  /// L4 = Executive (top), L3 = Senior Manager, L2 = Staff, L1 = Support (bottom)
  String _getLevelLabel(int level) {
    switch (level) {
      case 4:
        return 'L4 · EXEC';
      case 3:
        return 'L3 · SR. MGR';
      case 2:
        return 'L2 · STAFF';
      case 1:
        return 'L1 · SUPPORT';
      default:
        return 'L$level';
    }
  }

  /// Auto-detect the recommended hierarchy level from a role string.
  int _detectLevelFromRole(String role) {
    final r = role.toLowerCase();
    if (r.contains('manager') || r.contains('owner') || r.contains('exec') || r.contains('director') || r.contains('ceo') || r.contains('admin')) {
      return 4;
    } else if (r.contains('supervisor') || r.contains('head') || r.contains('senior') || r.contains('lead') || r.contains('chief')) {
      return 3;
    } else if (r.contains('cook') || r.contains('cashier') || r.contains('server') || r.contains('dine') || r.contains('cutter')) {
      return 2;
    } else if (r.contains('dishwasher') || r.contains('cleaner') || r.contains('support') || r.contains('helper') || r.contains('busboy')) {
      return 1;
    }
    return 2; // default to Staff
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
              child: const Icon(Icons.search_off_rounded, size: 52, color: _gold),
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
              'Try adjusting your search or add a new staff member.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: _slate,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddEditStaffModal(null),
              icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
              label: Text(
                'Add Staff Member',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CHANGE STATUS SELECTION DIALOG (Active, On Leave, Inactive)
  // -------------------------------------------------------------------------
  void _showChangeStatusDialog(Map<String, dynamic> staff) {
    String current = (staff['status'] ?? 'active').toString().toLowerCase();
    if (current == 'archived') current = 'active';
    String selected = current;

    // Check if staff can be placed on leave (hired >= 3 days ago)
    final dateHiredStr = staff['date_hired'] as String?;
    final canOnLeave = dateHiredStr != null &&
        DateTime.now().difference(DateTime.tryParse(dateHiredStr) ?? DateTime.now()).inDays >= 3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sync_alt_rounded, color: _emerald, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Change Status',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select employment status for "${staff['name']}" (${staff['id']}):',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 14),

              // Active Option
              _statusDialogOption(
                statusKey: 'active',
                title: 'Active',
                subtitle: 'Currently on duty and available',
                icon: Icons.verified_rounded,
                color: const Color(0xFF15803D),
                isSelected: selected == 'active',
                onTap: () => setDialogState(() => selected = 'active'),
              ),
              const SizedBox(height: 8),

              // On Leave Option
              _statusDialogOption(
                statusKey: 'on-leave',
                title: canOnLeave ? 'On Leave' : 'On Leave (Locked)',
                subtitle: canOnLeave
                    ? 'Temporarily on approved leave'
                    : 'Requires at least 3 days of employment',
                icon: Icons.event_busy_rounded,
                color: const Color(0xFFD97706),
                isSelected: selected == 'on-leave',
                isDisabled: !canOnLeave,
                onTap: canOnLeave ? () => setDialogState(() => selected = 'on-leave') : null,
              ),
              const SizedBox(height: 8),

              // Inactive Option
              _statusDialogOption(
                statusKey: 'inactive',
                title: 'Inactive',
                subtitle: 'Off-shift, suspended, or inactive',
                icon: Icons.cancel_rounded,
                color: const Color(0xFFDC2626),
                isSelected: selected == 'inactive',
                onTap: () => setDialogState(() => selected = 'inactive'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _slate)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  staff['status'] = selected;
                });
                _saveStaffData();

                AuditLogService.logActivity(
                  action: 'STATUS_CHANGE',
                  module: 'Users',
                  description: 'Changed status for "${staff['name']}" (${staff['id']}) to ${selected.toUpperCase()}',
                  entityId: staff['id']?.toString(),
                  metadata: {
                    'staff_name': staff['name'],
                    'staff_id': staff['id'],
                    'new_status': selected,
                  },
                );

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Updated ${staff['name']}\'s status to: ${selected.toUpperCase()}'),
                    backgroundColor: _emerald,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Update Status', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusDialogOption({
    required String statusKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    bool isDisabled = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : (isDisabled ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDisabled ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isDisabled ? _slate : color).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: isDisabled ? _slate : color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDisabled ? _slate : (isSelected ? color : _darkBg),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 18)
            else if (isDisabled)
              const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 16),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ADD / EDIT STAFF MODAL (With Real Photo Picker)
  // -------------------------------------------------------------------------
  void _showAddEditStaffModal(Map<String, dynamic>? staff) {
    final isEditing = staff != null;
    // Support both 'full_name' and legacy 'name' key
    final existingName = (staff?['full_name'] ?? staff?['name'] ?? '') as String;
    final nameController = TextEditingController(text: existingName);
    final titleController = TextEditingController(text: isEditing ? (staff['title'] ?? '') : '');
    String initialPhone = '';
    if (isEditing && staff['phone'] != null) {
      final digits = staff['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.startsWith('63') && digits.length == 12) {
        initialPhone = '0${digits.substring(2)}';
      } else if (digits.length == 11) {
        initialPhone = digits;
      } else if (digits.length == 10 && digits.startsWith('9')) {
        initialPhone = '0$digits';
      } else {
        initialPhone = digits;
      }
    }
    final phoneController = TextEditingController(text: initialPhone);
    final idController = TextEditingController(
      text: isEditing ? (staff['id'] ?? '') : 'EMP${_nextEmpNumber.toString().padLeft(3, '0')}',
    );

    String selectedDept = isEditing ? (staff['dept'] ?? 'Kitchen') : 'Kitchen';
    String selectedRole = isEditing ? (staff['role'] ?? 'Cook') : 'Cook';
    int selectedLevel = isEditing ? (staff['level'] ?? 2) : 2;
    String selectedStatus = isEditing ? (staff['status'] ?? 'active') : 'active';
    String? currentPhoto = isEditing ? (staff['image'] as String?) : null;

    // Compute whether On Leave is available (staff must be hired >= 3 days ago)
    final String? dateHiredStr = isEditing ? staff['date_hired'] as String? : null;
    final bool canShowOnLeave = isEditing && dateHiredStr != null &&
        DateTime.now().difference(DateTime.tryParse(dateHiredStr) ?? DateTime.now()).inDays >= 3;

    // Mutable lists (so user can add custom entries)
    final List<String> deptOptions = List<String>.from(_departments.where((d) => d != 'All'));
    final List<String> roleOptions = [
      'Supervisor',
      'Cook',
      'Cutter',
      'Cashier & Food Server',
      'Dine-in Food Server',
      'Dishwasher',
      'Kitchen Prep',
      'Kitchen Utility',
      'Restaurant Manager',
      'Admin',
      'Manager',
      ..._customRoles,
    ];

    // Ensure existing custom role/dept are in the lists
    if (isEditing && !roleOptions.contains(selectedRole)) roleOptions.add(selectedRole);
    if (isEditing && !deptOptions.contains(selectedDept)) deptOptions.add(selectedDept);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickPhoto(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final XFile? file = await picker.pickImage(
                source: source,
                maxWidth: 320,
                maxHeight: 320,
                imageQuality: 70,
              );
              if (file != null) {
                final bytes = await file.readAsBytes();
                final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                setDialogState(() {
                  currentPhoto = base64String;
                });
              }
            } catch (e) {
              debugPrint('Error picking staff image: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Camera/Gallery error: $e'),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            }
          }

          void showImageSourceSelector() {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (bCtx) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      'Select Staff Photo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _darkBg,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: _emerald),
                      ),
                      title: Text(
                        'Take Photo (Camera)',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Use device camera to snap staff portrait',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
                      ),
                      onTap: () {
                        Navigator.pop(bCtx);
                        pickPhoto(ImageSource.camera);
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0284C7)),
                      ),
                      title: Text(
                        'Choose from Gallery / Files',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Select an existing image from your device',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate),
                      ),
                      onTap: () {
                        Navigator.pop(bCtx);
                        pickPhoto(ImageSource.gallery);
                      },
                    ),
                    if (currentPhoto != null && currentPhoto!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                        ),
                        title: Text(
                          'Remove Photo',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(bCtx);
                          setDialogState(() => currentPhoto = null);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Modal Title Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_emerald, Color(0xFF1E4A42)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                              color: _gold,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'Edit Staff Member' : 'Add New Staff Member',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Form Fields
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 📸 PHOTO UPLOADER SECTION (Camera + Gallery)
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: showImageSourceSelector,
                                      child: Container(
                                        width: 84,
                                        height: 84,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(color: _emerald.withValues(alpha: 0.3), width: 2),
                                        ),
                                        child: _buildStaffAvatar(
                                          currentPhoto,
                                          nameController.text.isEmpty ? 'New Staff' : nameController.text,
                                          _emerald,
                                          size: 84,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: GestureDetector(
                                        onTap: showImageSourceSelector,
                                        child: Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: _gold,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(Icons.camera_alt_rounded, size: 15, color: _emerald),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: showImageSourceSelector,
                                      icon: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                      label: Text(
                                        'Take / Choose Photo',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _emerald,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        elevation: 0,
                                      ),
                                    ),
                                    if (currentPhoto != null && currentPhoto!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () => setDialogState(() => currentPhoto = null),
                                        child: Text(
                                          'Remove',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Name
                          _inputLabel('Name *'),
                          TextField(
                            controller: nameController,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: _inputDecoration('e.g. Maria Santos', Icons.person_outline_rounded),
                          ),
                          const SizedBox(height: 12),

                          // Job Title & Employee ID
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _inputLabel('Job Title *'),
                                    TextField(
                                      controller: titleController,
                                      decoration: _inputDecoration('e.g. Line Cook', Icons.work_outline_rounded),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _inputLabel(isEditing ? 'Employee ID (Locked)' : 'Employee ID (Auto: Staff #$_nextEmpNumber)'),
                                    TextField(
                                      controller: idController,
                                      readOnly: true,
                                      enabled: false,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF64748B),
                                      ),
                                      decoration: _inputDecoration('EMP001', Icons.badge_outlined).copyWith(
                                        fillColor: const Color(0xFFF1F5F9),
                                        suffixIcon: const Icon(Icons.lock_outline_rounded, size: 15, color: _slate),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Department & Role
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _inputLabel('Department *'),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _slateLight),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: deptOptions.contains(selectedDept) ? selectedDept : deptOptions.first,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                          items: [
                                            ...deptOptions.map((d) => DropdownMenuItem(
                                              value: d,
                                              child: Text(d, style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                                            )),
                                            DropdownMenuItem(
                                              value: '__add_dept__',
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.add_circle_outline_rounded, size: 14, color: _emerald),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Add Another Department',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: _emerald,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) async {
                                            if (val == '__add_dept__') {
                                              final ctrl = TextEditingController();
                                              final newDept = await showDialog<String>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  title: Text('Add Department', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
                                                  content: TextField(
                                                    controller: ctrl,
                                                    autofocus: true,
                                                    decoration: _inputDecoration('e.g. Delivery, Bar, Maintenance', Icons.business_rounded),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx),
                                                      child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _slate)),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                                                      style: ElevatedButton.styleFrom(backgroundColor: _emerald, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                                      child: Text('Add', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (newDept != null && newDept.isNotEmpty) {
                                                setDialogState(() {
                                                  if (!deptOptions.contains(newDept)) deptOptions.add(newDept);
                                                  selectedDept = newDept;
                                                });
                                                // Also add to the filter tab pills
                                                setState(() {
                                                  if (!_departments.contains(newDept)) _departments.add(newDept);
                                                });
                                                _saveCustomDepartments();
                                              }
                                            } else if (val != null) {
                                              setDialogState(() => selectedDept = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _inputLabel('Role / Access *'),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _slateLight),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: roleOptions.contains(selectedRole) ? selectedRole : roleOptions.first,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                          items: [
                                            ...roleOptions.map((r) => DropdownMenuItem(
                                              value: r,
                                              child: Text(r, style: GoogleFonts.plusJakartaSans(fontSize: 12), overflow: TextOverflow.ellipsis),
                                            )),
                                            DropdownMenuItem(
                                              value: '__add_role__',
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.add_circle_outline_rounded, size: 14, color: _emerald),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Add Another Role',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: _emerald,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) async {
                                            if (val == '__add_role__') {
                                              final ctrl = TextEditingController();
                                              final newRole = await showDialog<String>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  title: Text('Add Role', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
                                                  content: TextField(
                                                    controller: ctrl,
                                                    autofocus: true,
                                                    decoration: _inputDecoration('e.g. Bartender, Delivery Rider', Icons.work_outline_rounded),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx),
                                                      child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _slate)),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                                                      style: ElevatedButton.styleFrom(backgroundColor: _emerald, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                                      child: Text('Add', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (newRole != null && newRole.isNotEmpty) {
                                                setDialogState(() {
                                                  if (!roleOptions.contains(newRole)) roleOptions.add(newRole);
                                                  selectedRole = newRole;
                                                  // Auto-detect level from new role
                                                  selectedLevel = _detectLevelFromRole(newRole);
                                                });
                                                // Persist the custom role
                                                if (!_customRoles.contains(newRole)) {
                                                  setState(() => _customRoles.add(newRole));
                                                  _saveCustomRoles();
                                                }
                                              }
                                            } else if (val != null) {
                                              setDialogState(() {
                                                selectedRole = val;
                                                // Auto-detect level from selected role
                                                selectedLevel = _detectLevelFromRole(val);
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    // Auto-detect hint
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.auto_awesome_rounded, size: 10, color: _slate),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Level auto-detected from role',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _slate, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Mobile Phone (Strict 11 digits, numbers only)
                          _inputLabel('Contact Number (Exact 11 Digits) *'),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            decoration: _inputDecoration('e.g. 09123456789', Icons.phone_outlined),
                          ),
                          const SizedBox(height: 14),

                          // Hierarchy Level (L4=Exec top, L1=Support bottom)
                          _inputLabel('Staff Hierarchy Level'),
                          Row(
                            children: [
                              _levelChip(1, 'L1\nSupport', selectedLevel == 1, () => setDialogState(() => selectedLevel = 1)),
                              const SizedBox(width: 6),
                              _levelChip(2, 'L2\nStaff', selectedLevel == 2, () => setDialogState(() => selectedLevel = 2)),
                              const SizedBox(width: 6),
                              _levelChip(3, 'L3\nSr. Mgr', selectedLevel == 3, () => setDialogState(() => selectedLevel = 3)),
                              const SizedBox(width: 6),
                              _levelChip(4, 'L4\nExec', selectedLevel == 4, () => setDialogState(() => selectedLevel = 4)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Status Selector
                          _inputLabel('Employment Status'),
                          if (!isEditing)
                            // NEW STAFF: Active + Inactive only (On Leave needs 3 days first)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _statusChip('active', 'Active', Icons.verified_rounded, const Color(0xFF15803D), selectedStatus == 'active', () => setDialogState(() => selectedStatus = 'active')),
                                    const SizedBox(width: 8),
                                    _statusChip('inactive', 'Inactive', Icons.cancel_rounded, const Color(0xFFDC2626), selectedStatus == 'inactive', () => setDialogState(() => selectedStatus = 'inactive')),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.lock_clock_rounded, size: 13, color: Color(0xFFD97706)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'On Leave unlocks after 3 days of employment.',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            color: const Color(0xFFD97706),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            // EDITING: show based on date_hired eligibility
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _statusChip('active', 'Active', Icons.verified_rounded, const Color(0xFF15803D), selectedStatus == 'active', () => setDialogState(() => selectedStatus = 'active')),
                                    const SizedBox(width: 8),
                                    // On Leave: only tappable if >= 3 days hired
                                    Expanded(
                                      child: Tooltip(
                                        message: canShowOnLeave ? '' : 'Available after 3 days of employment',
                                        child: InkWell(
                                          onTap: canShowOnLeave
                                              ? () => setDialogState(() => selectedStatus = 'on-leave')
                                              : null,
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: selectedStatus == 'on-leave'
                                                  ? const Color(0xFFD97706).withValues(alpha: 0.15)
                                                  : canShowOnLeave
                                                      ? const Color(0xFFF8FAFC)
                                                      : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: selectedStatus == 'on-leave'
                                                    ? const Color(0xFFD97706)
                                                    : canShowOnLeave ? _slateLight : const Color(0xFFCBD5E1),
                                                width: selectedStatus == 'on-leave' ? 1.5 : 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.event_busy_rounded,
                                                  size: 12,
                                                  color: !canShowOnLeave
                                                      ? const Color(0xFFCBD5E1)
                                                      : selectedStatus == 'on-leave'
                                                          ? const Color(0xFFD97706)
                                                          : _slate,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'On Leave',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    fontWeight: selectedStatus == 'on-leave' ? FontWeight.w800 : FontWeight.w600,
                                                    color: !canShowOnLeave
                                                        ? const Color(0xFFCBD5E1)
                                                        : selectedStatus == 'on-leave'
                                                            ? const Color(0xFFD97706)
                                                            : const Color(0xFF64748B),
                                                  ),
                                                ),
                                                if (!canShowOnLeave) ...[
                                                  const SizedBox(width: 3),
                                                  const Icon(Icons.lock_outline_rounded, size: 10, color: Color(0xFFCBD5E1)),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _statusChip('inactive', 'Inactive', Icons.cancel_rounded, const Color(0xFFDC2626), selectedStatus == 'inactive', () => setDialogState(() => selectedStatus = 'inactive')),
                                  ],
                                ),
                                if (!canShowOnLeave) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.lock_clock_rounded, size: 13, color: Color(0xFFD97706)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'On Leave unlocks after 3 days of employment.',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              color: const Color(0xFFD97706),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _slate)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              final title = titleController.text.trim();
                              final phone = phoneController.text.trim();
                              final empId = idController.text.trim();

                              void showValidationError(String msg) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            msg,
                                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFFDC2626),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }

                              // 1. NAME VALIDATION
                              if (name.isEmpty) {
                                showValidationError('Name is required.');
                                return;
                              }
                              if (name.length < 2) {
                                showValidationError('Name must be at least 2 characters.');
                                return;
                              }
                              if (!RegExp(r"^[a-zA-Z\s\.\,\-\'\ñ\Ñ]+$").hasMatch(name)) {
                                showValidationError('Name can only contain letters, spaces, and standard name characters.');
                                return;
                              }

                              // 2. JOB TITLE VALIDATION
                              if (title.isEmpty) {
                                showValidationError('Job Title is required.');
                                return;
                              }
                              if (title.length < 2) {
                                showValidationError('Job Title must be at least 2 characters.');
                                return;
                              }

                              // 3. EMPLOYEE ID VALIDATION & DUPLICATE CHECK
                              if (empId.isEmpty) {
                                showValidationError('Employee ID is required.');
                                return;
                              }
                              if (!RegExp(r'^[a-zA-Z0-9\-_]+$').hasMatch(empId)) {
                                showValidationError('Employee ID can only contain letters, numbers, and hyphens (e.g. EMP001).');
                                return;
                              }

                              // Check if Employee ID is already assigned to someone else
                              final isDuplicateId = _staff.any((s) {
                                final existingId = (s['id'] ?? '').toString().trim().toUpperCase();
                                final currentId = empId.toUpperCase();
                                if (isEditing && (staff['id'] ?? '').toString().trim().toUpperCase() == existingId) {
                                  return false; // same staff being edited
                                }
                                return existingId == currentId;
                              });
                              if (isDuplicateId) {
                                showValidationError('Employee ID "$empId" is already taken by another staff member.');
                                return;
                              }

                              // 4. CONTACT NUMBER VALIDATION (Strictly exact 11 digits, numbers only, e.g. 09123456789)
                              if (phone.isEmpty) {
                                showValidationError('Contact Number is required.');
                                return;
                              }
                              if (RegExp(r'[a-zA-Z]').hasMatch(phone)) {
                                showValidationError('Contact Number cannot contain letters. Numbers only.');
                                return;
                              }
                              final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
                              if (digitsOnly.length != 11) {
                                showValidationError('Contact Number must be exactly 11 digits (e.g. 09123456789). Current: ${digitsOnly.length} digits.');
                                return;
                              }
                              if (!digitsOnly.startsWith('09')) {
                                showValidationError('Contact Number must start with 09 (e.g. 09123456789).');
                                return;
                              }
                              final formattedPhone = '+63 ${digitsOnly.substring(1, 4)} ${digitsOnly.substring(4, 7)} ${digitsOnly.substring(7)}';

                              // 5. DEPARTMENT & ROLE VALIDATION
                              if (selectedDept.isEmpty || selectedDept == '__add_dept__') {
                                showValidationError('Please select a valid Department.');
                                return;
                              }
                              if (selectedRole.isEmpty || selectedRole == '__add_role__') {
                                showValidationError('Please select a valid Role / Access level.');
                                return;
                              }

                              int colorHex = 0xFF14332E;
                              if (selectedDept == 'Management') colorHex = 0xFF0284C7;
                              if (selectedDept == 'Kitchen') colorHex = 0xFFD97706;
                              if (selectedDept == 'Service') colorHex = 0xFF0891B2;
                              if (selectedDept == 'Operations') colorHex = 0xFF7C3AED;

                              final updatedData = {
                                'name': name,
                                'full_name': name,
                                'title': title,
                                'dept': selectedDept,
                                'role': selectedRole,
                                'level': selectedLevel,
                                'status': selectedStatus,
                                'phone': formattedPhone,
                                'id': empId,
                                'colorHex': colorHex,
                                'image': currentPhoto ?? '',
                                'date_hired': isEditing
                                    ? (staff['date_hired'] ?? DateTime.now().toIso8601String())
                                    : DateTime.now().toIso8601String(),
                              };

                              setState(() {
                                if (isEditing) {
                                  final targetId = staff['id']?.toString() ?? empId;
                                  final idx = _staff.indexWhere((s) => s['id']?.toString() == targetId);
                                  if (idx != -1) {
                                    _staff[idx] = updatedData;
                                  } else {
                                    final nameIdx = _staff.indexWhere((s) => s['name'] == staff['name']);
                                    if (nameIdx != -1) {
                                      _staff[nameIdx] = updatedData;
                                    } else {
                                      _staff.insert(0, updatedData);
                                    }
                                  }
                                } else {
                                  _staff.insert(0, updatedData);
                                }
                              });

                              // Save to database & local storage
                              final bool dbSaved = await StaffService.saveStaffList(_staff);

                              AuditLogService.logActivity(
                                action: isEditing ? 'UPDATE' : 'CREATE',
                                module: 'Users',
                                description: isEditing
                                    ? 'Updated staff profile for "${updatedData['name']}" (${updatedData['id']}) - Role: ${updatedData['role']}'
                                    : 'Added new staff member "${updatedData['name']}" (${updatedData['id']}) - Role: ${updatedData['role']}',
                                entityId: updatedData['id']?.toString(),
                                metadata: updatedData,
                              );

                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          dbSaved ? Icons.cloud_done_rounded : Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            isEditing
                                                ? 'Staff "$name" updated & synced to database!'
                                                : 'New staff "$name" ($empId) saved to database!',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: _emerald,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _emerald,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              isEditing ? 'Save Changes' : 'Add Member',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ARCHIVE STAFF DIALOG (Replaces Permanent Deletion)
  // -------------------------------------------------------------------------
  void _showArchiveDialog(Map<String, dynamic> staff) {
    final empId = (staff['id'] ?? staff['employee_id'] ?? '').toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.archive_rounded, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'Archive Staff Member',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to archive "${staff['name']}" ($empId)?\n\nThis staff member will be moved to the Archived Staff list. You can view their details or restore them back to the active directory anytime.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _slate)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                staff['status'] = 'archived';
              });
              _saveStaffData();
              if (empId.isNotEmpty) {
                StaffService.archiveStaffMember(empId);
              }

              AuditLogService.logActivity(
                action: 'ARCHIVE',
                module: 'Users',
                description: 'Archived staff member "${staff['name']}" ($empId)',
                entityId: empId,
                metadata: staff,
              );

              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.archive_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${staff['name']} moved to Archived Staff.',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFD97706),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            icon: const Icon(Icons.archive_rounded, size: 16, color: Colors.white),
            label: Text('Archive Staff', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ARCHIVED STAFF MODAL (View Details & Restore Capability)
  // -------------------------------------------------------------------------
  void _showArchivedStaffModal() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final archivedList = _archivedStaff;
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 580,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modal Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.inventory_2_rounded, color: Color(0xFFD97706), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Archived Staff Records',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _darkBg,
                              ),
                            ),
                            Text(
                              '${archivedList.length} archived member${archivedList.length == 1 ? '' : 's'}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  if (archivedList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.archive_outlined, size: 48, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 12),
                            Text(
                              'No Archived Staff',
                              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: _slate),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Archived staff will appear here for information and recovery.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 380),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: archivedList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final s = archivedList[idx];
                          final empId = (s['id'] ?? s['employee_id'] ?? '').toString();
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _slateLight),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFFD97706).withValues(alpha: 0.15),
                                  child: Text(
                                    (s['name'] ?? 'S')[0].toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFD97706),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s['name'] ?? '',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: _darkBg,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$empId · ${s['title'] ?? s['role'] ?? ''}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: _slate,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // View Info Button
                                TextButton.icon(
                                  onPressed: () => _showStaffDetailsDialog(s),
                                  icon: const Icon(Icons.info_outline_rounded, size: 14, color: _slate),
                                  label: Text(
                                    'Details',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: _slate),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Restore Button
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      s['status'] = 'active';
                                    });
                                    _saveStaffData();
                                    if (empId.isNotEmpty) {
                                      StaffService.restoreStaffMember(empId);
                                    }
                                    setModalState(() {});

                                    AuditLogService.logActivity(
                                      action: 'RESTORE',
                                      module: 'Users',
                                      description: 'Restored archived staff member "${s['name']}" ($empId) back to active',
                                      entityId: empId,
                                      metadata: s,
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Restored ${s['name']} back to active staff directory!'),
                                        backgroundColor: _emerald,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.unarchive_rounded, size: 14, color: Colors.white),
                                  label: Text(
                                    'Restore',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _emerald,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _slate)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // FULL STAFF INFORMATION DETAILS MODAL
  // -------------------------------------------------------------------------
  void _showStaffDetailsDialog(Map<String, dynamic> staff) {
    final empId = (staff['id'] ?? staff['employee_id'] ?? '').toString();
    final name = (staff['name'] ?? staff['full_name'] ?? '').toString();
    final title = (staff['title'] ?? '').toString();
    final role = (staff['role'] ?? '').toString();
    final dept = (staff['dept'] ?? '').toString();
    final phone = (staff['phone'] ?? '').toString();
    final level = staff['level'] is int ? staff['level'] as int : int.tryParse(staff['level']?.toString() ?? '2') ?? 2;
    final status = (staff['status'] ?? 'active').toString().toUpperCase();
    final dateHired = staff['date_hired']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.badge_rounded, color: _emerald, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Staff Information Details',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile Card Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _slateLight),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: _emerald,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'S',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: _gold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: _darkBg),
                        ),
                        Text(
                          title.isNotEmpty ? title : role,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _slate, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _emerald.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            empId,
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: _emerald),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Detail rows
            _detailInfoRow('Employee ID', empId, Icons.badge_outlined),
            _detailInfoRow('Role / Access', role, Icons.admin_panel_settings_outlined),
            _detailInfoRow('Department', dept.isNotEmpty ? dept : 'Kitchen', Icons.business_rounded),
            _detailInfoRow('Hierarchy Level', _getLevelLabel(level), Icons.stairs_rounded),
            _detailInfoRow('Contact Number', phone.isNotEmpty ? phone : 'N/A', Icons.phone_outlined),
            _detailInfoRow('Status', status, Icons.info_outline_rounded),
            if (dateHired.isNotEmpty)
              _detailInfoRow('Date Registered', dateHired.split('T').first, Icons.calendar_today_rounded),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _slate)),
          ),
        ],
      ),
    );
  }

  Widget _detailInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _slate),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: _darkBg),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 16, color: _slate),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _slateLight)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _emerald, width: 1.5)),
    );
  }

  Widget _levelChip(int level, String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _emerald : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? _emerald : _slateLight),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String statusKey, String label, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : _slateLight, width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: isSelected ? color : _slate),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // STAFF DETAIL PROFILE MODAL WITH EDIT / DELETE ACTIONS
  // -------------------------------------------------------------------------
  void _showStaffModal(Map<String, dynamic> staff) {
    final accentColor = Color(staff['colorHex'] as int? ?? 0xFF14332E);
    final status = (staff['status'] ?? 'active').toString();
    // Support both 'full_name' and legacy 'name' key
    final name = (staff['full_name'] ?? staff['name']) as String? ?? '';
    final photo = staff['image'] as String?;

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
                          icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 76,
                      height: 76,
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
                      child: _buildStaffAvatar(photo, name, accentColor, size: 76),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      staff['title'] as String? ?? '',
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            staff['role'] as String? ?? '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: Colors.white),
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
                            value: staff['id'] as String? ?? '',
                            icon: Icons.badge_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _modalStatBox(
                            label: 'Department',
                            value: staff['dept'] as String? ?? '',
                            icon: Icons.business_center_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _modalDetailRow(Icons.phone_rounded, 'Mobile', staff['phone'] as String? ?? 'N/A'),
                    _modalDetailRow(Icons.work_rounded, 'Role', staff['role'] as String? ?? 'N/A'),

                    const SizedBox(height: 18),

                    // Actions Row: Edit / Delete
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showAddEditStaffModal(staff);
                            },
                            icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF0284C7)),
                            label: Text(
                              'Edit Details & Photo',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF0284C7)),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFF0284C7)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showArchiveDialog(staff);
                            },
                            icon: const Icon(Icons.archive_outlined, size: 16, color: Color(0xFFD97706)),
                            label: Text(
                              'Archive',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFFD97706)),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFD97706)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
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
