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
                .select('name, role')
                .eq('email', email)
                .maybeSingle();

            if (userRecord != null) {
              if (name.isEmpty && userRecord['name'] != null && userRecord['name'].toString().isNotEmpty) {
                name = userRecord['name'].toString();
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

  /// Fetch audit logs with filtering options
  static Future<List<AuditLog>> fetchLogs({
    String? searchQuery,
    String? module,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 150,
  }) async {
    try {
      var query = _supabase.from('audit_logs').select();

      if (module != null && module.isNotEmpty && module != 'All Modules') {
        query = query.eq('module', module);
      }

      if (action != null && action.isNotEmpty && action != 'All Actions') {
        query = query.eq('action', action.toUpperCase());
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toUtc().toIso8601String());
      }

      if (endDate != null) {
        // Set to end of the selected day
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.lte('created_at', endOfDay.toUtc().toIso8601String());
      }

      final response = await query.order('created_at', ascending: false).limit(limit);

      List<AuditLog> logs = (response as List)
          .map((item) => AuditLog.fromJson(item as Map<String, dynamic>))
          .toList();

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
}
