import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'developer_theme.dart';
import '../../services/app_logger.dart';

// ---------------------------------------------------------------------------
// Error Log Model
// ---------------------------------------------------------------------------

enum ErrorSeverity { critical, error, warning, info }

class AppErrorLog {
  final String id;
  final DateTime timestamp;
  final ErrorSeverity severity;
  final String source;
  final String message;
  final String? stackTrace;
  final Map<String, dynamic> context;

  const AppErrorLog({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.source,
    required this.message,
    this.stackTrace,
    this.context = const {},
  });

  factory AppErrorLog.fromAuditLog(Map<String, dynamic> row) {
    final action = (row['action'] ?? '').toString().toUpperCase();
    final meta = (row['metadata'] as Map<String, dynamic>?) ?? {};
    final metaSeverity = (meta['severity'] ?? '').toString().toUpperCase();

    ErrorSeverity severity;
    if (action == 'CRITICAL' || action == 'SYSTEM_ERROR' || metaSeverity == 'CRITICAL') {
      severity = ErrorSeverity.critical;
    } else if (action == 'ERROR' || action == 'FAILED' || metaSeverity == 'ERROR') {
      severity = ErrorSeverity.error;
    } else if (action == 'WARNING' || metaSeverity == 'WARNING') {
      severity = ErrorSeverity.warning;
    } else {
      severity = ErrorSeverity.info;
    }

    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now();
    return AppErrorLog(
      id: row['id']?.toString() ?? 'ERR-${createdAt.millisecondsSinceEpoch}',
      timestamp: createdAt,
      severity: severity,
      source: row['module']?.toString() ?? 'System',
      message: row['description']?.toString() ?? 'No description recorded',
      stackTrace: meta['stack_trace']?.toString(),
      context: {
        'user': row['user_email'] ?? 'system',
        'action': action,
        ...meta,
      },
    );
  }

  Color get severityColor {
    switch (severity) {
      case ErrorSeverity.critical:
        return DeveloperTheme.accentRose;
      case ErrorSeverity.error:
        return const Color(0xFFFC8181);
      case ErrorSeverity.warning:
        return DeveloperTheme.accentAmber;
      case ErrorSeverity.info:
        return DeveloperTheme.accentCyan;
    }
  }

  String get severityLabel {
    switch (severity) {
      case ErrorSeverity.critical:
        return 'CRITICAL';
      case ErrorSeverity.error:
        return 'ERROR';
      case ErrorSeverity.warning:
        return 'WARNING';
      case ErrorSeverity.info:
        return 'INFO';
    }
  }

  IconData get severityIcon {
    switch (severity) {
      case ErrorSeverity.critical:
        return Icons.dangerous_rounded;
      case ErrorSeverity.error:
        return Icons.error_rounded;
      case ErrorSeverity.warning:
        return Icons.warning_rounded;
      case ErrorSeverity.info:
        return Icons.info_rounded;
    }
  }
}

// ---------------------------------------------------------------------------
// In-Memory Error Log Store (Singleton)
// ---------------------------------------------------------------------------

class ErrorLogStore {
  static final ErrorLogStore _instance = ErrorLogStore._internal();
  factory ErrorLogStore() => _instance;
  ErrorLogStore._internal();

  final List<AppErrorLog> _logs = [];
  final StreamController<List<AppErrorLog>> _controller =
      StreamController.broadcast();

  Stream<List<AppErrorLog>> get stream => _controller.stream;
  List<AppErrorLog> get logs => List.unmodifiable(_logs);

  static int _counter = 0;

  void addLog({
    required ErrorSeverity severity,
    required String source,
    required String message,
    String? stackTrace,
    Map<String, dynamic> context = const {},
  }) {
    _counter++;
    final log = AppErrorLog(
      id: 'ERR-${_counter.toString().padLeft(4, '0')}',
      timestamp: DateTime.now(),
      severity: severity,
      source: source,
      message: message,
      stackTrace: stackTrace,
      context: context,
    );
    _logs.insert(0, log);
    if (_logs.length > 500) _logs.removeLast();
    _controller.add(List.unmodifiable(_logs));
  }

  void clear() {
    _logs.clear();
    _counter = 0;
    _controller.add([]);
  }
}

// ---------------------------------------------------------------------------
// Flutter Error Handler Integration (call AppErrorHandler.initialize() in main.dart)
// ---------------------------------------------------------------------------

class AppErrorHandler {
  static void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      // Don't pollute persistent system error logs with transient image loading/CORS failures
      // that are handled gracefully by widget errorBuilders/fallbacks
      final library = details.library ?? '';
      final contextDesc = details.context?.toDescription() ?? '';
      final msg = details.exceptionAsString();
      final isImageResourceError = library == 'image resource service' ||
          contextDesc.contains('image stream completer') ||
          (msg.contains('HTTP request failed') && msg.contains('statusCode: 0')) ||
          msg.contains('ImageCodecException');

      if (isImageResourceError) {
        debugPrint('⚠️ [ImageResource] Handled network image failure: $msg');
        return;
      }

      AppLogger.error(
        module: details.library ?? 'Flutter',
        message: msg,
        stackTrace: details.stack,
        context: {'context': contextDesc},
      );
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      final errStr = error.toString();

      // Don't treat transient socket reconnections / Supabase realtime interruptions as critical crashes
      final isTransientSocketError = errStr.contains('WebSocketException') ||
          errStr.contains('WebSocketChannelException') ||
          errStr.contains('RealtimeSubscribeException') ||
          errStr.contains('SocketException') ||
          errStr.contains('ClientException');

      if (isTransientSocketError) {
        debugPrint('ℹ️ [Network/Realtime] Suppressed transient socket error: $errStr');
        return true; // handled
      }

      AppLogger.critical(
        module: 'PlatformDispatcher',
        message: errStr,
        stackTrace: stack,
      );
      return false;
    };
  }
}
