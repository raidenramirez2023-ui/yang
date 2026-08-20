import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/backup_restore_service.dart';
import '../../models/audit_log_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Table selections & live counts
  Map<String, int> _tableCounts = {};
  final Set<String> _selectedTables = {};
  bool _isLoadingCounts = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  // Staged restore file data
  Map<String, dynamic>? _stagedBackupData;
  String? _stagedFileName;
  int? _stagedFileSizeBytes;
  final Set<String> _stagedSelectedTablesToRestore = {};
  bool _isUpsertMode = true; // true = Safe Upsert, false = Overwrite

  // Recent backup & restore activity log from audit_logs
  List<AuditLog> _recentActivityLogs = [];
  bool _isLoadingActivityLogs = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    for (final t in BackupRestoreService.availableTables) {
      _selectedTables.add(t.tableName);
    }
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadTableCounts(),
      _loadRecentActivityLogs(),
    ]);
  }

  Future<void> _loadTableCounts() async {
    setState(() => _isLoadingCounts = true);
    try {
      final counts = await BackupRestoreService.getLiveTableCounts();
      if (mounted) {
        setState(() {
          _tableCounts = counts;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading table counts: $e');
      if (mounted) setState(() => _isLoadingCounts = false);
    }
  }

  Future<void> _loadRecentActivityLogs() async {
    setState(() => _isLoadingActivityLogs = true);
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('audit_logs')
          .select()
          .inFilter('action', ['BACKUP_EXPORT', 'DATABASE_RESTORE'])
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _recentActivityLogs = (res as List)
              .map((item) => AuditLog.fromJson(item as Map<String, dynamic>))
              .toList();
          _isLoadingActivityLogs = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recent activity logs: $e');
      if (mounted) setState(() => _isLoadingActivityLogs = false);
    }
  }

  int get _totalDatabaseRecords {
    return _tableCounts.values.fold(0, (a, b) => a + b);
  }

  // ─────────────────────────────────────────────────────────────
  // PRESET SELECTIONS
  // ─────────────────────────────────────────────────────────────

  void _applyPreset(String presetKey) {
    setState(() {
      _selectedTables.clear();
      switch (presetKey) {
        case 'ALL':
          _selectedTables.addAll(BackupRestoreService.availableTables.map((t) => t.tableName));
          break;
        case 'FINANCE_SALES':
          _selectedTables.addAll([
            'orders',
            'order_items',
            'reservations',
            'refunds',
            'reschedule_requests',
            'petty_cash_fund',
            'petty_cash_expenses',
          ]);
          break;
        case 'INVENTORY_KITCHEN':
          _selectedTables.addAll([
            'inventory',
            'stock_transactions',
            'recipe_ingredients',
          ]);
          break;
        case 'MENU_CATALOG':
          _selectedTables.addAll([
            'menu_items',
            'recipe_ingredients',
            'announcements',
            'reviews',
          ]);
          break;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // BACKUP ACTIONS
  // ─────────────────────────────────────────────────────────────

  Future<void> _performBackup({bool full = true}) async {
    final tablesToExport = full
        ? BackupRestoreService.availableTables.map((t) => t.tableName).toList()
        : _selectedTables.toList();

    if (tablesToExport.isEmpty) {
      _showSnackBar('Please select at least one table to back up.', isError: true);
      return;
    }

    setState(() => _isBackingUp = true);

    String progressMessage = 'Preparing backup snapshot...';
    double progressPercent = 0.0;

    // Show Progress Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: AppTheme.white,
            title: Row(
              children: [
                const Icon(Icons.cloud_download_rounded, color: AppTheme.warmGold, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Generating System Snapshot',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progressMessage,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: AppTheme.mediumGrey),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressPercent > 0 ? progressPercent : null,
                    backgroundColor: AppTheme.lightGrey,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.forestGreen),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final backupData = await BackupRestoreService.generateBackupData(
        selectedTableNames: tablesToExport,
        onProgress: (msg, prog) {
          progressMessage = msg;
          progressPercent = prog;
        },
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      final savedPath = await BackupRestoreService.saveBackupToFile(backupData);

      if (savedPath != null && mounted) {
        final totalExported = (backupData['record_counts'] as Map<String, dynamic>).values.fold<int>(0, (a, b) => a + (b as int));
        _showSnackBar(
          'Backup exported successfully! ($totalExported records in ${tablesToExport.length} tables)',
          isSuccess: true,
        );
        _loadRecentActivityLogs();
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showSnackBar('Backup failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RESTORE ACTIONS
  // ─────────────────────────────────────────────────────────────

  Future<void> _pickAndStageBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        _showSnackBar('Failed to read file content.', isError: true);
        return;
      }

      final parsedData = BackupRestoreService.validateBackupData(bytes);

      setState(() {
        _stagedBackupData = parsedData;
        _stagedFileName = file.name;
        _stagedFileSizeBytes = file.size;
        _stagedSelectedTablesToRestore.clear();

        final dataMap = parsedData['data'] as Map<String, dynamic>? ?? {};
        _stagedSelectedTablesToRestore.addAll(dataMap.keys);
      });

      _showSnackBar('Backup file verified: ${file.name}', isSuccess: true);
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    }
  }

  void _promptRestoreConfirmation() {
    if (_stagedBackupData == null || _stagedSelectedTablesToRestore.isEmpty) {
      _showSnackBar('Please select at least one table to restore.', isError: true);
      return;
    }

    final confirmController = TextEditingController();
    bool isTypedCorrectly = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isMobile = MediaQuery.of(context).size.width < 600;
          return AlertDialog(
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: AppTheme.white,
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
                const SizedBox(width: 10),
                Text(
                  'Confirm Database Restore',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isUpsertMode
                                ? 'Safe Upsert Mode: Updates matching records and inserts new rows. Existing non-conflicting records will remain intact.'
                                : 'Overwrite Mode: Replaces table records with backup data. Use with caution.',
                            style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF991B1B), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You are about to restore ${_stagedSelectedTablesToRestore.length} table(s) from "${_stagedFileName ?? 'backup'}".',
                    style: GoogleFonts.outfit(fontSize: 13.5, color: AppTheme.darkGrey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type "RESTORE" below to confirm execution:',
                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.mediumGrey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Type RESTORE in capital letters',
                      hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        isTypedCorrectly = val.trim() == 'RESTORE';
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.mediumGrey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTypedCorrectly ? const Color(0xFFDC2626) : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: isTypedCorrectly
                    ? () {
                        Navigator.pop(ctx);
                        _executeRestore();
                      }
                    : null,
                child: Text('Confirm & Restore', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeRestore() async {
    if (_stagedBackupData == null) return;

    setState(() => _isRestoring = true);

    String progressMessage = 'Starting restore...';
    double progressPercent = 0.0;

    // Show Progress Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: AppTheme.white,
            title: Row(
              children: [
                const Icon(Icons.settings_backup_restore_rounded, color: AppTheme.forestGreen, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Restoring Database...',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progressMessage,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.mediumGrey),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressPercent > 0 ? progressPercent : null,
                    backgroundColor: AppTheme.lightGrey,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.forestGreen),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final summary = await BackupRestoreService.executeRestore(
        backupData: _stagedBackupData!,
        selectedTablesToRestore: _stagedSelectedTablesToRestore.toList(),
        isUpsertMode: _isUpsertMode,
        onProgress: (msg, prog) {
          progressMessage = msg;
          progressPercent = prog;
        },
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      await Future.wait([
        _loadTableCounts(),
        _loadRecentActivityLogs(),
      ]);

      _showRestoreSummaryDialog(summary);
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showSnackBar('Restore execution failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  void _showRestoreSummaryDialog(RestoreSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isMobile = MediaQuery.of(ctx).size.width < 600;
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppTheme.white,
          title: Row(
            children: [
              Icon(
                summary.isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: summary.isSuccess ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary.isSuccess ? 'Restore Completed' : 'Restore Finished with Errors',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.message,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.darkGrey),
                ),
              const SizedBox(height: 16),
              Text(
                'Restored Records Breakdown:',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.forestGreen),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  children: summary.restoredCounts.entries.map((e) {
                    final config = BackupRestoreService.availableTables.firstWhere(
                      (t) => t.tableName == e.key,
                      orElse: () => TableBackupConfig(tableName: e.key, displayName: e.key, description: '', category: ''),
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(config.displayName, style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.darkGrey)),
                          Text(
                            '${e.value} records',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.forestGreen),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (summary.errors.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Errors encountered (${summary.errors.length}):',
                  style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                ),
                const SizedBox(height: 4),
                ...summary.errors.take(3).map(
                      (err) => Text('• $err', style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.red.shade700)),
                    ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.forestGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );
}

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : (isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded),
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : (isSuccess ? const Color(0xFF15803D) : AppTheme.forestGreen),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // UI BUILDERS
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.adminMainBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 16,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDesktop),
              const SizedBox(height: 20),
              _buildStatsRow(isDesktop),
              const SizedBox(height: 20),
              _buildUserInstructionCard(),
              const SizedBox(height: 24),
              _buildTabSection(isDesktop),
              const SizedBox(height: 24),
              _buildRecentActivitySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.forestGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.settings_backup_restore_rounded, color: AppTheme.forestGreen, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Database Backup & Recovery',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.adminPrimaryText,
                      ),
                    ),
                    Text(
                      'System snapshots & disaster recovery',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.adminSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoadingCounts ? null : _loadInitialData,
              icon: _isLoadingCounts
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Sync Live Status', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.forestGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Database Backup & Disaster Recovery',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.adminPrimaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Generate secure snapshots of system records, manage JSON backups, and safely restore data.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppTheme.adminSecondaryText,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isLoadingCounts ? null : _loadInitialData,
          icon: _isLoadingCounts
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.refresh_rounded, size: 18),
          label: Text('Sync Live Status', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.forestGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isDesktop) {
    final totalTables = BackupRestoreService.availableTables.length;
    final totalRecords = _totalDatabaseRecords;

    final cards = [
      _buildStatCard(
        title: 'Monitored Tables',
        value: '$totalTables Tables',
        subtitle: 'Core, Sales, Inventory, Finance',
        icon: Icons.table_chart_rounded,
        color: const Color(0xFF2563EB),
      ),
      _buildStatCard(
        title: 'Total Live Records',
        value: _isLoadingCounts ? 'Loading...' : NumberFormat('#,###').format(totalRecords),
        subtitle: 'Stored across all entities',
        icon: Icons.storage_rounded,
        color: AppTheme.forestGreen,
      ),
      _buildStatCard(
        title: 'Backup Format',
        value: 'JSON Snapshot',
        subtitle: 'Machine-readable & Relational',
        icon: Icons.code_rounded,
        color: AppTheme.warmGold,
      ),
      _buildStatCard(
        title: 'Disaster Recovery',
        value: 'Online & Ready',
        subtitle: 'Safe Upsert & Clean Overwrite',
        icon: Icons.shield_rounded,
        color: const Color(0xFF15803D),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
      );
    } else {
      return SizedBox(
        height: 76,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: cards
              .map((c) => Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 8),
                    child: c,
                  ))
              .toList(),
        ),
      );
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.mediumGrey, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkGrey)),
                Text(subtitle, style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF15803D).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.help_outline_rounded, color: Color(0xFF15803D), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paano Gamitin ang Backup & Restore (User Guide)',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF166534),
                      ),
                    ),
                    Text(
                      'Gabay para sa ligtas na pag-save at pagbawi ng inyong records sakaling magkaroon ng aberya.',
                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF14532D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFBBF7D0), height: 1),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 650;
              final steps = [
                _buildInstructionStep(
                  stepNum: '1',
                  title: 'Pag-save ng Kopya (Backup):',
                  desc: 'Piliin ang "Full Backup (.JSON)" para sa buong database, o pumili ng specific tables gamit ang checkboxes sa ibaba (Export Selected). Itabi ang file sa ligtas na lugar.',
                  icon: Icons.cloud_download_outlined,
                ),
                _buildInstructionStep(
                  stepNum: '2',
                  title: 'Pagbalik ng Data (Restore):',
                  desc: 'Pumunta sa tab na "Restore From Backup" at i-upload ang iyong na-download na `.json` file.',
                  icon: Icons.folder_open_rounded,
                ),
                _buildInstructionStep(
                  stepNum: '3',
                  title: 'Ligtas na Pag-sync:',
                  desc: 'Piliin ang "Safe Upsert (Recommended)" at i-type ang RESTORE para maibalik ang data nang walang mabuburang bago.',
                  icon: Icons.shield_outlined,
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: steps.map((s) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: s))).toList(),
                );
              } else {
                return Column(
                  children: steps.map((s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: s)).toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep({
    required String stepNum,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: const Color(0xFF15803D),
                child: Text(
                  stepNum,
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF374151), height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.forestGreen,
            unselectedLabelColor: AppTheme.mediumGrey,
            indicatorColor: AppTheme.warmGold,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(
                icon: Icon(Icons.file_download_outlined, size: 20),
                text: 'Create System Backup',
              ),
              Tab(
                icon: Icon(Icons.settings_backup_restore_rounded, size: 20),
                text: 'Restore From Backup',
              ),
            ],
          ),
          const Divider(height: 1, color: AppTheme.cardBorder),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: 760,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBackupTabContent(isDesktop),
                  _buildRestoreTabContent(isDesktop),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: BACKUP VIEW
  // ─────────────────────────────────────────────────────────────

  Widget _buildBackupTabContent(bool isDesktop) {
    return ListView(
      children: [
        // Quick Action Banner
        Container(
          padding: EdgeInsets.all(isDesktop ? 20 : 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF14332E), Color(0xFF1E4A42)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14332E).withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isDesktop
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cloud_download_rounded, color: AppTheme.warmGold, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'One-Click Full Database Snapshot',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.warmGold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.5)),
                                ),
                                child: Text('RECOMMENDED', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.warmGold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Exports all ${BackupRestoreService.availableTables.length} system tables ($_totalDatabaseRecords live records) into a verified, timestamped JSON package.',
                            style: GoogleFonts.outfit(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isBackingUp ? null : () => _performBackup(full: true),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text('Full Backup (.JSON)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warmGold,
                        foregroundColor: AppTheme.darkBrownText,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.cloud_download_rounded, color: AppTheme.warmGold, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Full Database Snapshot',
                                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.warmGold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.warmGold.withValues(alpha: 0.5)),
                                ),
                                child: Text('REC', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.warmGold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Exports all ${BackupRestoreService.availableTables.length} tables ($_totalDatabaseRecords records) into a timestamped JSON package.',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isBackingUp ? null : () => _performBackup(full: true),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: Text('Full Backup (.JSON)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.warmGold,
                          foregroundColor: AppTheme.darkBrownText,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 18),

        // Quick Preset Profiles Filter Bar (Horizontal Scrollable)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              Text('Presets: ', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.mediumGrey)),
              const SizedBox(width: 6),
              _buildPresetChip('All Tables', 'ALL'),
              const SizedBox(width: 6),
              _buildPresetChip('Finance & Sales', 'FINANCE_SALES'),
              const SizedBox(width: 6),
              _buildPresetChip('Inventory & Kitchen', 'INVENTORY_KITCHEN'),
              const SizedBox(width: 6),
              _buildPresetChip('Menu & Catalog', 'MENU_CATALOG'),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Custom Selection Section Header
        isDesktop
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Selective Backup',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                      ),
                      Text(
                        'Select specific modules to include in the backup payload (${_selectedTables.length} of ${BackupRestoreService.availableTables.length} tables selected)',
                        style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.mediumGrey),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedTables.addAll(BackupRestoreService.availableTables.map((t) => t.tableName));
                          });
                        },
                        child: Text('Select All', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.forestGreen)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedTables.clear();
                          });
                        },
                        child: Text('Clear All', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.mediumGrey)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isBackingUp || _selectedTables.isEmpty ? null : () => _performBackup(full: false),
                        icon: const Icon(Icons.save_alt_rounded, size: 18),
                        label: Text('Export Selected (${_selectedTables.length})', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.forestGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Selective Backup',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                  ),
                  Text(
                    '${_selectedTables.length} of ${BackupRestoreService.availableTables.length} tables selected',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.mediumGrey),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTables.addAll(BackupRestoreService.availableTables.map((t) => t.tableName));
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: AppTheme.forestGreen),
                        ),
                        child: Text('Select All', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.forestGreen)),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTables.clear();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: AppTheme.cardBorder),
                        ),
                        child: Text('Clear All', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mediumGrey)),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isBackingUp || _selectedTables.isEmpty ? null : () => _performBackup(full: false),
                        icon: const Icon(Icons.save_alt_rounded, size: 15),
                        label: Text('Export (${_selectedTables.length})', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.forestGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

        const SizedBox(height: 16),

        // Table Checkboxes Grid
        _buildTableCardsGrid(),
      ],
    );
  }

  Widget _buildPresetChip(String label, String presetKey) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.lightGrey,
      side: const BorderSide(color: AppTheme.cardBorder),
      onPressed: () => _applyPreset(presetKey),
    );
  }

  Widget _buildTableCardsGrid() {
    final categories = [
      {'key': 'Core', 'label': 'CORE DATA', 'icon': Icons.dns_rounded},
      {'key': 'Operations', 'label': 'OPERATIONS & SALES', 'icon': Icons.storefront_rounded},
      {'key': 'Inventory', 'label': 'LOGISTICS & INVENTORY', 'icon': Icons.inventory_2_rounded},
      {'key': 'Financial', 'label': 'FINANCE & PETTY CASH', 'icon': Icons.account_balance_wallet_rounded},
      {'key': 'Logs', 'label': 'AUDIT TRAIL & LOGS', 'icon': Icons.security_rounded},
    ];

    return Column(
      children: categories.map((cat) {
        final catKey = cat['key'] as String;
        final catLabel = cat['label'] as String;
        final catIcon = cat['icon'] as IconData;
        final tablesInCat = BackupRestoreService.availableTables.where((t) => t.category == catKey).toList();
        if (tablesInCat.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(catIcon, size: 16, color: AppTheme.warmGold),
                  const SizedBox(width: 6),
                  Text(
                    catLabel,
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.warmGold, letterSpacing: 1.1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Divider(color: Colors.grey.shade200, height: 1)),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380,
                mainAxisExtent: 96,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: tablesInCat.length,
              itemBuilder: (context, index) {
                final table = tablesInCat[index];
                final isSelected = _selectedTables.contains(table.tableName);
                final rowCount = _tableCounts[table.tableName] ?? 0;

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTables.remove(table.tableName);
                      } else {
                        _selectedTables.add(table.tableName);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF0FDF4) : AppTheme.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF86EFAC) : AppTheme.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          activeColor: AppTheme.forestGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedTables.add(table.tableName);
                              } else {
                                _selectedTables.remove(table.tableName);
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                table.displayName,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                table.description,
                                style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.mediumGrey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.forestGreen.withValues(alpha: 0.1) : AppTheme.lightGrey,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isLoadingCounts ? '...' : NumberFormat('#,###').format(rowCount),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.forestGreen : AppTheme.mediumGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: RESTORE VIEW
  // ─────────────────────────────────────────────────────────────

  Widget _buildRestoreTabContent(bool isDesktop) {
    if (_stagedBackupData == null) {
      return Center(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.forestGreen.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_outlined, size: 50, color: AppTheme.forestGreen),
              ),
              const SizedBox(height: 20),
              Text(
                'Upload System Backup (.JSON)',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
              ),
              const SizedBox(height: 6),
              Text(
                'Select a previously generated Yang Chow backup file to inspect schema and execute safe restoration.',
                style: GoogleFonts.outfit(fontSize: 13.5, color: AppTheme.mediumGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickAndStageBackupFile,
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: Text('Browse JSON Backup File', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.forestGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Supported: .json files generated by Yang Chow Backup Engine',
                style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      );
    }

    final metadata = _stagedBackupData!;
    final createdAt = metadata['created_at'] != null ? DateTime.tryParse(metadata['created_at']) : null;
    final createdBy = metadata['created_by'] ?? 'Unknown Admin';
    final dataMap = metadata['data'] as Map<String, dynamic>? ?? {};
    final totalRowsInFile = dataMap.values.fold<int>(0, (sum, val) => sum + (val is List ? val.length : 0));
    final fileSizeKb = _stagedFileSizeBytes != null ? (_stagedFileSizeBytes! / 1024).toStringAsFixed(1) : 'N/A';

    return ListView(
      children: [
        // Loaded File Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _stagedFileName ?? "backup.json",
                          style: GoogleFonts.outfit(fontSize: 15.5, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBBF7D0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('$fileSizeKb KB', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBBF7D0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('$totalRowsInFile Records', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created: ${createdAt != null ? DateFormat("MMM dd, yyyy • hh:mm:ss a").format(createdAt.toLocal()) : "N/A"} by $createdBy',
                      style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF14532D)),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _pickAndStageBackupFile,
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text('Change File', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF15803D)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Restore Mode Selection
        Text(
          'Select Restoration Mode',
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
        ),
        const SizedBox(height: 10),
        isDesktop
            ? Row(
                children: [
                  Expanded(child: _buildUpsertModeCard()),
                  const SizedBox(width: 14),
                  Expanded(child: _buildOverwriteModeCard()),
                ],
              )
            : Column(
                children: [
                  _buildUpsertModeCard(),
                  const SizedBox(height: 10),
                  _buildOverwriteModeCard(),
                ],
              ),

        const SizedBox(height: 24),

        // Tables to Restore Selection
        isDesktop
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Tables to Restore (${_stagedSelectedTablesToRestore.length} of ${dataMap.keys.length} selected)',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _stagedSelectedTablesToRestore.addAll(dataMap.keys);
                          });
                        },
                        child: Text('Select All', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.forestGreen)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _stagedSelectedTablesToRestore.clear();
                          });
                        },
                        child: Text('Clear All', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.mediumGrey)),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tables to Restore (${_stagedSelectedTablesToRestore.length}/${dataMap.keys.length})',
                    style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _stagedSelectedTablesToRestore.addAll(dataMap.keys);
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: AppTheme.forestGreen),
                        ),
                        child: Text('Select All', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.forestGreen)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _stagedSelectedTablesToRestore.clear();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: AppTheme.cardBorder),
                        ),
                        child: Text('Clear All', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.mediumGrey)),
                      ),
                    ],
                  ),
                ],
              ),

        const SizedBox(height: 12),

        // Table List in Backup
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            children: dataMap.entries.map((entry) {
              final tableName = entry.key;
              final rowList = entry.value is List ? entry.value as List : [];
              final isSelected = _stagedSelectedTablesToRestore.contains(tableName);
              final config = BackupRestoreService.availableTables.firstWhere(
                (t) => t.tableName == tableName,
                orElse: () => TableBackupConfig(
                  tableName: tableName,
                  displayName: tableName,
                  description: 'Custom table',
                  category: 'Custom',
                ),
              );

              return Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  activeColor: AppTheme.forestGreen,
                  title: Text(config.displayName, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: Text(config.description, style: GoogleFonts.outfit(fontSize: 11.5, color: AppTheme.mediumGrey)),
                  secondary: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGrey,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${rowList.length} rows',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _stagedSelectedTablesToRestore.add(tableName);
                      } else {
                        _stagedSelectedTablesToRestore.remove(tableName);
                      }
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 24),

        // Restore Trigger Button
        isDesktop
            ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _stagedBackupData = null;
                        _stagedFileName = null;
                        _stagedFileSizeBytes = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.mediumGrey,
                      side: const BorderSide(color: AppTheme.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    onPressed: _isRestoring || _stagedSelectedTablesToRestore.isEmpty ? null : _promptRestoreConfirmation,
                    icon: const Icon(Icons.restore_page_rounded, size: 18),
                    label: Text(
                      'Proceed with Restore (${_stagedSelectedTablesToRestore.length} tables)',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isRestoring || _stagedSelectedTablesToRestore.isEmpty ? null : _promptRestoreConfirmation,
                      icon: const Icon(Icons.restore_page_rounded, size: 18),
                      label: Text(
                        'Proceed with Restore (${_stagedSelectedTablesToRestore.length} tables)',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _stagedBackupData = null;
                          _stagedFileName = null;
                          _stagedFileSizeBytes = null;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.mediumGrey,
                        side: const BorderSide(color: AppTheme.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: Text('Cancel Staging', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildUpsertModeCard() {
    return InkWell(
      onTap: () => setState(() => _isUpsertMode = true),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isUpsertMode ? const Color(0xFFF0FDF4) : AppTheme.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isUpsertMode ? const Color(0xFF15803D) : AppTheme.cardBorder,
            width: _isUpsertMode ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isUpsertMode ? const Color(0xFF15803D) : Colors.transparent,
                border: Border.all(
                  color: _isUpsertMode ? const Color(0xFF15803D) : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.circle,
                size: 10,
                color: _isUpsertMode ? Colors.white : Colors.transparent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safe Upsert / Merge (Recommended)',
                    style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                  ),
                  Text(
                    'Updates matching records and inserts new rows without deleting new existing data.',
                    style: GoogleFonts.outfit(fontSize: 11.5, color: AppTheme.mediumGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverwriteModeCard() {
    return InkWell(
      onTap: () => setState(() => _isUpsertMode = false),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: !_isUpsertMode ? const Color(0xFFFEF2F2) : AppTheme.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: !_isUpsertMode ? const Color(0xFFDC2626) : AppTheme.cardBorder,
            width: !_isUpsertMode ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !_isUpsertMode ? const Color(0xFFDC2626) : Colors.transparent,
                border: Border.all(
                  color: !_isUpsertMode ? const Color(0xFFDC2626) : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.circle,
                size: 10,
                color: !_isUpsertMode ? Colors.white : Colors.transparent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clean Overwrite / Replace',
                    style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                  ),
                  Text(
                    'Deletes existing records and restores exact snapshot state. Use with care.',
                    style: GoogleFonts.outfit(fontSize: 11.5, color: AppTheme.mediumGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // RECENT ACTIVITY LOGS SECTION (AUDIT TRAIL VIEW)
  // ─────────────────────────────────────────────────────────────

  Widget _buildRecentActivitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: AppTheme.forestGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Backup & Restore History',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkGrey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live Audit',
                style: GoogleFonts.outfit(fontSize: 11.5, color: AppTheme.mediumGrey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 12),
          if (_isLoadingActivityLogs)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.forestGreen),
              ),
            )
          else if (_recentActivityLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No recent backup or restore activities recorded yet.',
                  style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.mediumGrey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentActivityLogs.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 1, color: AppTheme.cardBorder),
              itemBuilder: (ctx, idx) {
                final log = _recentActivityLogs[idx];
                final isRestore = log.action == 'DATABASE_RESTORE';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isRestore ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isRestore ? Icons.restore_rounded : Icons.file_download_rounded,
                          color: isRestore ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.description,
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Operator: ${log.userName.isNotEmpty ? log.userName : log.userEmail} • ${DateFormat("MMM dd, yyyy • hh:mm a").format(log.createdAt.toLocal())}',
                              style: GoogleFonts.outfit(fontSize: 11.5, color: AppTheme.mediumGrey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isRestore
                              ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                              : const Color(0xFF15803D).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isRestore ? 'RESTORE' : 'BACKUP',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isRestore ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                          ),
                        ),
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
}
