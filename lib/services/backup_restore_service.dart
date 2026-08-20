import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audit_log_service.dart';

/// Information about a table that can be backed up or restored
class TableBackupConfig {
  final String tableName;
  final String displayName;
  final String description;
  final String category; // 'Core', 'Operations', 'Inventory', 'Financial', 'Logs'
  final String primaryKey;

  const TableBackupConfig({
    required this.tableName,
    required this.displayName,
    required this.description,
    required this.category,
    this.primaryKey = 'id',
  });
}

/// Result of a restore operation
class RestoreSummary {
  final bool isSuccess;
  final String message;
  final Map<String, int> restoredCounts;
  final List<String> errors;
  final DateTime executedAt;

  RestoreSummary({
    required this.isSuccess,
    required this.message,
    required this.restoredCounts,
    required this.errors,
    required this.executedAt,
  });
}

typedef ProgressCallback = void Function(String currentTask, double progress);

class BackupRestoreService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Configured tables available for backup & restore, arranged in safe dependency order
  static const List<TableBackupConfig> availableTables = [
    // Core Data
    TableBackupConfig(
      tableName: 'menu_items',
      displayName: 'Menu Items',
      description: 'Dishes, categories, prices, and availability',
      category: 'Core',
    ),
    TableBackupConfig(
      tableName: 'recipe_ingredients',
      displayName: 'Menu Recipes & Ingredients',
      description: 'Recipe BOM ingredient deductions for menu items',
      category: 'Core',
    ),
    TableBackupConfig(
      tableName: 'announcements',
      displayName: 'Announcements',
      description: 'Store news, promos, and banner announcements',
      category: 'Core',
    ),

    // Operations & Sales
    TableBackupConfig(
      tableName: 'reservations',
      displayName: 'Reservations & Bookings',
      description: 'Event and dine-in reservations, guest details, status',
      category: 'Operations',
    ),
    TableBackupConfig(
      tableName: 'orders',
      displayName: 'Orders & Sales',
      description: 'Dine-in, advance, and customer orders',
      category: 'Operations',
    ),
    TableBackupConfig(
      tableName: 'order_items',
      displayName: 'Order Items',
      description: 'Individual dish line items linked to orders',
      category: 'Operations',
    ),
    TableBackupConfig(
      tableName: 'refunds',
      displayName: 'Refund Requests',
      description: 'Customer refund records and approval statuses',
      category: 'Operations',
    ),
    TableBackupConfig(
      tableName: 'reschedule_requests',
      displayName: 'Reschedule Requests',
      description: 'Reservation reschedule logs and approvals',
      category: 'Operations',
    ),
    TableBackupConfig(
      tableName: 'reviews',
      displayName: 'Customer Reviews',
      description: 'Customer feedback and star ratings',
      category: 'Operations',
    ),

    // Inventory
    TableBackupConfig(
      tableName: 'inventory',
      displayName: 'Inventory Items',
      description: 'Raw ingredients, stock quantities, and units',
      category: 'Inventory',
    ),
    TableBackupConfig(
      tableName: 'stock_transactions',
      displayName: 'Stock Transactions & Spoilage',
      description: 'Stock-in, stock-out, and spoilage records',
      category: 'Inventory',
    ),

    // Financial & Cash
    TableBackupConfig(
      tableName: 'petty_cash_fund',
      displayName: 'Petty Cash Fund',
      description: 'Cash-on-hand balances and replenishment logs',
      category: 'Financial',
    ),
    TableBackupConfig(
      tableName: 'petty_cash_expenses',
      displayName: 'Petty Cash Expenses',
      description: 'Expense vouchers, disbursements, and receipts',
      category: 'Financial',
    ),

    // Logs
    TableBackupConfig(
      tableName: 'audit_logs',
      displayName: 'System Audit Logs',
      description: 'Administrative action trail and system activity logs',
      category: 'Logs',
    ),
  ];

  /// Get live row count for all available tables
  static Future<Map<String, int>> getLiveTableCounts() async {
    final Map<String, int> counts = {};

    for (final table in availableTables) {
      try {
        final res = await _supabase
            .from(table.tableName)
            .select(table.primaryKey);
        counts[table.tableName] = (res as List).length;
      } catch (e) {
        debugPrint('[BackupRestoreService] Error counting ${table.tableName}: $e');
        counts[table.tableName] = 0;
      }
    }

    return counts;
  }

  /// Generates a structured JSON backup payload
  static Future<Map<String, dynamic>> generateBackupData({
    List<String>? selectedTableNames,
    ProgressCallback? onProgress,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    final adminEmail = currentUser?.email ?? 'admin@yangchow.com';
    final tablesToExport = availableTables.where((t) {
      if (selectedTableNames == null || selectedTableNames.isEmpty) return true;
      return selectedTableNames.contains(t.tableName);
    }).toList();

    final Map<String, List<Map<String, dynamic>>> tablesData = {};
    final Map<String, int> summaryCounts = {};
    int completed = 0;

    for (final table in tablesToExport) {
      onProgress?.call(
        'Exporting ${table.displayName}...',
        completed / tablesToExport.length,
      );

      try {
        final res = await _supabase.from(table.tableName).select('*');
        final rows = List<Map<String, dynamic>>.from(res as List);
        tablesData[table.tableName] = rows;
        summaryCounts[table.tableName] = rows.length;
      } catch (e) {
        debugPrint('[BackupRestoreService] Error fetching table ${table.tableName}: $e');
        tablesData[table.tableName] = [];
        summaryCounts[table.tableName] = 0;
      }

      completed++;
    }

    onProgress?.call('Finalizing backup package...', 1.0);

    final payload = {
      'system': 'Yang Chow Restaurant & Catering Management System',
      'version': '1.0.0',
      'backup_type': (selectedTableNames == null || selectedTableNames.length == availableTables.length)
          ? 'FULL'
          : 'SELECTIVE',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'created_by': adminEmail,
      'tables_included': tablesToExport.map((t) => t.tableName).toList(),
      'record_counts': summaryCounts,
      'data': tablesData,
    };

    // Log the backup activity
    await AuditLogService.logActivity(
      action: 'BACKUP_EXPORT',
      module: 'System Backup',
      description: 'Exported database backup (${payload['backup_type']}) containing ${summaryCounts.values.fold(0, (a, b) => a + b)} total records across ${tablesToExport.length} tables.',
      metadata: {
        'backup_type': payload['backup_type'],
        'tables_count': tablesToExport.length,
        'record_counts': summaryCounts,
      },
    );

    return payload;
  }

  /// Prompts user to save the backup JSON file locally
  static Future<String?> saveBackupToFile(Map<String, dynamic> backupData) async {
    try {
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupType = backupData['backup_type'] == 'FULL' ? 'full' : 'selective';
      final fileName = 'yangchow_backup_${backupType}_$timestampStr.json';

      final outputFilePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Yang Chow System Database Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      return outputFilePath;
    } catch (e) {
      debugPrint('[BackupRestoreService] Error saving file: $e');
      rethrow;
    }
  }

  /// Parses and validates uploaded backup JSON data
  static Map<String, dynamic> validateBackupData(Uint8List bytes) {
    try {
      final jsonString = utf8.decode(bytes);
      final dynamic decoded = jsonDecode(jsonString);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid backup file: Root must be a JSON object.');
      }

      if (!decoded.containsKey('data') || decoded['data'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid backup file: Missing or invalid "data" table map.');
      }

      if (!decoded.containsKey('version')) {
        throw const FormatException('Invalid backup file: Missing version header.');
      }

      return decoded;
    } catch (e) {
      throw FormatException('Failed to read backup file: ${e.toString()}');
    }
  }

  /// Executes database restoration from parsed backup data
  static Future<RestoreSummary> executeRestore({
    required Map<String, dynamic> backupData,
    required List<String> selectedTablesToRestore,
    required bool isUpsertMode, // true = Upsert/Merge, false = Overwrite (truncate/delete first)
    ProgressCallback? onProgress,
  }) async {
    final Map<String, dynamic> dataMap = backupData['data'] as Map<String, dynamic>;
    final Map<String, int> restoredCounts = {};
    final List<String> errors = [];

    // Filter tables to restore according to predefined dependency sequence
    final tablesToProcess = availableTables.where((t) {
      return selectedTablesToRestore.contains(t.tableName) && dataMap.containsKey(t.tableName);
    }).toList();

    int completed = 0;
    int totalRestoredRecords = 0;

    for (final tableConfig in tablesToProcess) {
      final tableName = tableConfig.tableName;
      final rawRows = dataMap[tableName];

      onProgress?.call(
        'Restoring ${tableConfig.displayName}...',
        completed / (tablesToProcess.isEmpty ? 1 : tablesToProcess.length),
      );

      if (rawRows is! List || rawRows.isEmpty) {
        restoredCounts[tableName] = 0;
        completed++;
        continue;
      }

      final rows = List<Map<String, dynamic>>.from(rawRows);

      try {
        if (!isUpsertMode) {
          // In overwrite mode, delete existing records first (be cautious)
          try {
            await _supabase.from(tableName).delete().neq(tableConfig.primaryKey, '00000000-0000-0000-0000-000000000000');
          } catch (e) {
            debugPrint('[BackupRestoreService] Note: Non-critical delete fallback for $tableName: $e');
          }
        }

        // Chunk insertions to prevent Supabase payload size limits (batches of 50)
        const int chunkSize = 50;
        int tableRestoredCount = 0;

        for (var i = 0; i < rows.length; i += chunkSize) {
          final chunk = rows.sublist(i, i + chunkSize > rows.length ? rows.length : i + chunkSize);
          
          if (isUpsertMode) {
            try {
              // Try standard upsert with onConflict and ignoreDuplicates: true
              await _supabase.from(tableName).upsert(
                chunk,
                onConflict: tableConfig.primaryKey,
                ignoreDuplicates: true,
              );
              tableRestoredCount += chunk.length;
            } catch (chunkError) {
              debugPrint('[BackupRestoreService] Batch upsert fallback for $tableName: $chunkError');
              // Safe row-by-row insertion fallback
              for (final row in chunk) {
                try {
                  await _supabase.from(tableName).upsert(
                    row,
                    onConflict: tableConfig.primaryKey,
                    ignoreDuplicates: true,
                  );
                  tableRestoredCount++;
                } catch (_) {
                  try {
                    await _supabase.from(tableName).insert(row);
                    tableRestoredCount++;
                  } catch (e) {
                    // If error is duplicate key, it means the record is already in DB
                    final errStr = e.toString().toLowerCase();
                    if (errStr.contains('duplicate') || errStr.contains('23505') || errStr.contains('already exists')) {
                      tableRestoredCount++; // Count as preserved
                    }
                  }
                }
              }
            }
          } else {
            // Overwrite mode
            try {
              await _supabase.from(tableName).insert(chunk);
              tableRestoredCount += chunk.length;
            } catch (chunkError) {
              debugPrint('[BackupRestoreService] Batch insert fallback for $tableName: $chunkError');
              for (final row in chunk) {
                try {
                  await _supabase.from(tableName).insert(row);
                  tableRestoredCount++;
                } catch (_) {
                  try {
                    await _supabase.from(tableName).upsert(
                      row,
                      onConflict: tableConfig.primaryKey,
                      ignoreDuplicates: true,
                    );
                    tableRestoredCount++;
                  } catch (_) {}
                }
              }
            }
          }
        }

        restoredCounts[tableName] = tableRestoredCount;
        totalRestoredRecords += tableRestoredCount;
      } catch (e) {
        final errorMsg = 'Failed restoring $tableName: $e';
        debugPrint('[BackupRestoreService] $errorMsg');
        errors.add(errorMsg);
        restoredCounts[tableName] = 0;
      }

      completed++;
    }

    onProgress?.call('Restoration completed.', 1.0);

    final isSuccess = errors.length < tablesToProcess.length;

    // Log the restore activity
    await AuditLogService.logActivity(
      action: 'DATABASE_RESTORE',
      module: 'System Backup & Recovery',
      description: 'Restored database data (${isUpsertMode ? "Merge/Upsert" : "Overwrite"}) for ${restoredCounts.keys.length} tables ($totalRestoredRecords records).',
      metadata: {
        'mode': isUpsertMode ? 'MERGE_UPSERT' : 'OVERWRITE',
        'backup_created_at': backupData['created_at'],
        'backup_created_by': backupData['created_by'],
        'restored_counts': restoredCounts,
        'errors_count': errors.length,
        'errors': errors.take(5).toList(),
      },
    );

    return RestoreSummary(
      isSuccess: isSuccess,
      message: isSuccess
          ? 'Successfully restored $totalRestoredRecords records across ${restoredCounts.keys.length} tables.'
          : 'Restoration encountered errors.',
      restoredCounts: restoredCounts,
      errors: errors,
      executedAt: DateTime.now(),
    );
  }
}
