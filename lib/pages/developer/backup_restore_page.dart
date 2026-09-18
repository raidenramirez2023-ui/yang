import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/backup_restore_service.dart';
import 'developer_theme.dart';

/// Full-featured Backup & Restore tab for the Developer Console.
/// Features:
///   1. Selective Table Export — pick which tables to include in the JSON export.
///   2. Import / Restore      — upload a backup JSON and restore with Merge or Overwrite.
///   3. Backup History Log    — shows last 20 BACKUP_EXPORT / DATABASE_RESTORE audit events.
class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  // ─── Table Counts ─────────────────────────────────────────────
  Map<String, int> _tableCounts = {};
  bool _loadingCounts = false;

  // ─── Selective Export ──────────────────────────────────────────
  late Set<String> _selectedExportTables;
  bool _isExporting = false;
  String? _exportStatus;
  bool _exportIsError = false;

  // ─── Import / Restore ──────────────────────────────────────────
  Map<String, dynamic>? _parsedBackup;
  String? _backupFileLabel;
  Set<String> _selectedRestoreTables = {};
  bool _isUpsertMode = true;
  bool _isRestoring = false;
  String _restoreProgressMsg = '';
  RestoreSummary? _restoreResult;

  // ─── Backup History ────────────────────────────────────────────
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _selectedExportTables =
        BackupRestoreService.availableTables.map((t) => t.tableName).toSet();
    _loadTableCounts();
    _loadHistory();
  }

  // ─── Data Loaders ─────────────────────────────────────────────

  Future<void> _loadTableCounts() async {
    setState(() => _loadingCounts = true);
    try {
      final counts = await BackupRestoreService.getLiveTableCounts();
      if (mounted) {
        setState(() {
          _tableCounts = counts;
          _loadingCounts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final res = await Supabase.instance.client
          .from('audit_logs')
          .select('action, module, description, performed_by, created_at, metadata')
          .inFilter('action', ['BACKUP_EXPORT', 'DATABASE_RESTORE'])
          .order('created_at', ascending: false)
          .limit(20);
      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(res as List);
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  // ─── Export ───────────────────────────────────────────────────

  Future<void> _runExport() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'Generating backup snapshot...';
      _exportIsError = false;
    });
    try {
      final selected = _selectedExportTables.toList();
      final isFullBackup = selected.length == BackupRestoreService.availableTables.length;

      final backupData = await BackupRestoreService.generateBackupData(
        selectedTableNames: isFullBackup ? null : selected,
        onProgress: (msg, _) {
          if (mounted) setState(() => _exportStatus = msg);
        },
      );

      setState(() => _exportStatus = 'Saving file...');
      final path = await BackupRestoreService.saveBackupToFile(backupData);

      final counts = backupData['record_counts'] as Map<String, dynamic>?;
      final total = counts?.values.fold<int>(0, (a, b) => a + (b as int)) ?? 0;

      if (mounted) {
        setState(() {
          _exportStatus = path != null
              ? '✅ Backup saved — $total records across ${selected.length} tables.'
              : '⚠️ Export cancelled.';
          _isExporting = false;
        });
        _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _exportStatus = '❌ Export failed: $e';
          _exportIsError = true;
          _isExporting = false;
        });
      }
    }
  }

  // ─── Import / Restore ──────────────────────────────────────────

  Future<void> _pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      final bytes = result.files.single.bytes!;
      final parsed = BackupRestoreService.validateBackupData(bytes);
      final dataMap = parsed['data'] as Map<String, dynamic>;

      final availableInFile = BackupRestoreService.availableTables
          .where((t) => dataMap.containsKey(t.tableName))
          .map((t) => t.tableName)
          .toSet();

      setState(() {
        _parsedBackup = parsed;
        _backupFileLabel = result.files.single.name;
        _selectedRestoreTables = Set.from(availableInFile);
        _restoreResult = null;
        _restoreProgressMsg = '';
      });
    } catch (e) {
      _showSnack('❌ Invalid backup file: $e', isError: true);
    }
  }

  Future<void> _runRestore() async {
    if (_parsedBackup == null || _selectedRestoreTables.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DeveloperTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _isUpsertMode ? DeveloperTheme.accentEmerald : DeveloperTheme.accentRose,
          ),
        ),
        title: Text('Confirm Database Restore', style: DeveloperTheme.headingMedium()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mode: ${_isUpsertMode ? "Merge / Upsert (Safe)" : "Overwrite (Destructive)"}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _isUpsertMode ? DeveloperTheme.accentEmerald : DeveloperTheme.accentRose,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tables to restore: ${_selectedRestoreTables.length}',
              style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
            ),
            if (!_isUpsertMode) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DeveloperTheme.accentRose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DeveloperTheme.accentRose.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '⚠️ OVERWRITE will delete current records before inserting. This cannot be undone.',
                  style: DeveloperTheme.bodySmall(color: DeveloperTheme.accentRose),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isUpsertMode ? DeveloperTheme.accentEmerald : DeveloperTheme.accentRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isUpsertMode ? 'Merge & Restore' : 'Overwrite & Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isRestoring = true;
      _restoreResult = null;
      _restoreProgressMsg = 'Starting restoration...';
    });

    try {
      final result = await BackupRestoreService.executeRestore(
        backupData: _parsedBackup!,
        selectedTablesToRestore: _selectedRestoreTables.toList(),
        isUpsertMode: _isUpsertMode,
        onProgress: (msg, _) {
          if (mounted) setState(() => _restoreProgressMsg = msg);
        },
      );

      if (mounted) {
        setState(() {
          _restoreResult = result;
          _isRestoring = false;
        });
        _loadTableCounts();
        _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _restoreProgressMsg = '❌ Restore failed: $e';
        });
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? DeveloperTheme.accentRose : DeveloperTheme.accentEmerald,
    ));
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tables = BackupRestoreService.availableTables;
    final totalRows = _tableCounts.values.fold(0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Database Backup & Restore Center', style: DeveloperTheme.headingLarge()),
                  const SizedBox(height: 4),
                  Text(
                    'Selective export, JSON restore, and backup history tracking',
                    style: DeveloperTheme.bodySmall(),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DeveloperTheme.textPrimary,
                      side: const BorderSide(color: DeveloperTheme.borderSubtle),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _loadingCounts ? null : _loadTableCounts,
                    icon: _loadingCounts
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: DeveloperTheme.accentCyan),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh Counts'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DeveloperTheme.accentCyan,
                      foregroundColor: DeveloperTheme.bgDark,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: (_isExporting || _selectedExportTables.isEmpty) ? null : _runExport,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: DeveloperTheme.bgDark),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      _isExporting
                          ? 'Exporting...'
                          : 'Export ${_selectedExportTables.length == tables.length ? "All" : "${_selectedExportTables.length} Tables"} JSON',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Export status banner
          if (_exportStatus != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: (_exportIsError ? DeveloperTheme.accentRose : DeveloperTheme.accentCyan)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_exportIsError ? DeveloperTheme.accentRose : DeveloperTheme.accentCyan)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: _exportIsError ? DeveloperTheme.accentRose : DeveloperTheme.accentCyan,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_exportStatus!, style: DeveloperTheme.bodySmall(color: DeveloperTheme.textPrimary)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 16),

          // ── Stats Banner ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DeveloperTheme.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: DeveloperTheme.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statMetric('Tracked Tables', '${tables.length}', DeveloperTheme.accentIndigo, Icons.table_view),
                Container(width: 1, height: 32, color: DeveloperTheme.borderSubtle),
                _statMetric(
                  'Total Live Records',
                  _loadingCounts ? 'Scanning...' : '$totalRows rows',
                  DeveloperTheme.accentCyan,
                  Icons.data_object,
                ),
                Container(width: 1, height: 32, color: DeveloperTheme.borderSubtle),
                _statMetric(
                  'Selected for Export',
                  '${_selectedExportTables.length} / ${tables.length} tables',
                  DeveloperTheme.accentAmber,
                  Icons.check_box,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ─────────────────────────────────────────────────────────
          // SECTION A: Selective Table Backup
          // ─────────────────────────────────────────────────────────
          _sectionHeader(
            '✅  Selective Table Backup',
            'Choose which tables to include in the exported JSON backup',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: DeveloperTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuickSelectRow(tables),
                const SizedBox(height: 12),
                const Divider(color: DeveloperTheme.borderSubtle),
                const SizedBox(height: 8),
                ...tables.map((t) => _buildTableCheckbox(t)),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ─────────────────────────────────────────────────────────
          // SECTION B: Import / Restore
          // ─────────────────────────────────────────────────────────
          _sectionHeader(
            '📥  Import & Restore from Backup',
            'Upload a backup JSON file and selectively restore tables into the database',
          ),
          const SizedBox(height: 12),
          _buildRestorePanel(),

          const SizedBox(height: 28),

          // ─────────────────────────────────────────────────────────
          // SECTION C: Backup History Log
          // ─────────────────────────────────────────────────────────
          _sectionHeader(
            '📅  Backup & Restore History',
            'Last 20 backup and restore operations recorded in the audit trail',
          ),
          const SizedBox(height: 12),
          _buildHistoryPanel(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Section A ────────────────────────────────────────────────

  Widget _buildQuickSelectRow(List<TableBackupConfig> tables) {
    final categories = tables.map((t) => t.category).toSet().toList();
    final allSelected = _selectedExportTables.length == tables.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _quickChip(
          label: allSelected ? 'Deselect All' : 'Select All',
          icon: allSelected ? Icons.deselect : Icons.select_all_rounded,
          color: DeveloperTheme.accentIndigo,
          onTap: () => setState(() {
            if (allSelected) {
              _selectedExportTables.clear();
            } else {
              _selectedExportTables = tables.map((t) => t.tableName).toSet();
            }
          }),
        ),
        ...categories.map((cat) {
          final catTables = tables
              .where((t) => t.category == cat)
              .map((t) => t.tableName)
              .toSet();
          final allCatSelected = _selectedExportTables.containsAll(catTables);
          return _quickChip(
            label: cat,
            icon: allCatSelected ? Icons.folder : Icons.folder,
            color: DeveloperTheme.accentCyan,
            onTap: () => setState(() {
              if (allCatSelected) {
                _selectedExportTables.removeAll(catTables);
              } else {
                _selectedExportTables.addAll(catTables);
              }
            }),
          );
        }),
      ],
    );
  }

  Widget _buildTableCheckbox(TableBackupConfig t) {
    final isSelected = _selectedExportTables.contains(t.tableName);
    final count = _tableCounts[t.tableName];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: () => setState(() {
          if (isSelected) {
            _selectedExportTables.remove(t.tableName);
          } else {
            _selectedExportTables.add(t.tableName);
          }
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? DeveloperTheme.accentIndigo.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? DeveloperTheme.accentIndigo.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: isSelected ? DeveloperTheme.accentIndigo : DeveloperTheme.textMuted,
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: DeveloperTheme.accentIndigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.table_chart_rounded, size: 14, color: DeveloperTheme.accentIndigo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.displayName,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DeveloperTheme.textPrimary),
                    ),
                    Text(
                      '${t.tableName} · ${t.category} · ${t.description}',
                      style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DeveloperTheme.bgDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: DeveloperTheme.borderSubtle),
                ),
                child: Text(
                  _loadingCounts ? '...' : '${count ?? 0} rows',
                  style: DeveloperTheme.monoText(
                      fontSize: 11,
                      color: DeveloperTheme.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DeveloperTheme.accentEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'CONFIGURED',
                  style: DeveloperTheme.monoText(
                      fontSize: 11,
                      color: DeveloperTheme.accentEmerald,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section B ────────────────────────────────────────────────

  Widget _buildRestorePanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: DeveloperTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1 — Upload
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 1 — Upload Backup File',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DeveloperTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _backupFileLabel ?? 'No file selected — choose a .json backup file',
                      style: DeveloperTheme.bodySmall(
                        color: _backupFileLabel != null
                            ? DeveloperTheme.accentCyan
                            : DeveloperTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DeveloperTheme.bgDark,
                  foregroundColor: DeveloperTheme.textPrimary,
                  side: const BorderSide(color: DeveloperTheme.borderSubtle),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: _isRestoring ? null : _pickBackupFile,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(_parsedBackup != null ? 'Change File' : 'Choose JSON File'),
              ),
            ],
          ),

          if (_parsedBackup == null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: DeveloperTheme.bgDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DeveloperTheme.borderSubtle),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload, size: 40, color: DeveloperTheme.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'Upload a backup file to enable restore options',
                      style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Divider(color: DeveloperTheme.borderSubtle),
            const SizedBox(height: 16),

            // Parsed backup metadata
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DeveloperTheme.accentIndigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DeveloperTheme.accentIndigo.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backup File Info',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: DeveloperTheme.accentIndigo),
                  ),
                  const SizedBox(height: 8),
                  _infoRow('Type', _parsedBackup!['backup_type']?.toString() ?? 'UNKNOWN'),
                  _infoRow('Created At', _parsedBackup!['created_at']?.toString() ?? '-'),
                  _infoRow('Created By', _parsedBackup!['created_by']?.toString() ?? '-'),
                  _infoRow('Version', _parsedBackup!['version']?.toString() ?? '-'),
                  _infoRow(
                    'Tables in File',
                    '${(_parsedBackup!['tables_included'] as List?)?.length ?? 0}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Step 2 — Mode
            Text(
              'Step 2 — Restore Mode',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: DeveloperTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildModeCard(isUpsert: true)),
                const SizedBox(width: 12),
                Expanded(child: _buildModeCard(isUpsert: false)),
              ],
            ),

            const SizedBox(height: 16),

            // Step 3 — Table selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Step 3 — Tables to Restore',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DeveloperTheme.textPrimary),
                ),
                TextButton.icon(
                  onPressed: () {
                    final dataMap = _parsedBackup!['data'] as Map<String, dynamic>;
                    final avail = BackupRestoreService.availableTables
                        .where((t) => dataMap.containsKey(t.tableName))
                        .map((t) => t.tableName)
                        .toSet();
                    setState(() {
                      if (_selectedRestoreTables.containsAll(avail)) {
                        _selectedRestoreTables.clear();
                      } else {
                        _selectedRestoreTables = Set.from(avail);
                      }
                    });
                  },
                  icon: const Icon(Icons.select_all_rounded, size: 14),
                  label: const Text('Toggle All'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildRestoreTableList(),

            const SizedBox(height: 16),

            // Step 4 — Execute
            if (_isRestoring) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DeveloperTheme.accentAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DeveloperTheme.accentAmber.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: DeveloperTheme.accentAmber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_restoreProgressMsg,
                        style: DeveloperTheme.bodySmall(color: DeveloperTheme.textPrimary)),
                  ),
                ]),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isUpsertMode ? DeveloperTheme.accentEmerald : DeveloperTheme.accentRose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: DeveloperTheme.borderSubtle,
                  ),
                  onPressed: _selectedRestoreTables.isEmpty ? null : _runRestore,
                  icon: Icon(
                    _isUpsertMode ? Icons.merge_rounded : Icons.restore_rounded,
                    size: 20,
                  ),
                  label: Text(
                    _isUpsertMode
                        ? 'Execute Merge & Restore (${_selectedRestoreTables.length} tables)'
                        : 'Execute Overwrite Restore (${_selectedRestoreTables.length} tables) ⚠️',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],

            if (_restoreResult != null) ...[
              const SizedBox(height: 16),
              _buildRestoreResult(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildModeCard({required bool isUpsert}) {
    final isSelected = _isUpsertMode == isUpsert;
    final color = isUpsert ? DeveloperTheme.accentEmerald : DeveloperTheme.accentRose;

    return InkWell(
      onTap: () => setState(() => _isUpsertMode = isUpsert),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : DeveloperTheme.bgDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : DeveloperTheme.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  isUpsert ? 'Merge / Upsert' : 'Overwrite',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: DeveloperTheme.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isUpsert
                  ? 'Adds new records, updates existing ones. Safe — preserves current data.'
                  : 'Deletes existing rows first, then re-inserts. Destructive — use with caution.',
              style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreTableList() {
    final dataMap = _parsedBackup!['data'] as Map<String, dynamic>;
    final recordCounts = _parsedBackup!['record_counts'] as Map<String, dynamic>?;
    final availableTables = BackupRestoreService.availableTables
        .where((t) => dataMap.containsKey(t.tableName))
        .toList();

    return Column(
      children: availableTables.map((t) {
        final isSelected = _selectedRestoreTables.contains(t.tableName);
        final count = recordCounts?[t.tableName] ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: InkWell(
            onTap: () => setState(() {
              if (isSelected) {
                _selectedRestoreTables.remove(t.tableName);
              } else {
                _selectedRestoreTables.add(t.tableName);
              }
            }),
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? DeveloperTheme.accentEmerald.withValues(alpha: 0.08)
                    : DeveloperTheme.bgDark,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isSelected
                      ? DeveloperTheme.accentEmerald.withValues(alpha: 0.3)
                      : DeveloperTheme.borderSubtle,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 18,
                    color: isSelected ? DeveloperTheme.accentEmerald : DeveloperTheme.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.displayName,
                      style:
                          GoogleFonts.inter(fontSize: 13, color: DeveloperTheme.textPrimary),
                    ),
                  ),
                  Text(
                    '$count records in file',
                    style: DeveloperTheme.monoText(fontSize: 11, color: DeveloperTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRestoreResult() {
    final result = _restoreResult!;
    final color =
        result.isSuccess ? DeveloperTheme.accentEmerald : DeveloperTheme.accentRose;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                result.isSuccess ? 'Restore Successful' : 'Restore Completed with Errors',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(result.message,
              style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...result.errors.take(3).map((e) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $e',
                      style: DeveloperTheme.monoText(
                          fontSize: 11, color: DeveloperTheme.accentRose)),
                )),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: result.restoredCounts.entries
                .map((e) => Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: DeveloperTheme.bgDark,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: DeveloperTheme.borderSubtle),
                      ),
                      child: Text(
                        '${e.key}: ${e.value}',
                        style: DeveloperTheme.monoText(
                            fontSize: 11, color: DeveloperTheme.textSecondary),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─── Section C ────────────────────────────────────────────────

  Widget _buildHistoryPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DeveloperTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Operations',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DeveloperTheme.textPrimary),
              ),
              IconButton(
                onPressed: _loadingHistory ? null : _loadHistory,
                icon: _loadingHistory
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: DeveloperTheme.accentCyan),
                      )
                    : const Icon(Icons.refresh_rounded,
                        size: 18, color: DeveloperTheme.textSecondary),
                tooltip: 'Refresh History',
              ),
            ],
          ),
          const Divider(color: DeveloperTheme.borderSubtle),
          if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                  child: CircularProgressIndicator(color: DeveloperTheme.accentCyan)),
            )
          else if (_history.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 48, color: DeveloperTheme.textMuted),
                    const SizedBox(height: 12),
                    Text('No backup operations recorded yet',
                        style: DeveloperTheme.bodySmall()),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: DeveloperTheme.borderSubtle, height: 16),
              itemBuilder: (_, i) => _buildHistoryItem(_history[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> log) {
    final isExport = log['action'] == 'BACKUP_EXPORT';
    final color = isExport ? DeveloperTheme.accentCyan : DeveloperTheme.accentAmber;
    final icon = isExport ? Icons.download_rounded : Icons.restore_rounded;
    final label = isExport ? 'EXPORT' : 'RESTORE';

    final createdAt = log['created_at'] as String?;
    final formattedDate = createdAt != null
        ? DateFormat('MMM d, yyyy · h:mm a').format(DateTime.parse(createdAt).toLocal())
        : '-';

    final rawMeta = log['metadata'];
    Map<String, dynamic> meta = {};
    try {
      if (rawMeta is Map) {
        meta = Map<String, dynamic>.from(rawMeta);
      } else if (rawMeta is String) {
        meta = Map<String, dynamic>.from(jsonDecode(rawMeta));
      }
    } catch (_) {}

    final tablesCount =
        meta['tables_count'] ?? (meta['restored_counts'] as Map?)?.length ?? '-';
    final backupType = meta['backup_type']?.toString();

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      label,
                      style: DeveloperTheme.monoText(
                          fontSize: 10, color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (backupType != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DeveloperTheme.bgDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        backupType,
                        style: DeveloperTheme.monoText(
                            fontSize: 10, color: DeveloperTheme.textMuted),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(formattedDate,
                      style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                log['description']?.toString() ?? '-',
                style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$tablesCount tables',
              style: DeveloperTheme.monoText(fontSize: 11, color: DeveloperTheme.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              (log['performed_by']?.toString() ?? '-').split('@').first,
              style: DeveloperTheme.monoText(fontSize: 10, color: DeveloperTheme.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  // ─── Shared Helpers ───────────────────────────────────────────

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: DeveloperTheme.headingMedium()),
        const SizedBox(height: 2),
        Text(subtitle, style: DeveloperTheme.bodySmall()),
      ],
    );
  }

  Widget _quickChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _statMetric(String title, String value, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: DeveloperTheme.bodySmall()),
            Text(
              value,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DeveloperTheme.textPrimary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: DeveloperTheme.monoText(fontSize: 12, color: DeveloperTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
