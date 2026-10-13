import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_log_model.dart';

class AuditLogService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Log an administrative or staff activity in a fire-and-forget, safe manner.
  static Future<void> logActivity({
    required String action,
    required String module,
    required String description,
    String? entityId,
    Map<String, dynamic>? metadata,
    String? customUserEmail,
    String? customUserName,
    String? customUserRole,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      String email = customUserEmail ?? user?.email ?? 'system@yangchow.com';
      String name = customUserName ?? '';
      String role = customUserRole ?? '';

      // If name or role is not explicitly provided, try to extract from user metadata or users table
      if (user != null) {
        if (name.isEmpty) {
          name = user.userMetadata?['full_name']?.toString() ??
              user.userMetadata?['name']?.toString() ??
              email.split('@').first;
        }

        if (role.isEmpty) {
          try {
            final userRecord = await _supabase
                .from('users')
                .select('firstname, lastname, role')
                .eq('email', email)
                .maybeSingle();

            if (userRecord != null) {
              final fName = userRecord['firstname']?.toString() ?? '';
              final lName = userRecord['lastname']?.toString() ?? '';
              final fullName = '$fName $lName'.trim();
              if (name.isEmpty && fullName.isNotEmpty) {
                name = fullName;
              }
              if (userRecord['role'] != null) {
                role = userRecord['role'].toString();
              }
            }
          } catch (_) {
            // fallback gracefully
          }
        }
      }

      if (name.isEmpty) {
        name = email.split('@').first;
      }

      if (role.isEmpty) {
        final lowerEmail = email.toLowerCase();
        if (lowerEmail.contains('admn') ||
            lowerEmail.contains('admin') ||
            lowerEmail.startsWith('admn.') ||
            lowerEmail.startsWith('admin.')) {
          role = 'ADMIN';
        } else if (lowerEmail == 'chefycp@gmail.com' || lowerEmail.contains('chef')) {
          role = 'CHEF';
        } else if (lowerEmail.contains('yangchowit') ||
            lowerEmail.contains('developer') ||
            lowerEmail.contains('dev')) {
          role = 'DEVELOPER';
        } else {
          role = 'STAFF';
        }
      }

      final payload = {
        'user_id': user?.id,
        'user_email': email,
        'user_name': name.isEmpty ? email.split('@').first : name,
        'user_role': role.toUpperCase(),
        'action': action.toUpperCase(),
        'module': module,
        'description': description,
        'entity_id': entityId,
        'metadata': metadata ?? {},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _supabase.from('audit_logs').insert(payload);
    } catch (e) {
      // Never crash caller if network/audit log fails
      debugPrint('[AuditLogService] Error logging activity: $e');
    }
  }

  /// Returns module aliases and naming variations to ensure case-insensitive,
  /// comprehensive audit log searching across submodules.
  static List<String> getModuleAliases(String moduleName) {
    final m = moduleName.toLowerCase().trim();
    switch (m) {
      case 'reservations':
        return ['Reservations', 'reservations', 'RESERVATIONS', 'qr_check_in', 'qr_scanner', 'advance_orders'];
      case 'reschedule':
        return ['Reschedule', 'reschedule', 'reschedules'];
      case 'payments':
        return ['Payments', 'payments', 'payment'];
      case 'refunds':
        return ['Refunds', 'refunds', 'refund'];
      case 'petty cash':
        return ['Petty Cash', 'petty cash', 'petty_cash', 'pettycash', 'Expenses', 'expenses'];
      case 'inventory':
        return ['Inventory', 'inventory', 'kitchen_inventory', 'stock'];
      case 'menu':
        return ['Menu', 'menu', 'dish', 'recipe'];
      case 'users':
        return ['Users', 'users', 'customer accounts', 'profile'];
      case 'announcements':
        return ['Announcements', 'announcements', 'announcement'];
      case 'spoilage':
        return ['Spoilage', 'spoilage', 'waste', 'spoilage_wastage'];
      case 'auth':
        return ['Auth', 'auth', 'authentication', 'login', 'logout'];
      case 'system':
        return ['System', 'system', 'system backup', 'system backup & recovery'];
      default:
        return [m];
    }
  }

  /// Fetch audit logs with filtering options.
  /// Set [operationsOnly] to true to strictly show Yang Chow business operations
  /// and exclude IT Developer testing, maintenance toggles, and system diagnostic logs.
  static Future<List<AuditLog>> fetchLogs({
    String? searchQuery,
    String? module,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
    bool operationsOnly = false,
    int limit = 150,
  }) async {
    try {
      var query = _supabase.from('audit_logs').select();

      final bool isSpecificModule = module != null && module.isNotEmpty && module != 'All Modules';
      List<String> moduleAliases = [];

      if (isSpecificModule) {
        moduleAliases = getModuleAliases(module);
        // Build casing variants for database inFilter
        final Set<String> dbVariants = {};
        for (final a in moduleAliases) {
          dbVariants.add(a);
          dbVariants.add(a.toUpperCase());
          dbVariants.add(a.toLowerCase());
          // Title Case every word (e.g. "petty cash" -> "Petty Cash")
          final titleCased = a
              .split(' ')
              .map((w) => w.isNotEmpty ? (w[0].toUpperCase() + w.substring(1).toLowerCase()) : '')
              .join(' ');
          dbVariants.add(titleCased);
        }
        query = query.inFilter('module', dbVariants.toList());
      }

      if (action != null && action.isNotEmpty && action != 'All Actions') {
        query = query.eq('action', action.toUpperCase());
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toUtc().toIso8601String());
      }

      if (endDate != null) {
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.lte('created_at', endOfDay.toUtc().toIso8601String());
      }

      if (operationsOnly) {
        query = query
            .not('action', 'in', '("ERROR","CRITICAL","FAILED","SYSTEM_ERROR","WARNING")')
            .not('user_role', 'in', '("DEVELOPER","IT")')
            .not('user_email', 'ilike', '%yangchowit%');
      }

      List<dynamic> allRecords = [];
      const int chunkSize = 1000;
      int offset = 0;

      while (allRecords.length < limit) {
        final int to = offset + chunkSize - 1;
        final chunk = await query
            .order('created_at', ascending: false)
            .range(offset, to);

        final chunkList = chunk as List;
        allRecords.addAll(chunkList);

        if (chunkList.length < chunkSize) {
          break; // Reached the end of database records
        }
        offset += chunkSize;
      }

      List<AuditLog> logs = allRecords
          .map((item) => AuditLog.fromJson(item as Map<String, dynamic>))
          .toList();

      // In-memory case-insensitive safety filter for module
      if (isSpecificModule && moduleAliases.isNotEmpty) {
        logs = logs.where((log) {
          final logMod = log.module.toLowerCase().trim();
          return moduleAliases.any((alias) => logMod == alias || logMod.contains(alias));
        }).toList();
      }

      if (operationsOnly) {
        logs = logs.where((log) {
          final email = log.userEmail.toLowerCase();
          final role = log.userRole.toUpperCase();
          final actionUpper = log.action.toUpperCase();
          final moduleLower = log.module.toLowerCase();

          // Exclude developer / IT test account
          if (email.contains('yangchowit') || role == 'DEVELOPER' || role == 'IT') {
            return false;
          }

          // Exclude technical IT / Maintenance actions / Admin Governance
          if (moduleLower.contains('it access') ||
              moduleLower.contains('admin governance') ||
              actionUpper.startsWith('IT_ACCESS') ||
              actionUpper.contains('MAINTENANCE') ||
              actionUpper.startsWith('CONTINUITY') ||
              actionUpper.startsWith('SUCCESSION') ||
              actionUpper == 'PURGE_MAINTENANCE_TEST_DATA') {
            return false;
          }

          // Exclude internal Flutter framework exceptions, rendering crashes & developer telemetry
          final isTechnicalFrameworkLog = actionUpper == 'ERROR' ||
              actionUpper == 'CRITICAL' ||
              actionUpper == 'WARNING' ||
              moduleLower.contains('library') ||
              moduleLower.contains('flutter') ||
              moduleLower == 'platformdispatcher' ||
              (log.metadata['is_system_telemetry'] == true);
          if (isTechnicalFrameworkLog) {
            return false;
          }

          // Strictly restrict to authentic restaurant operational modules present in the dropdown
          if (!isSpecificModule) {
            final isRecognizedOperation = moduleLower.contains('reservation') ||
                moduleLower.contains('reschedule') ||
                moduleLower.contains('payment') ||
                moduleLower.contains('billing') ||
                moduleLower.contains('refund') ||
                moduleLower.contains('petty') ||
                moduleLower.contains('inventory') ||
                moduleLower.contains('stock') ||
                moduleLower.contains('menu') ||
                moduleLower.contains('dish') ||
                moduleLower.contains('user') ||
                moduleLower.contains('account') ||
                moduleLower.contains('announcement') ||
                moduleLower.contains('spoilage') ||
                moduleLower.contains('waste') ||
                moduleLower.contains('auth') ||
                moduleLower.contains('login') ||
                moduleLower.contains('logout');
            if (!isRecognizedOperation) {
              return false;
            }
          }

          return true;
        }).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        logs = logs.where((log) {
          return log.description.toLowerCase().contains(q) ||
              log.userEmail.toLowerCase().contains(q) ||
              log.userName.toLowerCase().contains(q) ||
              (log.entityId?.toLowerCase().contains(q) ?? false) ||
              log.module.toLowerCase().contains(q) ||
              log.action.toLowerCase().contains(q);
        }).toList();
      }

      return logs;
    } catch (e) {
      debugPrint('[AuditLogService] Error fetching audit logs: $e');
      return [];
    }
  }

  /// Generate CSV formatted string from logs
  static String generateCsv(List<AuditLog> logs) {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('"Timestamp","User Name","User Email","Role","Module","Action","Description","Entity ID","Metadata"');

    for (final log in logs) {
      final safeDesc = log.description.replaceAll('"', '""');
      final safeMeta = jsonEncode(log.metadata).replaceAll('"', '""');
      final safeDate = log.createdAt.toString();

      buffer.writeln('"${safeDate}","${log.userName}","${log.userEmail}","${log.userRole}","${log.module}","${log.action}","${safeDesc}","${log.entityId ?? ''}","${safeMeta}"');
    }

    return buffer.toString();
  }

  /// Purge technical error logs / crash telemetry from audit_logs.
  /// Safe: Only deletes CRITICAL, ERROR, FAILED, SYSTEM_ERROR records or system telemetry.
  /// Does NOT touch business activity logs (staff operations, logins, orders, settings).
  static Future<void> purgeTechnicalErrorLogs() async {
    try {
      await _supabase
          .from('audit_logs')
          .delete()
          .or('action.eq.CRITICAL,action.eq.ERROR,action.eq.FAILED,action.eq.SYSTEM_ERROR');
    } catch (e) {
      debugPrint('[AuditLogService] Error purging technical error logs: $e');
      rethrow;
    }
  }
}
