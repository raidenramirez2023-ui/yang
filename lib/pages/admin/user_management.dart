import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:yang_chow/services/staff_service.dart';
import 'package:yang_chow/services/image_storage_service.dart';
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
  String _sortBy = 'name_asc';
  bool _isRefreshing = false;
  bool _isExportingCsv = false;

  // Quick filter from stat tile tap: null = no filter
  // Values: 'active', 'on-leave', 'inactive', 'managers', 'portal'
  String? _quickFilter;

  // Color constants
  static const _darkBg = Color(0xFF0F172A);
  static const _emerald = Color(0xFF14332E);
  static const _gold = Color(0xFFD9A441);
  static const _slate = Color(0xFF64748B);
  static const _slateLight = Color(0xFFE2E8F0);

  // Departments for filter â mutable so custom depts added in modal appear here too
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
      if (mounted) {
        setState(() {
          _staff = list;
          // Dynamically merge any unique departments from staff records into _departments
          for (final s in list) {
            final d = (s['dept'] ?? '').toString().trim();
            if (d.isNotEmpty && !_departments.contains(d)) {
              _departments.add(d);
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _staff = [];
          _isLoading = false;
        });
      }
    }
  }

  /// Load persisted custom departments & roles from Supabase app_settings (with local fallback)
  Future<void> _loadCustomLists() async {
    try {
      final depts = await StaffService.loadCustomDepartments();
      final roles = await StaffService.loadCustomRoles();
      if (mounted && (depts.isNotEmpty || roles.isNotEmpty)) {
        setState(() {
          for (final d in depts) {
            if (!_departments.contains(d)) _departments.add(d);
          }
          for (final r in roles) {
            if (!_customRoles.contains(r)) _customRoles.add(r);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading custom lists: $e');
    }
  }


  /// Persist custom roles to Supabase app_settings & local storage
  Future<void> _saveCustomRoles() async {
    try {
      await StaffService.saveCustomRoles(_customRoles);
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
    final list = _staff.where((s) {
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

      // Quick filter from stat tile
      bool matchesQuick = true;
      if (_quickFilter != null) {
        final status = (s['status'] ?? 'active').toString().toLowerCase();
        final level = s['level'] is int ? s['level'] as int : int.tryParse(s['level']?.toString() ?? '') ?? 0;
        final email = (s['email'] ?? '').toString().trim();
        switch (_quickFilter) {
          case 'active':
            matchesQuick = status == 'active';
            break;
          case 'on-leave':
            matchesQuick = status == 'on-leave';
            break;
          case 'inactive':
            matchesQuick = status == 'inactive';
            break;
          case 'managers':
            matchesQuick = level >= 3;
            break;
          case 'portal':
            matchesQuick = email.isNotEmpty;
            break;
          default:
            matchesQuick = true;
        }
      }

      return matchesSearch && matchesDept && matchesQuick;
    }).toList();

    list.sort((a, b) {
      switch (_sortBy) {
        case 'name_desc':
          final nameA = (a['name'] ?? a['full_name'] ?? '').toString().toLowerCase();
          final nameB = (b['name'] ?? b['full_name'] ?? '').toString().toLowerCase();
          return nameB.compareTo(nameA);
        case 'newest':
          final dateA = DateTime.tryParse((a['date_hired'] ?? '').toString()) ?? DateTime(2000);
          final dateB = DateTime.tryParse((b['date_hired'] ?? '').toString()) ?? DateTime(2000);
          return dateB.compareTo(dateA);
        case 'level':
          final lvlA = a['level'] is int ? a['level'] as int : int.tryParse(a['level']?.toString() ?? '') ?? 0;
          final lvlB = b['level'] is int ? b['level'] as int : int.tryParse(b['level']?.toString() ?? '') ?? 0;
          return lvlB.compareTo(lvlA);
        case 'name_asc':
        default:
          final nameA = (a['name'] ?? a['full_name'] ?? '').toString().toLowerCase();
          final nameB = (b['name'] ?? b['full_name'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
      }
    });

    return list;
  }

  List<Map<String, dynamic>> get _archivedStaff {
    return _staff.where((s) => (s['status'] ?? '').toString().toLowerCase() == 'archived').toList();
  }

  int get _nextEmpNumber {
    int maxNum = 0;
    for (final s in _staff) {
      final idStr = (s['id'] ?? s['employee_id'] ?? '').toString();
      final match = RegExp(r'EMP(\d+)', caseSensitive: false).firstMatch(idStr);
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    return (maxNum > 0) ? (maxNum + 1) : (_staff.length + 1);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final filtered = _filteredStaff;

    // Count stats — fully dynamic from loaded staff list
    final activeCount    = _staff.where((s) => s['status'] == 'active').length;
    final onLeaveCount   = _staff.where((s) => s['status'] == 'on-leave').length;
    final inactiveCount  = _staff.where((s) => s['status'] == 'inactive').length;
    final managersCount  = _staff.where((s) {
      final lvl = s['level'] is int ? s['level'] as int : int.tryParse(s['level']?.toString() ?? '') ?? 0;
      return lvl >= 3;
    }).length;
    final portalCount    = _staff.where((s) => (s['email'] ?? '').toString().trim().isNotEmpty).length;

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
                  _buildStatsRow(isMobile, activeCount, onLeaveCount, inactiveCount, managersCount, portalCount),
                  const SizedBox(height: 16),


                  // ---- SEARCH + DEPT FILTER ----
                  _buildSearchAndFilter(isMobile),
                  const SizedBox(height: 20),

                  // ---- STAFF SECTION HEADER WITH ADD BUTTON ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${filtered.length} member${filtered.length == 1 ? '' : 's'} found',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: _slate,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Action Buttons
                      Row(
                        children: [
                          // ð¦ Archived Staff Button
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
                          // Export CSV Button
                          OutlinedButton.icon(
                            onPressed: _isExportingCsv ? null : _exportStaffRosterCsv,
                            icon: _isExportingCsv
                                ? const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: _emerald),
                                  )
                                : const Icon(Icons.file_download_outlined, size: 15, color: _emerald),
                           label: Text(
                              isMobile ? 'Excel' : 'Export Excel',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: _emerald,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: _emerald.withValues(alpha: 0.4)),
                              backgroundColor: Colors.white,
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
                          // â Add Staff Action Button
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

                  // ---- QUICK FILTER ACTIVE CHIP ----
                  if (_quickFilter != null) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14332E).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF14332E).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.filter_alt_rounded, size: 13, color: _emerald),
                                const SizedBox(width: 6),
                                Text(
                                  'Filtered: ${_quickFilterLabel(_quickFilter!)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _emerald,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => setState(() => _quickFilter = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: _emerald.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 12, color: _emerald),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

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

  String _quickFilterLabel(String key) {
    switch (key) {
      case 'active':    return 'Active Personnel';
      case 'on-leave':  return 'On Leave';
      case 'inactive':  return 'Inactive';
      case 'managers':  return 'Managers (L3+)';
      case 'portal':    return 'Portal Access';
      default:          return key;
    }
  }

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
                        'Employee Management',
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
                        'Directory',
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
                  'Manage, add, edit, and organize restaurant employees, roles, and credentials',
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
  Widget _buildStatsRow(
    bool isMobile,
    int active,
    int onLeave,
    int inactive,
    int managers,
    int portalAccess,
  ) {
    final total = _staff.length;

    final tiles = [
      _statTile(
        label: 'Total Staff',
        value: total.toString(),
        icon: Icons.groups_rounded,
        iconColor: _emerald,
        filterKey: null,
      ),
      _statTile(
        label: 'Active Personnel',
        value: active.toString(),
        icon: Icons.check_circle_rounded,
        iconColor: const Color(0xFF15803D),
        filterKey: 'active',
      ),
      _statTile(
        label: 'On Leave',
        value: onLeave.toString(),
        icon: Icons.event_busy_rounded,
        iconColor: const Color(0xFFD97706),
        filterKey: 'on-leave',
      ),
      _statTile(
        label: 'Inactive',
        value: inactive.toString(),
        icon: Icons.person_off_rounded,
        iconColor: const Color(0xFF64748B),
        filterKey: 'inactive',
      ),
      _statTile(
        label: 'Managers (L3+)',
        value: managers.toString(),
        icon: Icons.manage_accounts_rounded,
        iconColor: const Color(0xFF0F766E),
        filterKey: 'managers',
      ),
      _statTile(
        label: 'Portal Access',
        value: portalAccess.toString(),
        icon: Icons.key_rounded,
        iconColor: const Color(0xFF0284C7),
        filterKey: 'portal',
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 70,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: tiles.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => SizedBox(width: 155, child: tiles[i]),
        ),
      );
    }

    // Responsive layout for desktop/tablet:
    // If wide enough (>= 980px), display all 6 in a single clean row.
    // Otherwise, 2 neat rows of 3.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 980) {
          return Row(
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: tiles[0]),
                const SizedBox(width: 8),
                Expanded(child: tiles[1]),
                const SizedBox(width: 8),
                Expanded(child: tiles[2]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: tiles[3]),
                const SizedBox(width: 8),
                Expanded(child: tiles[4]),
                const SizedBox(width: 8),
                Expanded(child: tiles[5]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String? filterKey,
    String? subLabel,
  }) {
    final isTotal = filterKey == null;
    final isActive = filterKey != null && _quickFilter == filterKey;
    final isSelectedAll = isTotal && _quickFilter == null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          if (isTotal) {
            _quickFilter = null;
          } else {
            _quickFilter = (_quickFilter == filterKey) ? null : filterKey;
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: (isActive || isSelectedAll)
                ? _emerald.withValues(alpha: 0.035)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (isActive || isSelectedAll)
                  ? _emerald
                  : const Color(0xFFE2E8F0),
              width: (isActive || isSelectedAll) ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isActive || isSelectedAll)
                    ? _emerald.withValues(alpha: 0.08)
                    : const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (isActive || isSelectedAll)
                      ? _emerald.withValues(alpha: 0.1)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (isActive || isSelectedAll)
                        ? _emerald.withValues(alpha: 0.25)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Icon(
                  icon,
                  color: (isActive || isSelectedAll) ? _emerald : iconColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: (isActive || isSelectedAll) ? _emerald : const Color(0xFF64748B),
                        fontWeight: (isActive || isSelectedAll) ? FontWeight.w700 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subLabel != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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
        // Search bar + Sort + Refresh row
        Row(
          children: [
            Expanded(
              child: Container(
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
                    hintText: isMobile ? 'Search staff...' : 'Search staff by name, title, role, or ID...',
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
            ),
            const SizedBox(width: 8),

            // Sort Dropdown
            Container(
              height: 48,
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
              child: PopupMenuButton<String>(
                tooltip: 'Sort Staff',
                initialValue: _sortBy,
                onSelected: (val) => setState(() => _sortBy = val),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort_rounded, color: _emerald, size: 20),
                      if (!isMobile) ...[
                        const SizedBox(width: 6),
                        Text(
                          _sortLabel(_sortBy),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: _slate, size: 18),
                      ],
                    ],
                  ),
                ),
                itemBuilder: (ctx) => [
                  _buildSortMenuItem('name_asc', 'Name (A – Z)', Icons.sort_by_alpha_rounded),
                  _buildSortMenuItem('name_desc', 'Name (Z – A)', Icons.sort_by_alpha_rounded),
                  _buildSortMenuItem('newest', 'Newest First', Icons.schedule_rounded),
                  _buildSortMenuItem('level', 'Access Level (L4 – L1)', Icons.shield_rounded),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Refresh Button
            Container(
              height: 48,
              width: 48,
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
              child: IconButton(
                tooltip: 'Refresh staff list',
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _emerald),
                      )
                    : const Icon(Icons.refresh_rounded, color: _emerald, size: 20),
                onPressed: _isRefreshing ? null : _handleRefresh,
              ),
            ),
          ],
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

  String _sortLabel(String sortKey) {
    switch (sortKey) {
      case 'name_desc':
        return 'Sort: Z – A';
      case 'newest':
        return 'Sort: Newest';
      case 'level':
        return 'Sort: Level (L4–L1)';
      case 'name_asc':
      default:
        return 'Sort: A – Z';
    }
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String title, IconData icon) {
    final isSelected = _sortBy == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: isSelected ? _emerald : _slate),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _emerald : const Color(0xFF1E293B),
              ),
            ),
          ),
          if (isSelected) const Icon(Icons.check_rounded, size: 16, color: _emerald),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await _loadStaffData();
      await _loadCustomLists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Staff roster refreshed from server.'),
            backgroundColor: _emerald,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
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
                          } else if (val == 'reset_password') {
                            _showResetPasswordDialog(staff);
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
                          if ((staff['email'] ?? '').toString().trim().isNotEmpty)
                            PopupMenuItem(
                              value: 'reset_password',
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_reset_rounded, size: 16, color: Color(0xFF7C3AED)),
                                  const SizedBox(width: 8),
                                  Text('Reset Portal Password', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF7C3AED))),
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
        return 'L4 Â· EXEC';
      case 3:
        return 'L3 Â· SR. MGR';
      case 2:
        return 'L2 Â· STAFF';
      case 1:
        return 'L1 Â· SUPPORT';
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

  /// Generates a strong, secure 10-char temporary password.
  /// Guarantees: at least 8+ chars, 1 uppercase, 1 lowercase, 1 digit, and 1 special character.
  String _generatePassword() {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnpqrstuvwxyz';
    const digits = '23456789';
    const specials = '@#\$%&*!?';
    const all = '$upper$lower$digits$specials';

    final rng = Random.secure();

    // Guarantee required character classes (2 upper, 3 lower, 2 digits, 2 special + 1 random = 10 chars)
    final chars = <String>[
      upper[rng.nextInt(upper.length)],
      upper[rng.nextInt(upper.length)],
      lower[rng.nextInt(lower.length)],
      lower[rng.nextInt(lower.length)],
      lower[rng.nextInt(lower.length)],
      digits[rng.nextInt(digits.length)],
      digits[rng.nextInt(digits.length)],
      specials[rng.nextInt(specials.length)],
      specials[rng.nextInt(specials.length)],
      all[rng.nextInt(all.length)],
    ];

    // Shuffle characters to avoid predictable ordering
    chars.shuffle(rng);
    return chars.join();
  }

  /// Auto-detect the department based on role title keywords.
  /// Mirrors the same logic used by StaffService._inferDepartment().
  String _detectDeptFromRole(String role) {
    final r = role.toLowerCase();
    if (r.contains('manager') || r.contains('supervisor') || r.contains('admin') ||
        r.contains('owner') || r.contains('exec') || r.contains('director') || r.contains('ceo')) {
      return 'Management';
    } else if (r.contains('cook') || r.contains('chef') || r.contains('cutter') ||
        r.contains('prep') || r.contains('kitchen') || r.contains('dishwasher') ||
        r.contains('busboy') || r.contains('cleaner')) {
      return 'Kitchen';
    } else if (r.contains('server') || r.contains('wait') || r.contains('dine') ||
        r.contains('host') || r.contains('concierge')) {
      return 'Service';
    } else if (r.contains('cashier') || r.contains('inventory') || r.contains('stock') ||
        r.contains('warehouse') || r.contains('utility') || r.contains('delivery')) {
      return 'Operations';
    }
    return 'Operations'; // default
  }

  /// Check if a role is tied to one of the 4 system portals (Admin, chefycp, staffycp, pagsanjaninv).
  /// Normal staff roles (e.g. Dishwasher, Cleaner, Utility, or custom roles) do not have portal access.
  bool _isPortalRole(String role) {
    const portalRoles = {
      'Admin',
      'Cook',
      'Cashier & Food Server',
      'Inventory Staff',
    };
    if (portalRoles.contains(role)) return true;
    final r = role.toLowerCase();
    if (r == 'chef' || r == 'cashier' || r == 'restaurant manager') return true;
    return false;
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
              'No Employees Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _darkBg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search or add a new employee.',
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
                'Add New Employee',
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
              if (selected == 'inactive' && (staff['email'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Setting to Inactive will prompt you to disable portal login access for this staff member.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF92400E), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _slate)),
            ),
            ElevatedButton(
              onPressed: () {
                final prevStatus = current;
                setState(() {
                  staff['status'] = selected;
                });
                _saveStaffData();

                AuditLogService.logActivity(
                  action: 'STATUS_CHANGE',
                  module: 'Users',
                  description: 'Changed status for "${staff['name']}" (${staff['id']}) from ${prevStatus.toUpperCase()} to ${selected.toUpperCase()}',
                  entityId: staff['id']?.toString(),
                  metadata: {
                    'staff_name': staff['name'],
                    'staff_id': staff['id'],
                    'previous_status': prevStatus,
                    'new_status': selected,
                  },
                );

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Updated ${staff['name']}\'s status to: ${selected.toUpperCase()}'),
                    backgroundColor: selected == 'inactive' ? const Color(0xFFDC2626) : _emerald,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );

                final email = (staff['email'] ?? '').toString().trim();
                if (selected == 'inactive' && email.isNotEmpty) {
                  _showDeactivatePortalPrompt(staff);
                } else if (prevStatus == 'inactive' && selected == 'active' && email.isNotEmpty) {
                  _showReactivatePortalPrompt(staff);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: selected == 'inactive' ? const Color(0xFFDC2626) : _emerald,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Update Status', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeactivatePortalPrompt(Map<String, dynamic> staff) {
    final email = (staff['email'] ?? '').toString().trim();
    if (email.isEmpty) return;

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
              child: const Icon(Icons.lock_person_rounded, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Disable Portal Login?',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          '${staff['name']} has been set to Inactive.\n\nWould you also like to disable their portal login access ($email)? They will no longer be able to log in until reactivated.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Access', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _slate)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StaffService.deactivateStaffAuthAccount(email);
              AuditLogService.logActivity(
                action: 'DEACTIVATE_PORTAL',
                module: 'Users',
                description: 'Deactivated portal login for "${staff['name']}" ($email)',
                entityId: staff['id']?.toString(),
                metadata: {
                  'staff_name': staff['name'],
                  'staff_id': staff['id'],
                  'email': email,
                },
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Portal login disabled for ${staff['name']}.'),
                    backgroundColor: const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Disable Portal', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReactivatePortalPrompt(Map<String, dynamic> staff) {
    final email = (staff['email'] ?? '').toString().trim();
    if (email.isEmpty) return;
    final role = (staff['role'] ?? 'Staff').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.vpn_key_rounded, color: _emerald, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Re-enable Portal Login?',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          '${staff['name']} has been set back to Active.\n\nWould you like to restore their portal login access ($email)?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Disabled', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _slate)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StaffService.reactivateStaffAuthAccount(email, role);
              AuditLogService.logActivity(
                action: 'REACTIVATE_PORTAL',
                module: 'Users',
                description: 'Reactivated portal login for "${staff['name']}" ($email)',
                entityId: staff['id']?.toString(),
                metadata: {
                  'staff_name': staff['name'],
                  'staff_id': staff['id'],
                  'email': email,
                  'role': role,
                },
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Portal login re-enabled for ${staff['name']}.'),
                    backgroundColor: _emerald,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _emerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Re-enable Portal', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
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
    final existingEmail = isEditing ? ((staff['email'] ?? '') as String) : '';
    final emailController = TextEditingController(text: existingEmail);
    final passwordController = TextEditingController(text: _generatePassword());
    final idController = TextEditingController(
      text: isEditing ? (staff['id'] ?? '') : 'EMP${_nextEmpNumber.toString().padLeft(3, '0')}',
    );

    String selectedRole = isEditing ? (staff['role'] ?? 'Cook') : 'Cook';
    String selectedDept = _detectDeptFromRole(selectedRole);
    bool createLoginAccount = !isEditing && _isPortalRole(selectedRole);
    bool isPasswordVisible = false;
    int selectedLevel = _detectLevelFromRole(selectedRole);
    String selectedStatus = isEditing ? (staff['status'] ?? 'active') : 'active';
    String? currentPhoto = isEditing ? (staff['image'] as String?) : null;

    // Compute whether On Leave is available (staff must be hired >= 3 days ago)
    final String? dateHiredStr = isEditing ? staff['date_hired'] as String? : null;
    final bool canShowOnLeave = isEditing && dateHiredStr != null &&
        DateTime.now().difference(DateTime.tryParse(dateHiredStr) ?? DateTime.now()).inDays >= 3;

    // Mutable lists (so user can add custom entries)
    final List<String> deptOptions = List<String>.from(_departments.where((d) => d != 'All'));
    final List<String> roleOptions = [
      'Admin',                 // â ð¡ï¸ Admin Portal
      'Cook',                  // â ð³ chefycp (Kitchen)
      'Cashier & Food Server', // â ð¥ï¸ staffycp (POS)
      'Inventory Staff',       // â ð¦ pagsanjaninv (Inventory)
      ..._customRoles,
    ];

    // Ensure existing custom role/dept are in the lists
    if (isEditing && !roleOptions.contains(selectedRole)) roleOptions.add(selectedRole);
    if (isEditing && !deptOptions.contains(selectedDept)) deptOptions.add(selectedDept);

    bool isUploadingPhoto = false;
    bool isSavingStaff = false;
    Uint8List? pendingPhotoBytes;
    String? pendingPhotoExt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickPhoto(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final XFile? file = await picker.pickImage(
                source: source,
                maxWidth: 400,
                maxHeight: 400,
                imageQuality: 75,
              );
              if (file != null) {
                final bytes = await file.readAsBytes();
                final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
                setDialogState(() {
                  pendingPhotoBytes = bytes;
                  pendingPhotoExt = ext;
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
                    if ((currentPhoto != null && currentPhoto!.isNotEmpty) || pendingPhotoBytes != null) ...[
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
                          setDialogState(() {
                            pendingPhotoBytes = null;
                            pendingPhotoExt = null;
                            currentPhoto = null;
                          });
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
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.badge_outlined, size: 12, color: _gold),
                                  const SizedBox(width: 4),
                                  Text(
                                    idController.text,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
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
                          // ð¸ PHOTO UPLOADER SECTION (Camera + Gallery)
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: isUploadingPhoto ? null : showImageSourceSelector,
                                      child: Container(
                                        width: 84,
                                        height: 84,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(color: _emerald.withValues(alpha: 0.3), width: 2),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            if (pendingPhotoBytes != null)
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(22),
                                                child: Image.memory(
                                                  pendingPhotoBytes!,
                                                  width: 84,
                                                  height: 84,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            else
                                              _buildStaffAvatar(
                                                currentPhoto,
                                                nameController.text.isEmpty ? 'New Staff' : nameController.text,
                                                _emerald,
                                                size: 84,
                                              ),
                                            if (isUploadingPhoto)
                                              Container(
                                                width: 84,
                                                height: 84,
                                                decoration: BoxDecoration(
                                                  color: Colors.black45,
                                                  borderRadius: BorderRadius.circular(22),
                                                ),
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 28,
                                                    height: 28,
                                                    child: CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 3,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: GestureDetector(
                                        onTap: isUploadingPhoto ? null : showImageSourceSelector,
                                        child: Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: _gold,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: isUploadingPhoto
                                              ? const SizedBox(
                                                  width: 15,
                                                  height: 15,
                                                  child: CircularProgressIndicator(color: _emerald, strokeWidth: 2),
                                                )
                                              : const Icon(Icons.camera_alt_rounded, size: 15, color: _emerald),
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
                                    if ((currentPhoto != null && currentPhoto!.isNotEmpty) || pendingPhotoBytes != null) ...[
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () => setDialogState(() {
                                          currentPhoto = null;
                                          pendingPhotoBytes = null;
                                          pendingPhotoExt = null;
                                        }),
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

                          // 1. Full Name
                          _inputLabel('Full Name *'),
                          TextField(
                            controller: nameController,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: _inputDecoration('e.g. Maria Santos', Icons.person_outline_rounded),
                          ),
                          const SizedBox(height: 12),

                          // 2. Mobile Phone (Placed directly under Name for natural personal info flow)
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
                          const SizedBox(height: 12),

                          // 3. Role / Access (Left) & Department (Right) - Role is first because it auto-detects Department & Level!
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Role / Position
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _inputLabel('Role / Position *'),
                                        if (_customRoles.isNotEmpty)
                                          GestureDetector(
                                            onTap: () => _showManageRolesDialog(
                                              parentContext: context,
                                              roleOptions: roleOptions,
                                              onRoleDeleted: (deletedRole) {
                                                setDialogState(() {
                                                  if (selectedRole == deletedRole) {
                                                    selectedRole = roleOptions.first;
                                                    selectedLevel = _detectLevelFromRole(selectedRole);
                                                    selectedDept = _detectDeptFromRole(selectedRole);
                                                    createLoginAccount = !isEditing && _isPortalRole(selectedRole);
                                                  }
                                                });
                                              },
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 6),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.delete_outline_rounded, size: 12, color: Color(0xFFEF4444)),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    'Manage Roles',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFFEF4444),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
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
                                                  Expanded(
                                                    child: Text(
                                                      'Add Another Role',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: _emerald,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (_customRoles.isNotEmpty)
                                              DropdownMenuItem(
                                                value: '__manage_roles__',
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.delete_sweep_rounded, size: 14, color: Color(0xFFEF4444)),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Manage / Remove Roles',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                          color: const Color(0xFFEF4444),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                          onChanged: (val) async {
                                            if (val == '__manage_roles__') {
                                              await _showManageRolesDialog(
                                                parentContext: context,
                                                roleOptions: roleOptions,
                                                onRoleDeleted: (deletedRole) {
                                                  setDialogState(() {
                                                    if (selectedRole == deletedRole) {
                                                      selectedRole = roleOptions.first;
                                                      selectedLevel = _detectLevelFromRole(selectedRole);
                                                      selectedDept = _detectDeptFromRole(selectedRole);
                                                      createLoginAccount = !isEditing && _isPortalRole(selectedRole);
                                                    }
                                                  });
                                                },
                                              );
                                            } else if (val == '__add_role__') {
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
                                                  selectedLevel = _detectLevelFromRole(newRole);
                                                  selectedDept = _detectDeptFromRole(newRole);
                                                  createLoginAccount = !isEditing && _isPortalRole(newRole);
                                                });
                                                if (!_customRoles.contains(newRole)) {
                                                  setState(() => _customRoles.add(newRole));
                                                  _saveCustomRoles();
                                                }
                                              }
                                            } else if (val != null) {
                                              setDialogState(() {
                                                selectedRole = val;
                                                selectedLevel = _detectLevelFromRole(val);
                                                selectedDept = _detectDeptFromRole(val);
                                                createLoginAccount = !isEditing && _isPortalRole(val);
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.auto_awesome_rounded, size: 10, color: _slate),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Auto-detects Dept & Level',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _slate, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Department (Auto-assigned from Role, Locked / Read-only)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _inputLabel('Department *'),
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      alignment: Alignment.centerLeft,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _slateLight),
                                      ),
                                      child: Text(
                                        selectedDept.isEmpty ? 'Auto-assigned' : selectedDept,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.auto_awesome_rounded, size: 10, color: _slate),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Auto-assigned from Role',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9,
                                              color: _slate,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Work / Contact Email Address
                          _inputLabel(
                            _isPortalRole(selectedRole)
                                ? 'Work Email Address (For Portal Login)'
                                : 'Contact Email (Optional)',
                          ),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(
                              _isPortalRole(selectedRole)
                                  ? 'e.g. maria.staff@yangchow.com'
                                  : 'e.g. maria@gmail.com (Optional)',
                              Icons.email_outlined,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Portal Access or Normal Staff Badge
                          Builder(builder: (_) {
                            final isPortal = _isPortalRole(selectedRole);
                            if (!isPortal) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF64748B).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF64748B).withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Role Type: ',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      'Normal Staff',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF334155), fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      '  Â·  Directory Record Only (No Portal Access)',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _slate),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final sysRole = StaffService.mapStaffRoleToSystemRole(selectedRole);
                            String portalName;
                            String portalDesc;
                            Color portalColor;
                            IconData portalIcon;
                            if (sysRole == 'chef') {
                              portalName = 'chefycp';
                              portalDesc = 'Kitchen Dashboard';
                              portalColor = const Color(0xFFD97706);
                              portalIcon = Icons.restaurant_menu_rounded;
                            } else if (sysRole == 'admin' || sysRole == 'backup_admin') {
                              portalName = 'Admin Portal';
                              portalDesc = 'Admin Dashboard';
                              portalColor = const Color(0xFF0284C7);
                              portalIcon = Icons.admin_panel_settings_rounded;
                            } else if (sysRole == 'inventory staff') {
                              portalName = 'pagsanjaninv';
                              portalDesc = 'Inventory Dashboard';
                              portalColor = const Color(0xFF7C3AED);
                              portalIcon = Icons.inventory_2_rounded;
                            } else {
                              portalName = 'staffycp';
                              portalDesc = 'POS / Staff Dashboard';
                              portalColor = const Color(0xFF14332E);
                              portalIcon = Icons.point_of_sale_rounded;
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: portalColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: portalColor.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.login_rounded, size: 13, color: portalColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Portal Access: ',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate, fontWeight: FontWeight.w500),
                                  ),
                                  Icon(portalIcon, size: 13, color: portalColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    portalName,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: portalColor, fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    '  Â·  $portalDesc',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _slate),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Provision System Login Account Toggle & Credentials (ONLY for Portal Roles)
                          if (_isPortalRole(selectedRole)) ...[
                            const SizedBox(height: 14),
                            Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: createLoginAccount
                                  ? const Color(0xFF14332E).withValues(alpha: 0.05)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: createLoginAccount ? _emerald.withValues(alpha: 0.4) : _slateLight,
                                width: createLoginAccount ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: createLoginAccount,
                                      activeColor: _emerald,
                                      onChanged: (val) {
                                        setDialogState(() {
                                          createLoginAccount = val ?? false;
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            createLoginAccount = !createLoginAccount;
                                          });
                                        },
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Provision System Login Account',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: _darkBg,
                                              ),
                                            ),
                                            Text(
                                              'Creates credentials in Supabase Auth for Staff Login',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                color: _slate,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _emerald.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        StaffService.mapStaffRoleToSystemRole(selectedRole).toUpperCase(),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: _emerald,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (createLoginAccount) ...[
                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _inputLabel('Temporary Password *'),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () => setDialogState(() {
                                          passwordController.text = _generatePassword();
                                        }),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            const Icon(Icons.refresh_rounded, size: 11, color: _gold),
                                            const SizedBox(width: 3),
                                            Text('Regenerate', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _gold, fontWeight: FontWeight.w600)),
                                          ]),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextField(
                                    controller: passwordController,
                                    obscureText: !isPasswordVisible,
                                    decoration: _inputDecoration('Temporary password', Icons.lock_outline_rounded).copyWith(
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                          size: 16,
                                          color: _slate,
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            isPasswordVisible = !isPasswordVisible;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Auto-generated strong password (8+ chars, upper, lower, number & symbol).',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          ],
                          const SizedBox(height: 14),

                          // Hierarchy Level (Auto-assigned from Role, Read-only)
                          _inputLabel('Staff Hierarchy Level'),
                          Row(
                            children: [
                              _levelChip(1, 'L1\nSupport', selectedLevel == 1),
                              const SizedBox(width: 6),
                              _levelChip(2, 'L2\nStaff', selectedLevel == 2),
                              const SizedBox(width: 6),
                              _levelChip(3, 'L3\nSr. Mgr', selectedLevel == 3),
                              const SizedBox(width: 6),
                              _levelChip(4, 'L4\nExec', selectedLevel == 4),
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
                              // Job Title is auto-synced from Role (no manual field shown)
                              final title = titleController.text.trim().isEmpty ? selectedRole : titleController.text.trim();
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
                              if (!RegExp(r"^[a-zA-Z\s\.\,\-\'\Ã±\Ã]+$").hasMatch(name)) {
                                showValidationError('Name can only contain letters, spaces, and standard name characters.');
                                return;
                              }

                              // 2. JOB TITLE — auto-synced from Role, no validation needed

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

                              // 6. WORK EMAIL & PASSWORD VALIDATION (If system login account enabled)
                              final email = emailController.text.trim().toLowerCase();
                              final password = passwordController.text.trim();

                              if (createLoginAccount && email.isEmpty) {
                                showValidationError('Work Email is required when provisioning a system login account.');
                                return;
                              }
                              if (email.isNotEmpty && !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email)) {
                                showValidationError('Please enter a valid email address (e.g. maria.staff@yangchow.com).');
                                return;
                              }
                              if (createLoginAccount) {
                                if (password.length < 8) {
                                  showValidationError('Temporary password must be at least 8 characters.');
                                  return;
                                }
                                final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
                                final hasLower = RegExp(r'[a-z]').hasMatch(password);
                                final hasDigit = RegExp(r'[0-9]').hasMatch(password);
                                final hasSpecial = RegExp(r'[@#\$%!&*^%+=?_\-]').hasMatch(password);
                                if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
                                  showValidationError('Temporary password must contain at least 1 uppercase, 1 lowercase, 1 digit, and 1 special character.');
                                  return;
                                }
                              }

                              int colorHex = 0xFF14332E;
                              if (selectedDept == 'Management') colorHex = 0xFF0284C7;
                              if (selectedDept == 'Kitchen') colorHex = 0xFFD97706;
                              if (selectedDept == 'Service') colorHex = 0xFF0891B2;
                              if (selectedDept == 'Operations') colorHex = 0xFF7C3AED;

                              if (isSavingStaff) return;
                              setDialogState(() {
                                isSavingStaff = true;
                              });

                              // Deferred upload: upload pending photo bytes to Firebase Storage now
                              if (pendingPhotoBytes != null) {
                                try {
                                  final downloadUrl = await ImageStorageService.uploadAvatar(
                                    bytes: pendingPhotoBytes!,
                                    userId: empId,
                                    extension: pendingPhotoExt ?? 'jpg',
                                  );
                                  if (downloadUrl != null && downloadUrl.isNotEmpty) {
                                    currentPhoto = downloadUrl;
                                  } else {
                                    currentPhoto = 'data:image/jpeg;base64,${base64Encode(pendingPhotoBytes!)}';
                                  }
                                } catch (e) {
                                  debugPrint('Error uploading staff avatar to storage: $e');
                                  currentPhoto = 'data:image/jpeg;base64,${base64Encode(pendingPhotoBytes!)}';
                                }
                              }

                              final updatedData = {
                                'name': name,
                                'full_name': name,
                                'title': title,
                                'dept': selectedDept,
                                'role': selectedRole,
                                'level': selectedLevel,
                                'status': selectedStatus,
                                'phone': formattedPhone,
                                'email': email,
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

                               final messenger = ScaffoldMessenger.of(context);

                               try {
                                 // Save to database & local storage
                                 final bool dbSaved = await StaffService.saveStaffList(_staff);

                                 // Provision Auth account if enabled
                                 Map<String, dynamic>? authResult;
                                 if (createLoginAccount && email.isNotEmpty) {
                                   authResult = await StaffService.createStaffAuthAccount(
                                     email: email,
                                     password: password,
                                     fullName: name,
                                     role: selectedRole,
                                     phone: formattedPhone,
                                     employeeId: empId,
                                   );
                                 } else if (isEditing && (email.isNotEmpty || existingEmail.isNotEmpty)) {
                                   // Synchronize profile changes to `public.users` & Supabase Auth metadata
                                   await StaffService.syncStaffUserAccount(
                                     currentEmail: email,
                                     previousEmail: existingEmail,
                                     fullName: name,
                                     phone: formattedPhone,
                                     role: selectedRole,
                                     employeeId: empId,
                                   );
                                 }

                                 AuditLogService.logActivity(
                                   action: isEditing ? 'UPDATE' : 'CREATE',
                                   module: 'Users',
                                   description: isEditing
                                       ? 'Updated staff profile for "${updatedData['name']}" (${updatedData['id']}) - Role: ${updatedData['role']}'
                                       : 'Added new staff member "${updatedData['name']}" (${updatedData['id']}) - Role: ${updatedData['role']}${createLoginAccount ? " [System Account Provisioned]" : ""}',
                                   entityId: updatedData['id']?.toString(),
                                   metadata: updatedData,
                                 );

                                 if (mounted) {
                                   Navigator.pop(ctx);
                                   if (authResult != null && authResult['success'] == true) {
                                     _showCredentialsDialog(
                                       name: name,
                                       email: email,
                                       password: password,
                                       role: authResult['systemRole']?.toString() ?? selectedRole,
                                     );
                                   } else if (authResult != null && authResult['success'] == false) {
                                     messenger.showSnackBar(
                                       SnackBar(
                                         content: Text('Staff saved, but note on Auth Account: ${authResult['error']}'),
                                         backgroundColor: const Color(0xFFD97706),
                                         behavior: SnackBarBehavior.floating,
                                         duration: const Duration(seconds: 5),
                                       ),
                                     );
                                   } else {
                                     messenger.showSnackBar(
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
                                                     ? 'Staff "$name" updated & saved successfully!'
                                                     : 'New staff "$name" ($empId) saved successfully!',
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
                                         duration: const Duration(seconds: 4),
                                       ),
                                     );
                                   }
                                 }
                               } catch (saveErr) {
                                 debugPrint('Error saving staff: $saveErr');
                                 setDialogState(() {
                                   isSavingStaff = false;
                                 });
                                 showValidationError('Failed to save staff: $saveErr');
                               }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _emerald,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSavingStaff
                                 ? const SizedBox(
                                     width: 20,
                                     height: 20,
                                     child: CircularProgressIndicator(
                                       color: Colors.white,
                                       strokeWidth: 2,
                                     ),
                                   )
                                 : Text(
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
  // MANAGE CUSTOM ROLES DIALOG
  // -------------------------------------------------------------------------
  Future<void> _showManageRolesDialog({
    required BuildContext parentContext,
    required List<String> roleOptions,
    required void Function(String deletedRole) onRoleDeleted,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setManageState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Enterprise Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.badge_outlined, color: Color(0xFF334155), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Custom Staff Roles',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_customRoles.length}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Manage directory roles created outside core portals',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                          splashRadius: 18,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),

                  // Content Body
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _customRoles.isEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Icon(Icons.shield_outlined, size: 28, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No Custom Roles',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Only the 4 standard portal positions (Admin, Cook, Cashier, Inventory) are active.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'POSITION CATALOG',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 280),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _customRoles.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, index) {
                                    final roleName = _customRoles[index];
                                    final dept = _detectDeptFromRole(roleName);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAFAFA),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Center(
                                              child: Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF475569)),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  roleName,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFE2E8F0),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        dept,
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w600,
                                                          color: const Color(0xFF475569),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Normal Staff Â· Directory Record',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 10,
                                                        color: const Color(0xFF94A3B8),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: dialogCtx,
                                                  builder: (c) => Dialog(
                                                    backgroundColor: Colors.transparent,
                                                    child: ConstrainedBox(
                                                      constraints: const BoxConstraints(maxWidth: 380),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(22),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(16),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withValues(alpha: 0.12),
                                                              blurRadius: 24,
                                                              offset: const Offset(0, 10),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Container(
                                                                  padding: const EdgeInsets.all(8),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFFFEE2E2),
                                                                    borderRadius: BorderRadius.circular(8),
                                                                  ),
                                                                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                                                                ),
                                                                const SizedBox(width: 10),
                                                                Text(
                                                                  'Remove Role',
                                                                  style: GoogleFonts.plusJakartaSans(
                                                                    fontWeight: FontWeight.w700,
                                                                    fontSize: 15,
                                                                    color: const Color(0xFF0F172A),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 12),
                                                            Text(
                                                              'Are you sure you want to remove "$roleName" from the position catalog? It will no longer be selectable for new employees.',
                                                              style: GoogleFonts.plusJakartaSans(
                                                                fontSize: 12,
                                                                height: 1.4,
                                                                color: const Color(0xFF475569),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 20),
                                                            Row(
                                                              mainAxisAlignment: MainAxisAlignment.end,
                                                              children: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(c, false),
                                                                  style: TextButton.styleFrom(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                                  ),
                                                                  child: Text(
                                                                    'Cancel',
                                                                    style: GoogleFonts.plusJakartaSans(
                                                                      fontWeight: FontWeight.w600,
                                                                      fontSize: 12,
                                                                      color: const Color(0xFF64748B),
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 8),
                                                                ElevatedButton(
                                                                  onPressed: () => Navigator.pop(c, true),
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor: const Color(0xFFDC2626),
                                                                    elevation: 0,
                                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                  ),
                                                                  child: Text(
                                                                    'Remove Role',
                                                                    style: GoogleFonts.plusJakartaSans(
                                                                      color: Colors.white,
                                                                      fontWeight: FontWeight.w700,
                                                                      fontSize: 12,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );

                                                if (confirm == true) {
                                                  setState(() {
                                                    _customRoles.remove(roleName);
                                                  });
                                                  roleOptions.remove(roleName);
                                                  await _saveCustomRoles();
                                                  onRoleDeleted(roleName);
                                                  setManageState(() {});
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(7),
                                                child: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 18,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Standard portal roles are protected',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'Done',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
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
        ),
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
              final staffEmail = (staff['email'] ?? '').toString().trim();
              if (staffEmail.isNotEmpty) {
                StaffService.deactivateStaffAuthAccount(staffEmail);
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
                          child: const Icon(Icons.archive_rounded, color: Color(0xFFD97706), size: 22),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                            '$empId Â· ${s['title'] ?? s['role'] ?? ''}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: _slate,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // View Info Button
                                    TextButton.icon(
                                      onPressed: () => _showStaffDetailsDialog(s),
                                      icon: const Icon(Icons.info_outline_rounded, size: 14, color: _slate),
                                      label: Text(
                                        'Details',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: _slate),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Delete Button
                                    TextButton.icon(
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (dCtx) => AlertDialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                            title: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 20),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    'Permanently Delete?',
                                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'You are about to permanently delete "${s['name']}" ($empId) from the system.',
                                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
                                                ),
                                                const SizedBox(height: 12),
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEE2E2),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 16),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          'This action cannot be undone. All records for this staff member will be removed permanently.',
                                                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF991B1B)),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(dCtx, false),
                                                child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _slate)),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () => Navigator.pop(dCtx, true),
                                                icon: const Icon(Icons.delete_forever_rounded, size: 15, color: Colors.white),
                                                label: Text('Delete Permanently', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFDC2626),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed == true) {
                                          // Remove from Supabase staff table
                                          if (empId.isNotEmpty) {
                                            await StaffService.deleteStaffMember(empId);
                                          }
                                          // Remove from local list
                                          setState(() {
                                            _staff.removeWhere((m) =>
                                              (m['id'] ?? m['employee_id'] ?? '').toString() == empId);
                                          });
                                          await _saveStaffData();
                                          setModalState(() {});

                                          AuditLogService.logActivity(
                                            action: 'DELETE',
                                            module: 'Users',
                                            description: 'Permanently deleted archived staff member "${s['name']}" ($empId)',
                                            entityId: empId,
                                            metadata: {'staff_name': s['name'], 'staff_id': empId},
                                          );

                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 18),
                                                    const SizedBox(width: 8),
                                                    Expanded(child: Text('${s['name']} permanently deleted.')),
                                                  ],
                                                ),
                                                backgroundColor: const Color(0xFFDC2626),
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.delete_forever_rounded, size: 14, color: Color(0xFFDC2626)),
                                      label: Text(
                                        'Delete',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        backgroundColor: const Color(0xFFFEE2E2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                                        final staffEmail = (s['email'] ?? '').toString().trim();
                                        if (staffEmail.isNotEmpty) {
                                          StaffService.reactivateStaffAuthAccount(staffEmail, (s['role'] ?? 'staff').toString());
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
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
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
                          if (title.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: _slate),
                            ),
                          ],
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
            _detailInfoRow(
              'Work Email',
              (staff['email'] ?? '').toString().isNotEmpty ? staff['email'].toString() : 'None provisioned',
              Icons.email_outlined,
            ),
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

  // -------------------------------------------------------------------------
  // CREDENTIALS MODAL (Shown when staff account is provisioned)
  // -------------------------------------------------------------------------
  void _showCredentialsDialog({
    required String name,
    required String email,
    required String password,
    required String role,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_user_rounded, color: _emerald, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Staff Account Created',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A system login account has been successfully provisioned in Supabase Auth for "$name".',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _slateLight),
              ),
              child: Column(
                children: [
                  _credentialRow('Email / Username', email),
                  const Divider(height: 16),
                  _credentialRow('Temporary Password', password),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('System Role', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _slate)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: _gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'The employee can now log in using these credentials at the Staff Login portal.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _emerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Done', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _slate)),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: _darkBg),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 16, color: _emerald),
          tooltip: 'Copy',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied $label to clipboard!'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
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

  Widget _levelChip(int level, String label, bool isSelected, [VoidCallback? onTap]) {
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

  // ─── Step 4: Reset Portal Password Dialog ───────────────────────────────────

  void _showResetPasswordDialog(Map<String, dynamic> staff) {
    final email = (staff['email'] ?? '').toString().trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This staff member has no email set. Please edit their profile and add an email first.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final pwController = TextEditingController();
    bool obscure = false;
    bool loading = false;
    String? errorMsg;

    // Generate a random temporary password
    String _generateTempPassword() {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#\$';
      final rand = Random.secure();
      return List.generate(12, (_) => chars[rand.nextInt(chars.length)]).join();
    }

    pwController.text = _generateTempPassword();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF7C3AED), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reset Portal Password',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set a new login password for ${staff['name'] ?? 'this staff member'} ($email).',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NEW TEMPORARY PASSWORD',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: pwController,
                    obscureText: obscure,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Enter new password',
                      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFFCBD5E1)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Copy password',
                            icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF7C3AED)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: pwController.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Password copied to clipboard!'),
                                  backgroundColor: const Color(0xFF7C3AED),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: obscure ? 'Show password' : 'Hide password',
                            icon: Icon(
                              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 18,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () => setStateDialog(() => obscure = !obscure),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      setStateDialog(() {
                        pwController.text = _generateTempPassword();
                        errorMsg = null;
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF7C3AED)),
                    label: Text(
                      'Generate new password',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                  if (errorMsg != null) ...
                    [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMsg!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],

                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () {
                  pwController.dispose();
                  Navigator.pop(ctx);
                },
                child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _slate)),
              ),
              ElevatedButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        final newPw = pwController.text.trim();
                        if (newPw.length < 8) {
                          setStateDialog(() => errorMsg = 'Password must be at least 8 characters.');
                          return;
                        }
                        setStateDialog(() {
                          loading = true;
                          errorMsg = null;
                        });

                        final result = await StaffService.resetStaffPassword(
                          email: email,
                          newPassword: newPw,
                        );

                        if (!ctx.mounted) return;

                        if (result['success'] == true) {
                          // Log to audit
                          final empId = (staff['id'] ?? staff['employee_id'] ?? '').toString();
                          AuditLogService.logActivity(
                            action: 'RESET_PASSWORD',
                            module: 'Users',
                            description: 'Reset portal password for "${staff['name']}" ($email)',
                            entityId: empId,
                            metadata: {'email': email, 'staff_id': empId},
                          );

                          pwController.dispose();
                          Navigator.pop(ctx);

                          _showResetSuccessDialog(
                            (staff['name'] ?? 'Staff').toString(),
                            email,
                            newPw,
                          );
                        } else {
                          setStateDialog(() {
                            loading = false;
                            errorMsg = result['error']?.toString() ?? 'Failed to reset password. Please try again.';
                          });
                        }
                      },
                icon: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock_reset_rounded, size: 16),
                label: Text(
                  loading ? 'Resetting...' : 'Reset Password',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetSuccessDialog(String staffName, String email, String newPassword) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Password Reset Complete!',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The login password for $staffName ($email) has been updated.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              Text(
                'NEW LOGIN CREDENTIALS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            newPassword,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF7C3AED),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy password',
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF7C3AED), size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: newPassword));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Password copied to clipboard!'),
                            backgroundColor: const Color(0xFF7C3AED),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Please share this temporary password with the staff member. They can change it anytime once logged in.',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Done', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  /// Helper: format a raw ISO date string to a human-readable form like "Apr 29, 2026"
  String _formatDateHired(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return raw.split('T').first;
    }
  }

  /// Helper: return the actual phone or empty string if it's the placeholder default
  String _cleanPhone(String phone) {
    const placeholder = '+63 900 000 0000';
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // Placeholder digits: 639000000000
    if (phone.trim() == placeholder || digits == '639000000000' || digits == '9000000000') {
      return '';
    }
    return phone;
  }

  Future<void> _exportStaffRosterCsv() async {
    if (_staff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No staff records to export.'),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isExportingCsv = true);

    try {
      // ── Build Excel workbook ──────────────────────────────────────────────
      final excel = xl.Excel.createExcel();
      final sheet = excel['Staff Roster'];
      // Remove the default 'Sheet1'
      excel.delete('Sheet1');

      // Header row (bold)
      const headers = [
        'Employee ID', 'Full Name', 'Role', 'Title', 'Department',
        'Access Level', 'Status', 'Work Email', 'Phone', 'Date Hired',
      ];
      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        cell.value = xl.TextCellValue(headers[col]);
        cell.cellStyle = xl.CellStyle(
          bold: true,
          backgroundColorHex: xl.ExcelColor.fromHexString('FF14332E'),
          fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        );
      }

      // Data rows
      for (int i = 0; i < _staff.length; i++) {
        final s = _staff[i];
        final rowIndex = i + 1;

        final id    = (s['id'] ?? s['employee_id'] ?? '').toString();
        final name  = (s['name'] ?? s['full_name'] ?? '').toString();
        final role  = (s['role'] ?? '').toString();
        final title = (s['title'] ?? '').toString();
        final dept  = (s['dept'] ?? '').toString();
        final level = 'L${s['level'] ?? 2}';
        final status = (s['status'] ?? 'active').toString().toUpperCase();
        final email = (s['email'] ?? '').toString();
        final phone = _cleanPhone((s['phone'] ?? '').toString());
        final dateHired = _formatDateHired((s['date_hired'] ?? '').toString());

        final rowData = [id, name, role, title, dept, level, status, email, phone, dateHired];
        for (int col = 0; col < rowData.length; col++) {
          final cell = sheet.cell(
            xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
          );
          cell.value = xl.TextCellValue(rowData[col]);
          // Alternate row shading
          if (i % 2 == 1) {
            cell.cellStyle = xl.CellStyle(
              backgroundColorHex: xl.ExcelColor.fromHexString('FFF1F5F9'),
            );
          }
        }
      }

      // Set column widths
      final colWidths = [12.0, 22.0, 20.0, 20.0, 14.0, 12.0, 10.0, 26.0, 18.0, 14.0];
      for (int i = 0; i < colWidths.length; i++) {
        sheet.setColumnWidth(i, colWidths[i]);
      }

      // Encode to bytes
      final excelBytes = excel.encode();
      if (excelBytes == null) throw Exception('Failed to encode Excel file.');
      final bytes = Uint8List.fromList(excelBytes);

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'yang_chow_staff_roster_$timestamp.xlsx';

      final outputFilePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Staff Roster Excel Export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: bytes,
      );

      if (outputFilePath != null && mounted) {
        AuditLogService.logActivity(
          action: 'EXPORT_STAFF_EXCEL',
          module: 'Users',
          description: 'Exported ${_staff.length} staff records to Excel ($fileName)',
          metadata: {
            'file_name': fileName,
            'total_exported': _staff.length,
          },
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Exported ${_staff.length} staff records to Excel!')),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export Excel: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }
}
