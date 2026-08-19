import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yang_chow/services/staff_service.dart';
import 'package:yang_chow/services/audit_log_service.dart';
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

  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaffData();
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

  Future<void> _saveStaffData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StaffService.storageKey, jsonEncode(_staff));
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
      final name = s['name'].toString().toLowerCase();
      final role = s['role'].toString().toLowerCase();
      final title = s['title'].toString().toLowerCase();
      final dept = s['dept'].toString();
      final id = (s['id'] ?? '').toString().toLowerCase();
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

  int get _nextEmpNumber {
    int maxNum = 0;
    for (final s in _staff) {
      final id = (s['id'] ?? '').toString();
      final numStr = id.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(numStr) ?? 0;
      if (parsed > maxNum) maxNum = parsed;
    }
    return maxNum + 1;
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
  // STATS ROW
  // -------------------------------------------------------------------------
  Widget _buildStatsRow(bool isMobile, int active, int onLeave, int inactive) {
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _darkBg,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
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
    final name = staff['name'] as String? ?? 'Unnamed Staff';
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

                      // 3-Dot Quick Action Menu (Edit / Delete / Toggle Status)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: _slate),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showAddEditStaffModal(staff);
                          } else if (val == 'delete') {
                            _showDeleteDialog(staff);
                          } else if (val == 'toggle_status') {
                            _toggleStaffStatus(staff);
                          }
                        },
                        itemBuilder: (ctx) => [
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
                            value: 'toggle_status',
                            child: Row(
                              children: [
                                const Icon(Icons.sync_alt_rounded, size: 16, color: Color(0xFFD97706)),
                                const SizedBox(width: 8),
                                Text('Change Status', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_rounded, size: 16, color: Color(0xFFDC2626)),
                                const SizedBox(width: 8),
                                Text('Delete Staff', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626))),
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
  // STATUS TOGGLE HELPER
  // -------------------------------------------------------------------------
  void _toggleStaffStatus(Map<String, dynamic> staff) {
    final currentStatus = staff['status'] ?? 'active';
    String nextStatus = 'active';
    if (currentStatus == 'active') {
      nextStatus = 'on-leave';
    } else if (currentStatus == 'on-leave') {
      nextStatus = 'inactive';
    } else {
      nextStatus = 'active';
    }

    setState(() {
      staff['status'] = nextStatus;
    });
    _saveStaffData();

    AuditLogService.logActivity(
      action: 'STATUS_CHANGE',
      module: 'Users',
      description: 'Changed staff status for "${staff['name']}" (${staff['id']}) to ${nextStatus.toUpperCase()}',
      entityId: staff['id']?.toString(),
      metadata: {
        'staff_name': staff['name'],
        'staff_id': staff['id'],
        'new_status': nextStatus,
        'dept': staff['dept'],
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated ${staff['name']}\'s status to: ${nextStatus.toUpperCase()}'),
        backgroundColor: _emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ADD / EDIT STAFF MODAL (With Real Photo Picker)
  // -------------------------------------------------------------------------
  void _showAddEditStaffModal(Map<String, dynamic>? staff) {
    final isEditing = staff != null;
    final nameController = TextEditingController(text: isEditing ? staff['name'] : '');
    final titleController = TextEditingController(text: isEditing ? staff['title'] : '');
    final phoneController = TextEditingController(text: isEditing ? staff['phone'] : '+63 ');
    final idController = TextEditingController(
      text: isEditing ? staff['id'] : 'EMP${_nextEmpNumber.toString().padLeft(3, '0')}',
    );

    String selectedDept = isEditing ? (staff['dept'] ?? 'Kitchen') : 'Kitchen';
    String selectedRole = isEditing ? (staff['role'] ?? 'Cook') : 'Cook';
    int selectedLevel = isEditing ? (staff['level'] ?? 2) : 2;
    String selectedStatus = isEditing ? (staff['status'] ?? 'active') : 'active';
    String? currentPhoto = isEditing ? (staff['image'] as String?) : null;

    final List<String> deptOptions = ['Management', 'Kitchen', 'Service', 'Operations'];
    final List<String> roleOptions = [
      'Supervisor',
      'Cook',
      'Cutter',
      'Cashier & Food Server',
      'Dine-in Food Server',
      'Dishwasher',
      'Admin',
      'Manager',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickPhoto(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final XFile? file = await picker.pickImage(
                source: source,
                maxWidth: 800,
                maxHeight: 800,
                imageQuality: 85,
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

                          // Full Name
                          _inputLabel('Full Name *'),
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
                                    _inputLabel('Employee ID'),
                                    TextField(
                                      controller: idController,
                                      decoration: _inputDecoration('EMP001', Icons.badge_outlined),
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
                                          value: selectedDept,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                          items: deptOptions.map((d) => DropdownMenuItem(value: d, child: Text(d, style: GoogleFonts.plusJakartaSans(fontSize: 13)))).toList(),
                                          onChanged: (val) {
                                            if (val != null) setDialogState(() => selectedDept = val);
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
                                          items: roleOptions.map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.plusJakartaSans(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                                          onChanged: (val) {
                                            if (val != null) setDialogState(() => selectedRole = val);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Mobile Phone
                          _inputLabel('Contact Number'),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _inputDecoration('+63 912 345 6789', Icons.phone_outlined),
                          ),
                          const SizedBox(height: 14),

                          // Hierarchy Level
                          _inputLabel('Staff Hierarchy Level'),
                          Row(
                            children: [
                              _levelChip(0, 'L1 (Exec)', selectedLevel == 0, () => setDialogState(() => selectedLevel = 0)),
                              const SizedBox(width: 6),
                              _levelChip(1, 'L2 (Mgr)', selectedLevel == 1, () => setDialogState(() => selectedLevel = 1)),
                              const SizedBox(width: 6),
                              _levelChip(2, 'L3 (Staff)', selectedLevel == 2, () => setDialogState(() => selectedLevel = 2)),
                              const SizedBox(width: 6),
                              _levelChip(3, 'L4 (Support)', selectedLevel == 3, () => setDialogState(() => selectedLevel = 3)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Status Selector
                          _inputLabel('Employment Status'),
                          Row(
                            children: [
                              _statusChip('active', 'Active', Icons.verified_rounded, const Color(0xFF15803D), selectedStatus == 'active', () => setDialogState(() => selectedStatus = 'active')),
                              const SizedBox(width: 8),
                              _statusChip('on-leave', 'On Leave', Icons.event_busy_rounded, const Color(0xFFD97706), selectedStatus == 'on-leave', () => setDialogState(() => selectedStatus = 'on-leave')),
                              const SizedBox(width: 8),
                              _statusChip('inactive', 'Inactive', Icons.cancel_rounded, const Color(0xFFDC2626), selectedStatus == 'inactive', () => setDialogState(() => selectedStatus = 'inactive')),
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
                            onPressed: () {
                              final name = nameController.text.trim();
                              final title = titleController.text.trim();
                              final phone = phoneController.text.trim();
                              final empId = idController.text.trim();

                              if (name.isEmpty || title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Please fill in both Full Name and Job Title'),
                                    backgroundColor: AppTheme.errorRed,
                                  ),
                                );
                                return;
                              }

                              int colorHex = 0xFF14332E;
                              if (selectedDept == 'Management') colorHex = 0xFF0284C7;
                              if (selectedDept == 'Kitchen') colorHex = 0xFFD97706;
                              if (selectedDept == 'Service') colorHex = 0xFF0891B2;
                              if (selectedDept == 'Operations') colorHex = 0xFF7C3AED;

                              final updatedData = {
                                'name': name,
                                'title': title,
                                'dept': selectedDept,
                                'role': selectedRole,
                                'level': selectedLevel,
                                'status': selectedStatus,
                                'phone': phone.isEmpty ? '+63 900 000 0000' : phone,
                                'id': empId.isEmpty ? 'EMP001' : empId,
                                'colorHex': colorHex,
                                'image': currentPhoto ?? '',
                              };

                              setState(() {
                                if (isEditing) {
                                  final idx = _staff.indexOf(staff);
                                  if (idx != -1) _staff[idx] = updatedData;
                                } else {
                                  _staff.insert(0, updatedData);
                                }
                              });
                              _saveStaffData();

                              AuditLogService.logActivity(
                                action: isEditing ? 'UPDATE' : 'CREATE',
                                module: 'Users',
                                description: isEditing
                                    ? 'Updated staff profile for "${updatedData['name']}" (${updatedData['id']}) - Role: ${updatedData['role']}'
                                    : 'Added new staff member "${updatedData['name']}" (${updatedData['id']}) - Role: ${updatedData['role']}',
                                entityId: updatedData['id']?.toString(),
                                metadata: updatedData,
                              );

                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEditing ? 'Staff details updated successfully!' : 'New staff member added successfully!'),
                                  backgroundColor: _emerald,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
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
  // DELETE CONFIRMATION DIALOG
  // -------------------------------------------------------------------------
  void _showDeleteDialog(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'Remove Staff',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${staff['name']}" (${staff['id']}) from the staff directory? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _slate)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _staff.remove(staff);
              });
              _saveStaffData();

              AuditLogService.logActivity(
                action: 'DELETE',
                module: 'Users',
                description: 'Removed staff member "${staff['name']}" (${staff['id']}) from directory',
                entityId: staff['id']?.toString(),
                metadata: staff,
              );

              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed ${staff['name']} from staff directory.'),
                  backgroundColor: const Color(0xFFDC2626),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // FORM HELPER WIDGETS
  // -------------------------------------------------------------------------
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
    final name = staff['name'] as String? ?? '';
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
                              _showDeleteDialog(staff);
                            },
                            icon: const Icon(Icons.delete_rounded, size: 16, color: Color(0xFFDC2626)),
                            label: Text(
                              'Delete',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFFDC2626)),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFDC2626)),
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
