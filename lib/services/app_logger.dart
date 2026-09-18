import 'package:flutter/foundation.dart';
import 'audit_log_service.dart';
import '../pages/developer/error_log_viewer_page.dart';

/// Centralized application logger providing structured runtime console output,
/// in-memory developer telemetry, and persistent database storage via Supabase.
class AppLogger {
  /// Log a Critical event (database/financial/system-halting failure)
  static Future<void> critical({
    required String module,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    String? entityId,
    Map<String, dynamic>? context,
  }) async {
    final fullStackTrace = stackTrace?.toString() ?? StackTrace.current.toString();
    final errorStr = error != null ? ' | Error: $error' : '';
    debugPrint('🔴 [CRITICAL][$module] $message$errorStr');

    // 1. Feed in-memory developer store
    try {
      ErrorLogStore().addLog(
        severity: ErrorSeverity.critical,
        source: module,
        message: '$message$errorStr',
        stackTrace: fullStackTrace,
        context: context ?? {},
      );
    } catch (_) {}

    // 2. Persist to database audit_logs
    try {
      await AuditLogService.logActivity(
        action: 'CRITICAL',
        module: module,
        description: message,
        entityId: entityId,
        metadata: {
          ...?context,
          'severity': 'CRITICAL',
          if (error != null) 'error': error.toString(),
          'stack_trace': fullStackTrace,
        },
      );
    } catch (e) {
      debugPrint('[AppLogger] Failed to persist critical log: $e');
    }
  }

  /// Log an Error event (action failure, catch-block exception, UI error)
  static Future<void> error({
    required String module,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    String? entityId,
    Map<String, dynamic>? context,
  }) async {
    final fullStackTrace = stackTrace?.toString();
    final errorStr = error != null ? ' | Error: $error' : '';
    debugPrint('🟠 [ERROR][$module] $message$errorStr');

    // 1. Feed in-memory developer store
    try {
      ErrorLogStore().addLog(
        severity: ErrorSeverity.error,
        source: module,
        message: '$message$errorStr',
        stackTrace: fullStackTrace,
        context: context ?? {},
      );
    } catch (_) {}

    // 2. Persist to database audit_logs
    try {
      await AuditLogService.logActivity(
        action: 'ERROR',
        module: module,
        description: message,
        entityId: entityId,
        metadata: {
          ...?context,
          'severity': 'ERROR',
          if (error != null) 'error': error.toString(),
          if (fullStackTrace != null) 'stack_trace': fullStackTrace,
        },
      );
    } catch (e) {
      debugPrint('[AppLogger] Failed to persist error log: $e');
    }
  }

  /// Log a Warning event (non-fatal, anomaly, low stock, deprecation)
  static Future<void> warning({
    required String module,
    required String message,
    String? entityId,
    Map<String, dynamic>? context,
  }) async {
    debugPrint('🟡 [WARNING][$module] $message');

    // 1. Feed in-memory developer store
    try {
      ErrorLogStore().addLog(
        severity: ErrorSeverity.warning,
        source: module,
        message: message,
        context: context ?? {},
      );
    } catch (_) {}

    // 2. Persist to database audit_logs
    try {
      await AuditLogService.logActivity(
        action: 'WARNING',
        module: module,
        description: message,
        entityId: entityId,
        metadata: {
          ...?context,
          'severity': 'WARNING',
        },
      );
    } catch (_) {}
  }

  /// Log an Info event (routine system status, maintenance toggled, user audit)
  static Future<void> info({
    required String module,
    required String message,
    String? entityId,
    Map<String, dynamic>? context,
  }) async {
    debugPrint('ℹ️ [INFO][$module] $message');

    // 1. Feed in-memory developer store
    try {
      ErrorLogStore().addLog(
        severity: ErrorSeverity.info,
        source: module,
        message: message,
        context: context ?? {},
      );
    } catch (_) {}

    // 2. Persist to database audit_logs
    try {
      await AuditLogService.logActivity(
        action: 'INFO',
        module: module,
        description: message,
        entityId: entityId,
        metadata: {
          ...?context,
          'severity': 'INFO',
        },
      );
    } catch (_) {}
  }
}
