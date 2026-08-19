import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart' as csv_pkg;

import '../../models/audit_log_model.dart';
import '../../services/audit_log_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  List<AuditLog> _logs = [];
  bool _isLoading = true;
  String? _errorMessage;

  // View Mode: 'table' or 'timeline'
  String _viewMode = 'table';

  // Filters
  final TextEditingController _searchController = TextEditingController();
  String _selectedModule = 'All Modules';
  String _selectedAction = 'All Actions';
  String _selectedDateRange = 'All Time';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Pagination / Limit
  final int _limit = 200;

  final List<String> _moduleOptions = [
    'All Modules',
    'Reservations',
    'Reschedule',
    'Payments',
    'Refunds',
    'Petty Cash',
    'Inventory',
    'Menu',
    'Users',
    'Announcements',
    'Spoilage',
    'Auth',
    'System',
  ];

  final List<String> _dateOptions = [
    'All Time',
    'Today',
    'Past 7 Days',
    'Past 30 Days',
    'Custom Range',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      DateTime? start;
      DateTime? end;

      final now = DateTime.now();
      if (_selectedDateRange == 'Today') {
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (_selectedDateRange == 'Past 7 Days') {
        start = now.subtract(const Duration(days: 7));
        end = now;
      } else if (_selectedDateRange == 'Past 30 Days') {
        start = now.subtract(const Duration(days: 30));
        end = now;
      } else if (_selectedDateRange == 'Custom Range') {
        start = _customStartDate;
        end = _customEndDate;
      }

      final results = await AuditLogService.fetchLogs(
        searchQuery: _searchController.text,
        module: _selectedModule,
        action: _selectedAction,
        startDate: start,
        endDate: end,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          _logs = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load audit trail: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportLogsToCSV() async {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audit logs available to export.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      List<List<dynamic>> rows = [];
      rows.add([
        'YANG CHOW PALACE RESTAURANT AUDIT TRAIL REPORT',
      ]);
      rows.add([
        'Exported At: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
        'Total Records: ${_logs.length}',
      ]);
      rows.add([]);
      rows.add([
        'Timestamp',
        'User Name',
        'User Email',
        'Role',
        'Module',
        'Action',
        'Description',
        'Entity ID',
        'Metadata (JSON)',
      ]);

      for (var log in _logs) {
        rows.add([
          DateFormat('yyyy-MM-dd HH:mm:ss').format(log.createdAt),
          log.userName,
          log.userEmail,
          log.userRole,
          log.module,
          log.action,
          log.description,
          log.entityId ?? '',
          jsonEncode(log.metadata),
        ]);
      }

      final csvContent = csv_pkg.CsvCodec().encode(rows);
      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final fileName = 'audit_logs_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

      final outputFilePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Audit Trail CSV Export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (outputFilePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Exported ${_logs.length} audit logs successfully!')),
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
            content: Text('Failed to export CSV: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showLogDetailsDialog(AuditLog log) {
    showDialog(
      context: context,
      builder: (context) {
        final formattedDate = DateFormat('MMMM dd, yyyy • hh:mm:ss a').format(log.createdAt);
        final moduleColor = _getModuleColor(log.module);
        final roleColor = _getRoleColor(log.userRole);

        // Helper to format metadata key names into human readable labels
        String formatKeyName(String key) {
          return key
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
              .join(' ');
        }

        // Helper to format metadata values into human readable text
        String formatKeyValue(String key, dynamic value) {
          if (value == null) return 'N/A';
          if (key.contains('amount') || key.contains('cost') || key.contains('total') || key.contains('price')) {
            if (value is num) return '₱${value.toStringAsFixed(2)}';
          }
          if (key.contains('id') && value is String && value.length == 36) {
            return '#${value.substring(0, 8).toUpperCase()}';
          }
          return value.toString();
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _getActionColor(log.action).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _getActionColor(log.action).withValues(alpha: 0.2)),
                            ),
                            child: Icon(
                              _getActionIcon(log.action),
                              color: _getActionColor(log.action),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Activity Details',
                                      style: GoogleFonts.inter(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: moduleColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        log.module.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: moduleColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedDate,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 16),

                      // Scrollable Body
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Processed By Card
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: roleColor.withValues(alpha: 0.15),
                                      child: Text(
                                        log.userName.isNotEmpty ? log.userName[0].toUpperCase() : 'U',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: roleColor),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                log.userName,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              _buildRolePill(log.userRole),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            log.userEmail,
                                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Human Readable Action Summary
                              Text(
                                'SUMMARY OF ACTION',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  log.description,
                                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), height: 1.4),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Clean Transaction Details
                              if (log.metadata.isNotEmpty) ...[
                                Text(
                                  'TRANSACTION DETAILS',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF64748B),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: log.metadata.entries.map((entry) {
                                      final isLongUuid = entry.value is String && (entry.value as String).length == 36;
                                      final displayVal = formatKeyValue(entry.key, entry.value);

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 140,
                                              child: Text(
                                                formatKeyName(entry.key),
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      displayVal,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                  ),
                                                  if (isLongUuid)
                                                    InkWell(
                                                      onTap: () {
                                                        Clipboard.setData(ClipboardData(text: entry.value.toString()));
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('ID copied!'), duration: Duration(seconds: 1)),
                                                        );
                                                      },
                                                      child: const Padding(
                                                        padding: EdgeInsets.all(2.0),
                                                        child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF0284C7)),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14332E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'APPROVE':
        return const Color(0xFF15803D); // Emerald Green
      case 'REJECT':
        return const Color(0xFFDC2626); // Red
      case 'CREATE':
        return const Color(0xFF0284C7); // Blue
      case 'UPDATE':
      case 'STATUS_CHANGE':
        return const Color(0xFFD97706); // Amber
      case 'DELETE':
        return const Color(0xFFB91C1C); // Crimson
      case 'LOGIN':
        return const Color(0xFF7C3AED); // Purple
      case 'EXPORT':
        return const Color(0xFF4F46E5); // Indigo
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'APPROVE':
        return Icons.check_circle_outline_rounded;
      case 'REJECT':
        return Icons.cancel_outlined;
      case 'CREATE':
        return Icons.add_circle_outline_rounded;
      case 'UPDATE':
      case 'STATUS_CHANGE':
        return Icons.edit_note_rounded;
      case 'DELETE':
        return Icons.delete_outline_rounded;
      case 'LOGIN':
        return Icons.login_rounded;
      case 'EXPORT':
        return Icons.file_download_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  Color _getModuleColor(String module) {
    switch (module.toLowerCase()) {
      case 'reschedule':
        return const Color(0xFF7C3AED); // Vibrant Purple
      case 'reservations':
        return const Color(0xFF14332E); // Deep Forest Green
      case 'payments':
        return const Color(0xFF0D9488); // Teal
      case 'refunds':
        return const Color(0xFFE11D48); // Rose
      case 'petty cash':
        return const Color(0xFFD9A441); // Warm Gold
      case 'menu':
        return const Color(0xFFEA580C); // Orange
      case 'spoilage':
        return const Color(0xFFDC2626); // Red
      case 'users':
        return const Color(0xFF0284C7); // Sky Blue
      case 'announcements':
        return const Color(0xFF6366F1); // Indigo
      case 'system':
      case 'auth':
      default:
        return const Color(0xFF475569); // Slate
    }
  }

  IconData _getModuleIcon(String module) {
    switch (module.toLowerCase()) {
      case 'reschedule':
        return Icons.edit_calendar_rounded;
      case 'reservations':
        return Icons.calendar_month_rounded;
      case 'payments':
        return Icons.payments_outlined;
      case 'refunds':
        return Icons.currency_exchange_rounded;
      case 'petty cash':
        return Icons.account_balance_wallet_outlined;
      case 'menu':
        return Icons.restaurant_menu_rounded;
      case 'spoilage':
        return Icons.delete_sweep_rounded;
      case 'users':
        return Icons.people_alt_outlined;
      case 'announcements':
        return Icons.campaign_outlined;
      case 'system':
      case 'auth':
      default:
        return Icons.shield_outlined;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return const Color(0xFF14332E);
      case 'CHEF':
        return const Color(0xFFD97706);
      case 'STAFF':
      default:
        return const Color(0xFF0284C7);
    }
  }

  Widget _buildRolePill(String role) {
    final isRoleAdmin = role.toUpperCase() == 'ADMIN';
    final isRoleChef = role.toUpperCase() == 'CHEF';

    final Color bgColor = isRoleAdmin
        ? const Color(0xFF14332E).withValues(alpha: 0.12)
        : (isRoleChef ? const Color(0xFFD97706).withValues(alpha: 0.12) : const Color(0xFF0284C7).withValues(alpha: 0.12));

    final Color textColor = isRoleAdmin
        ? const Color(0xFF14332E)
        : (isRoleChef ? const Color(0xFFB45309) : const Color(0xFF0284C7));

    final IconData icon = isRoleAdmin
        ? Icons.admin_panel_settings_rounded
        : (isRoleChef ? Icons.local_fire_department_rounded : Icons.badge_outlined);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Formats raw description texts by highlighting entity IDs and scheduling details cleanly
  Widget _buildFormattedDescription(String desc, AuditLog log) {
    // Check if description has UUID pattern and clean it up for elegance
    final uuidRegex = RegExp(r'#([a-f0-9\-]{36})');
    String displayDesc = desc;

    final match = uuidRegex.firstMatch(desc);
    String? shortCode;
    if (match != null) {
      final fullUuid = match.group(1)!;
      shortCode = '#${fullUuid.substring(0, 8).toUpperCase()}';
      displayDesc = desc.replaceFirst('#$fullUuid', shortCode);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayDesc,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (log.metadata.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (log.metadata['new_date'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '📅 ${log.metadata['new_date']} ${log.metadata['new_time'] ?? ''}',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED)),
                    ),
                  ),
                if (log.metadata['refund_amount'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '₱${(log.metadata['refund_amount'] as num).toStringAsFixed(2)}',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                    ),
                  ),
                if (log.metadata['staff_on_duty'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      'Cook: ${log.metadata['staff_on_duty']}',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    // Calculate metrics
    final totalLogs = _logs.length;
    final now = DateTime.now();
    final todayLogs = _logs.where((l) =>
      l.createdAt.year == now.year &&
      l.createdAt.month == now.month &&
      l.createdAt.day == now.day
    ).length;

    final criticalCount = _logs.where((l) =>
      l.action == 'APPROVE' || l.action == 'REJECT' || l.action == 'DELETE' || l.module == 'Refunds' || l.module == 'Reschedule'
    ).length;

    final uniqueUsers = _logs.map((l) => l.userEmail).toSet().length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            _buildHeader(isDesktop),
            const SizedBox(height: 14),

            // Top Metric Summary Cards
            _buildMetricCards(
              totalLogs: totalLogs,
              todayLogs: todayLogs,
              criticalCount: criticalCount,
              uniqueUsers: uniqueUsers,
              isDesktop: isDesktop,
            ),
            const SizedBox(height: 14),

            // Compact Filter & Search Toolbar
            _buildFilterCard(isDesktop),
            const SizedBox(height: 14),

            // Main Content Area: Table / Timeline
            if (_isLoading)
              Container(
                height: 380,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.forestGreen, strokeWidth: 2.5),
                      SizedBox(height: 16),
                      Text('Syncing security audit trail from Supabase...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(color: AppTheme.errorRed, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadLogs,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.forestGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_logs.isEmpty)
              Container(
                height: 320,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.manage_search_rounded, size: 48, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No audit records found matching your filters',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try switching modules or resetting search criteria',
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedModule = 'All Modules';
                            _selectedAction = 'All Actions';
                            _selectedDateRange = 'All Time';
                            _searchController.clear();
                          });
                          _loadLogs();
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Reset All Filters'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_viewMode == 'timeline')
              _buildTimelineView(isDesktop)
            else
              _buildTableCard(isDesktop),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ── Header Component ──────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2621), Color(0xFF14332E), Color(0xFF1B433C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14332E).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppTheme.warmGold,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Audit Trail & Security Logs',
                      style: GoogleFonts.inter(
                        fontSize: isDesktop ? 20 : 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'LIVE AUDIT',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6EE7B7),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Immutable timeline of administrative, financial, staff, and kitchen operations',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            // View Mode Toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.table_rows_rounded, color: _viewMode == 'table' ? AppTheme.warmGold : Colors.white70, size: 20),
                    tooltip: 'Table Grid View',
                    onPressed: () => setState(() => _viewMode = 'table'),
                  ),
                  IconButton(
                    icon: Icon(Icons.timeline_rounded, color: _viewMode == 'timeline' ? AppTheme.warmGold : Colors.white70, size: 20),
                    tooltip: 'Security Timeline View',
                    onPressed: () => setState(() => _viewMode = 'timeline'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Refresh Button
            Tooltip(
              message: 'Refresh Logs',
              child: InkWell(
                onTap: _loadLogs,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Export CSV Button
            ElevatedButton.icon(
              onPressed: _exportLogsToCSV,
              icon: const Icon(Icons.download_rounded, size: 17),
              label: Text('Export CSV', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warmGold,
                foregroundColor: const Color(0xFF14332E),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Metric Cards ─────────────────────────────────────────────────────────────
  Widget _buildMetricCards({
    required int totalLogs,
    required int todayLogs,
    required int criticalCount,
    required int uniqueUsers,
    required bool isDesktop,
  }) {
    final List<Widget> cards = [
      _buildSingleMetricCard(
        title: 'Total Activity History',
        value: totalLogs.toString(),
        subtitle: 'Lahat ng logs (Reservations, POS, Stock, Menu, etc.)',
        icon: Icons.history_rounded,
        color: const Color(0xFF0F172A),
        badgeText: 'All-Time',
        badgeColor: const Color(0xFF0F172A),
      ),
      _buildSingleMetricCard(
        title: "Today's Operations",
        value: todayLogs.toString(),
        subtitle: 'Mga aksyon at updates na naitala ngayong araw',
        icon: Icons.electric_bolt_rounded,
        color: const Color(0xFF0284C7),
        badgeText: 'Today',
        badgeColor: const Color(0xFF0284C7),
      ),
      _buildSingleMetricCard(
        title: 'Approvals & Decisions',
        value: criticalCount.toString(),
        subtitle: 'Reschedules, payment approvals, refunds & deletes',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFFD97706),
        badgeText: 'Decisions',
        badgeColor: const Color(0xFFD97706),
      ),
      _buildSingleMetricCard(
        title: 'Active Staff & Admins',
        value: uniqueUsers.toString(),
        subtitle: 'Mga admin, cashier at staff na nag-process',
        icon: Icons.manage_accounts_rounded,
        color: const Color(0xFF7C3AED),
        badgeText: 'Operators',
        badgeColor: const Color(0xFF7C3AED),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
      );
    } else {
      return Column(
        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)).toList(),
      );
    }
  }

  Widget _buildSingleMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Sleek Compact Unified Filter Toolbar ──────────────────────────────────────
  Widget _buildFilterCard(bool isDesktop) {
    final hasActiveFilters = _selectedModule != 'All Modules' ||
        _selectedDateRange != 'All Time' ||
        _searchController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              children: [
                // Compact Search Field
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => _loadLogs(),
                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Search by operator, action, description...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadLogs();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF14332E), width: 1.2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Compact Module Dropdown
                _buildCompactDropdown(
                  icon: Icons.layers_outlined,
                  value: _selectedModule,
                  items: _moduleOptions,
                  width: 170,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedModule = val);
                      _loadLogs();
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Compact Date Range Dropdown
                _buildCompactDropdown(
                  icon: Icons.calendar_today_outlined,
                  value: _selectedDateRange,
                  items: _dateOptions,
                  width: 150,
                  onChanged: (val) async {
                    if (val == 'Custom Range') {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _customStartDate = picked.start;
                          _customEndDate = picked.end;
                          _selectedDateRange = val!;
                        });
                        _loadLogs();
                      }
                    } else if (val != null) {
                      setState(() => _selectedDateRange = val);
                      _loadLogs();
                    }
                  },
                ),

                if (hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Clear all active filters',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedModule = 'All Modules';
                          _selectedAction = 'All Actions';
                          _selectedDateRange = 'All Time';
                          _searchController.clear();
                        });
                        _loadLogs();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_alt_off_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text('Reset', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            )
          : Column(
              children: [
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _loadLogs(),
                    style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search logs, users, IDs...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactDropdown(
                        icon: Icons.layers_outlined,
                        value: _selectedModule,
                        items: _moduleOptions,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedModule = val);
                            _loadLogs();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildCompactDropdown(
                        icon: Icons.calendar_today_outlined,
                        value: _selectedDateRange,
                        items: _dateOptions,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedDateRange = val);
                            _loadLogs();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildCompactDropdown({
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double? width,
  }) {
    final widgetChild = Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: widgetChild);
    }
    return widgetChild;
  }

  // ── Main Table Card ──────────────────────────────────────────────────────────
  Widget _buildTableCard(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: const Color(0xFFF1F5F9),
              child: Row(
                children: [
                  _buildHeaderCell('TIMESTAMP', flex: 2),
                  _buildHeaderCell('USER & OPERATOR', flex: 3),
                  _buildHeaderCell('MODULE', flex: 2),
                  _buildHeaderCell('ACTION', flex: 2),
                  _buildHeaderCell('DESCRIPTION', flex: 5),
                  _buildHeaderCell('INSPECT', flex: 1, alignment: Alignment.centerRight),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Table Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _logs.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final log = _logs[index];
                final formattedDate = DateFormat('MMM dd, yyyy').format(log.createdAt);
                final formattedTime = DateFormat('hh:mm:ss a').format(log.createdAt);
                final moduleColor = _getModuleColor(log.module);

                return InkWell(
                  onTap: () => _showLogDetailsDialog(log),
                  hoverColor: const Color(0xFFF8FAFC),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        // Timestamp
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formattedDate,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                formattedTime,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // User & Role
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: _getRoleColor(log.userRole).withValues(alpha: 0.15),
                                child: Text(
                                  log.userName.isNotEmpty ? log.userName[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _getRoleColor(log.userRole),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.userName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    _buildRolePill(log.userRole),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Module
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: moduleColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: moduleColor.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getModuleIcon(log.module), size: 12, color: moduleColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    log.module,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: moduleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Action
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getActionColor(log.action).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _getActionColor(log.action).withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getActionIcon(log.action),
                                    size: 13,
                                    color: _getActionColor(log.action),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    log.action,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _getActionColor(log.action),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Description
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _buildFormattedDescription(log.description, log),
                          ),
                        ),

                        // Details Button
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF0284C7)),
                              tooltip: 'Inspect Payload',
                              onPressed: () => _showLogDetailsDialog(log),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Timeline Stream View Mode ────────────────────────────────────────────────
  Widget _buildTimelineView(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          final formattedDate = DateFormat('MMMM dd, yyyy • hh:mm:ss a').format(log.createdAt);
          final actionColor = _getActionColor(log.action);
          final moduleColor = _getModuleColor(log.module);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline Node Line & Dot
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: actionColor, width: 2),
                    ),
                    child: Icon(_getActionIcon(log.action), size: 16, color: actionColor),
                  ),
                  if (index < _logs.length - 1)
                    Container(
                      width: 2,
                      height: 80,
                      color: const Color(0xFFE2E8F0),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Timeline Content Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: InkWell(
                    onTap: () => _showLogDetailsDialog(log),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: moduleColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  log.module.toUpperCase(),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: moduleColor),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: actionColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  log.action,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: actionColor),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formattedDate,
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildFormattedDescription(log.description, log),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: _getRoleColor(log.userRole).withValues(alpha: 0.2),
                                child: Text(
                                  log.userName.isNotEmpty ? log.userName[0].toUpperCase() : 'U',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getRoleColor(log.userRole)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${log.userName} (${log.userEmail})',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                              ),
                              const SizedBox(width: 6),
                              _buildRolePill(log.userRole),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCell(String title, {int flex = 1, Alignment alignment = Alignment.centerLeft}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF475569),
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
