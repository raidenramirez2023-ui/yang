import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/audit_log_model.dart';
import '../../services/audit_log_service.dart';
import 'developer_theme.dart';

class DeveloperAuditLogsPage extends StatefulWidget {
  const DeveloperAuditLogsPage({super.key});

  @override
  State<DeveloperAuditLogsPage> createState() => _DeveloperAuditLogsPageState();
}

class _DeveloperAuditLogsPageState extends State<DeveloperAuditLogsPage> {
  List<AuditLog> _logs = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filters
  final TextEditingController _searchController = TextEditingController();
  String _selectedModule = 'All Modules';
  String _selectedAction = 'All Actions';
  String _selectedDateRange = 'All Time';

  final List<String> _moduleOptions = [
    'All Modules',
    'System',
    'Maintenance',
    'Auth',
    'Security',
    'Users',
    'Reservations',
    'Payments',
    'Inventory',
    'Menu',
  ];

  final List<String> _actionOptions = [
    'All Actions',
    'LOGIN',
    'MAINTENANCE_TOGGLE',
    'SECURITY_ALERT',
    'CREATE',
    'UPDATE',
    'DELETE',
    'STATUS_CHANGE',
    'EXPORT',
  ];

  final List<String> _dateOptions = [
    'All Time',
    'Today',
    'Past 7 Days',
    'Past 30 Days',
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
      }

      final logs = await AuditLogService.fetchLogs(
        searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        module: _selectedModule == 'All Modules' ? null : _selectedModule,
        action: _selectedAction == 'All Actions' ? null : _selectedAction,
        startDate: start,
        endDate: end,
        limit: 300,
      );

      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load audit logs: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _exportCsv() {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to export')),
      );
      return;
    }
    final csv = AuditLogService.generateCsv(_logs);
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: DeveloperTheme.accentEmerald,
        content: Text('CSV audit logs copied to clipboard successfully!'),
      ),
    );
  }

  void _showLogDetailModal(AuditLog log) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: DeveloperTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: DeveloperTheme.borderSubtle),
          ),
          child: Container(
            width: 650,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: DeveloperTheme.accentIndigo.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: DeveloperTheme.accentIndigo,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('Audit Record Inspector', style: DeveloperTheme.headingMedium()),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: DeveloperTheme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Key value table
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DeveloperTheme.bgDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: DeveloperTheme.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Log ID', log.id),
                      _buildDetailRow('Timestamp (UTC)', log.createdAt.toUtc().toIso8601String()),
                      _buildDetailRow('Operator Email', log.userEmail),
                      _buildDetailRow('Operator Role', log.userRole),
                      _buildDetailRow('Action', log.action),
                      _buildDetailRow('Target Module', log.module),
                      if (log.entityId != null) _buildDetailRow('Entity ID', log.entityId!),
                      _buildDetailRow('Description', log.description),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Text('Metadata Payload', style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
                const SizedBox(height: 6),

                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DeveloperTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DeveloperTheme.borderSubtle),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(log.metadata),
                      style: DeveloperTheme.monoText(
                        fontSize: 12,
                        color: DeveloperTheme.accentCyan,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DeveloperTheme.bgCardHover,
                      foregroundColor: DeveloperTheme.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: DeveloperTheme.monoText(
                fontSize: 12,
                color: DeveloperTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'MAINTENANCE_TOGGLE':
        return DeveloperTheme.accentAmber;
      case 'SECURITY_ALERT':
        return DeveloperTheme.accentRose;
      case 'DELETE':
        return DeveloperTheme.accentRose;
      case 'CREATE':
        return DeveloperTheme.accentEmerald;
      case 'UPDATE':
        return DeveloperTheme.accentCyan;
      case 'LOGIN':
        return DeveloperTheme.accentIndigo;
      default:
        return DeveloperTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  Text('Technical Audit Trail', style: DeveloperTheme.headingLarge()),
                  const SizedBox(height: 4),
                  Text(
                    'Immutable logging of technical events, administrative operations, and security triggers',
                    style: DeveloperTheme.bodySmall(),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DeveloperTheme.textPrimary,
                      side: const BorderSide(color: DeveloperTheme.borderSubtle),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _loadLogs,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DeveloperTheme.accentIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Filters Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: DeveloperTheme.cardDecoration(),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Search Input
                SizedBox(
                  width: 260,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadLogs(),
                    style: GoogleFonts.inter(fontSize: 13, color: DeveloperTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search email, action, text...',
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

                // Module Filter
                _buildDropdown(
                  value: _selectedModule,
                  items: _moduleOptions,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedModule = val);
                      _loadLogs();
                    }
                  },
                ),

                // Action Filter
                _buildDropdown(
                  value: _selectedAction,
                  items: _actionOptions,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedAction = val);
                      _loadLogs();
                    }
                  },
                ),

                // Date Filter
                _buildDropdown(
                  value: _selectedDateRange,
                  items: _dateOptions,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedDateRange = val);
                      _loadLogs();
                    }
                  },
                ),

                Text(
                  '${_logs.length} entries found',
                  style: DeveloperTheme.monoText(fontSize: 12, color: DeveloperTheme.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Logs Table / List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: DeveloperTheme.accentIndigo),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(color: DeveloperTheme.accentRose),
                        ),
                      )
                    : _logs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inbox_rounded, size: 48, color: DeveloperTheme.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'No audit records found matching criteria',
                                  style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: DeveloperTheme.cardDecoration(),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ListView.separated(
                                itemCount: _logs.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: DeveloperTheme.borderSubtle,
                                ),
                                itemBuilder: (context, index) {
                                  final log = _logs[index];
                                  final actionColor = _getActionColor(log.action);
                                  return InkWell(
                                    onTap: () => _showLogDetailModal(log),
                                    hoverColor: DeveloperTheme.bgCardHover,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          // Action Badge
                                          Container(
                                            width: 140,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: actionColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: actionColor.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              log.action,
                                              textAlign: TextAlign.center,
                                              style: DeveloperTheme.monoText(
                                                fontSize: 11,
                                                color: actionColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // Module Chip
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: DeveloperTheme.bgDark,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: DeveloperTheme.borderSubtle),
                                            ),
                                            child: Text(
                                              log.module,
                                              style: DeveloperTheme.monoText(
                                                fontSize: 10,
                                                color: DeveloperTheme.textSecondary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),

                                          // Description & User
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  log.description,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: DeveloperTheme.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'By: ${log.userEmail} (${log.userRole})',
                                                  style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Time
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                DateFormat('yyyy-MM-dd').format(log.createdAt),
                                                style: DeveloperTheme.monoText(
                                                  fontSize: 11,
                                                  color: DeveloperTheme.textSecondary,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('HH:mm:ss').format(log.createdAt),
                                                style: DeveloperTheme.monoText(
                                                  fontSize: 11,
                                                  color: DeveloperTheme.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.chevron_right_rounded,
                                              size: 18, color: DeveloperTheme.textMuted),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: DeveloperTheme.bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DeveloperTheme.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: DeveloperTheme.bgCard,
          icon: const Icon(Icons.arrow_drop_down, color: DeveloperTheme.textSecondary, size: 20),
          style: DeveloperTheme.bodySmall(color: DeveloperTheme.textPrimary),
          items: items.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(opt),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
