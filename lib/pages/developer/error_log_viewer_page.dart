import 'dart:async';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'developer_theme.dart';
import '../../services/app_logger.dart';
import '../../services/audit_log_service.dart';
import '../../utils/file_download.dart';

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

// ---------------------------------------------------------------------------
// Error Log Viewer Page
// ---------------------------------------------------------------------------

class ErrorLogViewerPage extends StatefulWidget {
  const ErrorLogViewerPage({super.key});

  @override
  State<ErrorLogViewerPage> createState() => _ErrorLogViewerPageState();
}

class _ErrorLogViewerPageState extends State<ErrorLogViewerPage> {
  final _store = ErrorLogStore();
  final TextEditingController _searchController = TextEditingController();

  List<AppErrorLog> _allLogs = [];
  List<AppErrorLog> _filteredLogs = [];

  ErrorSeverity? _severityFilter;
  String _sourceFilter = 'All Sources';
  String _searchQuery = '';
  AppErrorLog? _selectedLog;
  bool _autoRefresh = true;
  Timer? _refreshTimer;
  StreamSubscription<List<AppErrorLog>>? _streamSub;

  List<Map<String, dynamic>> _dbErrors = [];
  bool _loadingDbErrors = false;
  RealtimeChannel? _realtimeSub;

  /// Set when user clicks "Clear All" — filters out DB logs older than this
  DateTime? _clearedAt;

  int _runtimePage = 1;
  int _dbPage = 1;
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _allLogs = _store.logs.toList();
    _applyFilters();
    _loadClearedAtAndFetch();

    _streamSub = _store.stream.listen((logs) {
      if (mounted) {
        setState(() {
          final memoryIds = logs.map((l) => l.id).toSet();
          final dbOnly = _allLogs.where((l) => !memoryIds.contains(l.id));
          _allLogs = [...logs, ...dbOnly];
          _applyFilters();
        });
      }
    });

    // Subscribe to realtime database error insertions
    try {
      _realtimeSub = Supabase.instance.client
          .channel('developer_error_log_stream')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'audit_logs',
            callback: (payload) {
              _fetchDbErrors();
            },
          )
          .subscribe();
    } catch (_) {}

    if (_autoRefresh) {
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _fetchDbErrors(),
      );
    }
  }

  Future<void> _loadClearedAtAndFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('dev_error_logs_cleared_at');
      if (str != null) {
        final parsed = DateTime.tryParse(str);
        if (parsed != null && mounted) {
          setState(() {
            _clearedAt = parsed.toUtc();
          });
        }
      }
    } catch (_) {}
    _fetchDbErrors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    _streamSub?.cancel();
    _realtimeSub?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchDbErrors() async {
    if (!mounted) return;
    setState(() => _loadingDbErrors = true);
    try {
      final response = await Supabase.instance.client
          .from('audit_logs')
          .select('id, action, module, description, user_email, created_at, metadata')
          .or('action.eq.CRITICAL,action.eq.ERROR,action.eq.FAILED,action.eq.SYSTEM_ERROR,action.eq.WARNING,action.eq.INFO,description.ilike.%error%,description.ilike.%failed%')
          .order('created_at', ascending: false)
          .limit(1000);

      final List<AppErrorLog> dbLogs = [];
      for (final row in (response as List)) {
        dbLogs.add(AppErrorLog.fromAuditLog(Map<String, dynamic>.from(row)));
      }

      // Merge persistent database errors with any local session logs.
      // If user cleared, only show logs that arrived AFTER the clear time.
      final filtered = _clearedAt == null
          ? dbLogs
          : dbLogs.where((l) => l.timestamp.toUtc().isAfter(_clearedAt!.toUtc())).toList();

      final existingIds = filtered.map((l) => l.id).toSet();
      final memoryOnly = _store.logs.where((l) => !existingIds.contains(l.id));

      final rawDbFiltered = _clearedAt == null
          ? List<Map<String, dynamic>>.from(response)
          : (response as List).where((row) {
              final dt = DateTime.tryParse(row['created_at']?.toString() ?? '');
              return dt != null && dt.toUtc().isAfter(_clearedAt!.toUtc());
            }).map((r) => Map<String, dynamic>.from(r)).toList();

      if (mounted) {
        setState(() {
          _allLogs = [...memoryOnly, ...filtered];
          _dbErrors = rawDbFiltered;
          _loadingDbErrors = false;
          _applyFilters();
          final totalDbPages = (_dbErrors.length / _pageSize).ceil().clamp(1, 99999);
          if (_dbPage > totalDbPages) {
            _dbPage = 1;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDbErrors = false);
    }
  }

  void _applyFilters() {
    List<AppErrorLog> result = _allLogs;

    if (_severityFilter != null) {
      result = result.where((l) => l.severity == _severityFilter).toList();
    }

    if (_sourceFilter != 'All Sources') {
      result = result.where((l) => l.source == _sourceFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((l) =>
              l.message.toLowerCase().contains(q) ||
              l.source.toLowerCase().contains(q) ||
              l.id.toLowerCase().contains(q))
          .toList();
    }

    _filteredLogs = result;
    final totalPages = (_filteredLogs.length / _pageSize).ceil().clamp(1, 99999);
    if (_runtimePage > totalPages) {
      _runtimePage = 1;
    }
  }

  List<String> get _availableSources {
    final sources = _allLogs.map((l) => l.source).toSet().toList()..sort();
    return ['All Sources', ...sources];
  }

  Map<ErrorSeverity, int> get _severityCounts {
    final counts = <ErrorSeverity, int>{};
    for (final log in _allLogs) {
      counts[log.severity] = (counts[log.severity] ?? 0) + 1;
    }
    return counts;
  }

  // ---------------------------------------------------------------------------
  // Export Logs as CSV — real file download on web, clipboard on other platforms
  // ---------------------------------------------------------------------------

  void _exportLogs({List<AppErrorLog>? logs}) {
    final target = logs ?? _allLogs;
    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DeveloperTheme.bgCard,
          content: Text(
            'No logs to export.',
            style: GoogleFonts.inter(color: DeveloperTheme.textMuted),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Build CSV rows
    final rows = <List<dynamic>>[
      ['ID', 'Timestamp', 'Severity', 'Source', 'Message', 'Stack Trace', 'Context'],
    ];
    for (final log in target) {
      rows.add([
        log.id,
        log.timestamp.toLocal().toString(),
        log.severityLabel,
        log.source,
        log.message,
        log.stackTrace ?? '',
        log.context.entries.map((e) => '${e.key}=${e.value}').join('; '),
      ]);
    }
    final csvString = const CsvEncoder().convert(rows);
    final filename =
        'error_logs_${DateTime.now().millisecondsSinceEpoch}.csv';

    // Try real browser download first (web only)
    final downloaded = downloadTextFile(csvString, filename);

    if (downloaded) {
      // Web: file was downloaded via browser
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DeveloperTheme.accentEmerald,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${target.length} logs downloaded as "$filename"',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      // Non-web: copy CSV to clipboard as fallback
      Clipboard.setData(ClipboardData(text: csvString));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DeveloperTheme.accentEmerald,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${target.length} logs copied to clipboard as CSV.',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Clear All (with optional export-first)
  // ---------------------------------------------------------------------------

  void _clearAll() {
    bool deleteFromDb = true;

    showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: DeveloperTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: DeveloperTheme.borderSubtle),
          ),
          title: Text('Clear All Error Logs?', style: DeveloperTheme.headingMedium()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will clear all ${_allLogs.length} error logs currently displayed.',
                style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              // Option to permanently delete from Supabase
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: DeveloperTheme.bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: deleteFromDb
                        ? DeveloperTheme.accentRose.withValues(alpha: 0.5)
                        : DeveloperTheme.borderSubtle,
                  ),
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: DeveloperTheme.accentRose,
                  title: Text(
                    'Permanently delete from Supabase Database',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: DeveloperTheme.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Buburahin sa cloud database ang mga error/crash logs para hindi na bumalik kahit patayin ang laptop. (Hindi madadamay ang business audit trails tulad ng logins at orders).',
                    style: TextStyle(
                      fontSize: 10,
                      color: DeveloperTheme.textMuted,
                    ),
                  ),
                  value: deleteFromDb,
                  onChanged: (val) {
                    setDlgState(() {
                      deleteFromDb = val ?? false;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DeveloperTheme.accentAmber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DeveloperTheme.accentAmber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: DeveloperTheme.accentAmber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'IT Best Practice: Piliin ang "Export & Clear" bago magbura para may offline backup CSV copy ka ng logs.',
                        style: DeveloperTheme.bodySmall(color: DeveloperTheme.accentAmber),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text('Cancel', style: TextStyle(color: DeveloperTheme.textMuted)),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: DeveloperTheme.accentEmerald,
                side: const BorderSide(color: DeveloperTheme.accentEmerald),
              ),
              onPressed: () => Navigator.pop(ctx, 'export_clear'),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Export & Clear'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: DeveloperTheme.accentRose,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, 'clear'),
              icon: const Icon(Icons.delete_sweep_rounded, size: 16),
              label: Text(deleteFromDb ? 'Purge & Clear' : 'Clear View'),
            ),
          ],
        ),
      ),
    ).then((action) async {
      if (action == null || action == 'cancel') return;

      if (action == 'export_clear') {
        _exportLogs(logs: List.from(_allLogs));
      }

      bool dbPurgeFailed = false;
      String? dbErrorMsg;

      if (deleteFromDb) {
        try {
          await AuditLogService.purgeTechnicalErrorLogs();
        } catch (e) {
          dbPurgeFailed = true;
          dbErrorMsg = e.toString();
          debugPrint('[ErrorLogViewer] Failed to purge from Supabase: $e');
        }
      }

      _store.clear();
      final now = DateTime.now().toUtc();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dev_error_logs_cleared_at', now.toIso8601String());
      } catch (_) {}

      if (mounted) {
        setState(() {
          _clearedAt = now;
          _allLogs = [];
          _filteredLogs = [];
          _dbErrors = [];
          _selectedLog = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: dbPurgeFailed ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
            content: Text(
              deleteFromDb
                  ? (dbPurgeFailed
                      ? 'Cleared locally. (Cloud delete note: $dbErrorMsg)'
                      : 'Error logs successfully cleared and purged from Supabase.')
                  : 'Session error logs cleared.',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  Future<void> _restoreLogHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('dev_error_logs_cleared_at');
    } catch (_) {}
    if (mounted) {
      setState(() {
        _clearedAt = null;
      });
      _fetchDbErrors();
    }
  }

  void _copyLogToClipboard(AppErrorLog log) {
    final text = '''
=== ${log.id} ===
Timestamp : ${log.timestamp.toLocal()}
Severity  : ${log.severityLabel}
Source    : ${log.source}
Message   : ${log.message}
${log.stackTrace != null ? '\nStack Trace:\n${log.stackTrace}' : ''}
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: DeveloperTheme.accentEmerald,
        content: Text(
          'Log ${log.id} copied to clipboard.',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildSeverityBar(),
          if (_clearedAt != null) ...[
            const SizedBox(height: 12),
            _buildClearedNoticeBanner(),
          ],
          const SizedBox(height: 20),
          _buildFiltersRow(),
          const SizedBox(height: 16),
          _buildMainContent(),
          const SizedBox(height: 28),
          _buildDbErrorsSection(),
        ],
      ),
    );
  }

  Widget _buildClearedNoticeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DeveloperTheme.accentCyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DeveloperTheme.accentCyan.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sensors_rounded, size: 16, color: DeveloperTheme.accentCyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Session logs cleared. Live monitoring is active for incoming runtime events.',
              style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: DeveloperTheme.accentCyan,
              side: const BorderSide(color: DeveloperTheme.accentCyan),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _restoreLogHistory,
            icon: const Icon(Icons.history_rounded, size: 14),
            label: Text(
              'View All Logs',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Runtime Error Log Viewer', style: DeveloperTheme.headingLarge()),
            const SizedBox(height: 4),
            Text(
              'In-memory Flutter errors, exceptions, and system-level warnings',
              style: DeveloperTheme.bodySmall(),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: DeveloperTheme.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DeveloperTheme.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sync_rounded,
                    size: 14,
                    color: _autoRefresh
                        ? DeveloperTheme.accentEmerald
                        : DeveloperTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Auto-Refresh',
                    style: DeveloperTheme.bodySmall(
                      color: _autoRefresh
                          ? DeveloperTheme.textPrimary
                          : DeveloperTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: _autoRefresh,
                    onChanged: (v) {
                      setState(() => _autoRefresh = v);
                      if (v) {
                        _refreshTimer = Timer.periodic(
                          const Duration(seconds: 10),
                          (_) => _fetchDbErrors(),
                        );
                      } else {
                        _refreshTimer?.cancel();
                      }
                    },
                    activeThumbColor: DeveloperTheme.accentEmerald,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Clear Logs button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: DeveloperTheme.accentRose,
                side: const BorderSide(color: DeveloperTheme.accentRose),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: _allLogs.isEmpty ? null : _clearAll,
              icon: const Icon(Icons.delete_sweep_rounded, size: 15),
              label: const Text('Clear Logs'),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'TEST / DEV TOOL: Nagpapadala ng fake error entry para ma-verify\nkung gumagana ang pipeline mula app papuntang Supabase at viewer.',
              preferBelow: true,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: DeveloperTheme.accentEmerald,
                  side: const BorderSide(color: DeveloperTheme.accentEmerald),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                ),
                onPressed: _showSimulateDialog,
                child: const Icon(Icons.science_rounded, size: 15),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showSimulateDialog() {
    ErrorSeverity? _selected;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: DeveloperTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: DeveloperTheme.borderSubtle),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DEV TOOL badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DeveloperTheme.accentEmerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: DeveloperTheme.accentEmerald.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_rounded, size: 13, color: DeveloperTheme.accentEmerald),
                    const SizedBox(width: 6),
                    Text(
                      'DEV / TESTING TOOL ONLY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: DeveloperTheme.accentEmerald,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text('Simulate Test Log', style: DeveloperTheme.headingMedium()),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Purpose explanation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DeveloperTheme.bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DeveloperTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Para saan ito?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: DeveloperTheme.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nagpapadala ng FAKE error entry para ma-verify na gumagana ang buong logging pipeline:',
                      style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    _PipelineStep(icon: Icons.phone_android_rounded, label: 'App (Flutter)', color: DeveloperTheme.accentIndigo),
                    _PipelineStep(icon: Icons.arrow_downward_rounded, label: '', color: DeveloperTheme.textMuted, isArrow: true),
                    _PipelineStep(icon: Icons.storage_rounded, label: 'Supabase DB (error_logs table)', color: DeveloperTheme.accentEmerald),
                    _PipelineStep(icon: Icons.arrow_downward_rounded, label: '', color: DeveloperTheme.textMuted, isArrow: true),
                    _PipelineStep(icon: Icons.monitor_rounded, label: 'Real-time stream → Log Viewer', color: DeveloperTheme.accentAmber),
                    const SizedBox(height: 8),
                    Text(
                      '⚠️ Hindi ito tunay na error. Para lang sa testing at verification ng pipeline.',
                      style: DeveloperTheme.bodySmall(color: DeveloperTheme.accentAmber),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Piliin ang severity ng test log:',
                style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              // Severity selector
              Row(
                children: [
                  _SeverityChip(
                    label: 'Warning',
                    color: DeveloperTheme.accentAmber,
                    selected: _selected == ErrorSeverity.warning,
                    onTap: () => setDialogState(() => _selected = ErrorSeverity.warning),
                  ),
                  const SizedBox(width: 8),
                  _SeverityChip(
                    label: 'Error',
                    color: const Color(0xFFFC8181),
                    selected: _selected == ErrorSeverity.error,
                    onTap: () => setDialogState(() => _selected = ErrorSeverity.error),
                  ),
                  const SizedBox(width: 8),
                  _SeverityChip(
                    label: 'Critical',
                    color: DeveloperTheme.accentRose,
                    selected: _selected == ErrorSeverity.critical,
                    onTap: () => setDialogState(() => _selected = ErrorSeverity.critical),
                  ),
                ],
              ),
              if (_selected != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: DeveloperTheme.accentRose.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: DeveloperTheme.accentRose.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: DeveloperTheme.accentAmber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ito ay magdadagdag ng FAKE log entry sa database. Press "Confirm & Send" para ituloy.',
                          style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
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
              child: Text('Cancel', style: TextStyle(color: DeveloperTheme.textMuted)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selected == null
                    ? DeveloperTheme.borderSubtle
                    : DeveloperTheme.accentEmerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _selected == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      switch (_selected!) {
                        case ErrorSeverity.warning:
                          AppLogger.warning(
                            module: 'SIMULATOR',
                            message: 'Test Warning: Inventory stock threshold reached for ingredient.',
                          );
                          break;
                        case ErrorSeverity.error:
                          AppLogger.error(
                            module: 'SIMULATOR',
                            message: 'Test Error: Payment gateway response timed out (HTTP 504).',
                            error: 'TimeoutException: Request exceeded 10000ms',
                          );
                          break;
                        case ErrorSeverity.critical:
                          AppLogger.critical(
                            module: 'SIMULATOR',
                            message: 'Test Critical: Database lock detected during settlement.',
                            error: 'PostgresException: deadlock detected on transaction table',
                          );
                          break;
                        default:
                          break;
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: DeveloperTheme.bgCard,
                            behavior: SnackBarBehavior.floating,
                            content: Row(
                              children: [
                                Icon(Icons.science_rounded, size: 16, color: DeveloperTheme.accentEmerald),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Test log dispatched: ${_selected!.name.toUpperCase()} (Testing pipeline only)',
                                    style: TextStyle(color: DeveloperTheme.textPrimary, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Confirm & Send'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityBar() {
    final counts = _severityCounts;
    final total = _allLogs.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DeveloperTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DeveloperTheme.borderSubtle),
      ),
      child: Row(
        children: [
          _buildSeverityChip(null, 'All', total, DeveloperTheme.textSecondary, Icons.list_alt_rounded),
          const SizedBox(width: 8),
          _buildSeverityChip(ErrorSeverity.critical, 'Critical', counts[ErrorSeverity.critical] ?? 0, DeveloperTheme.accentRose, Icons.dangerous_rounded),
          const SizedBox(width: 8),
          _buildSeverityChip(ErrorSeverity.error, 'Error', counts[ErrorSeverity.error] ?? 0, const Color(0xFFFC8181), Icons.error_rounded),
          const SizedBox(width: 8),
          _buildSeverityChip(ErrorSeverity.warning, 'Warning', counts[ErrorSeverity.warning] ?? 0, DeveloperTheme.accentAmber, Icons.warning_rounded),
          const SizedBox(width: 8),
          _buildSeverityChip(ErrorSeverity.info, 'Info', counts[ErrorSeverity.info] ?? 0, DeveloperTheme.accentCyan, Icons.info_rounded),
        ],
      ),
    );
  }

  Widget _buildSeverityChip(ErrorSeverity? severity, String label, int count, Color color, IconData icon) {
    final isSelected = _severityFilter == severity;
    return GestureDetector(
      onTap: () {
        setState(() {
          _severityFilter = isSelected ? null : severity;
          _applyFilters();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : DeveloperTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.6) : DeveloperTheme.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: DeveloperTheme.bodySmall(color: isSelected ? DeveloperTheme.textPrimary : DeveloperTheme.textSecondary)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$count',
                style: DeveloperTheme.monoText(fontSize: 11, color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: DeveloperTheme.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DeveloperTheme.borderSubtle),
            ),
            child: TextField(
              controller: _searchController,
              style: DeveloperTheme.monoText(fontSize: 13, color: DeveloperTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search logs by message, source, or ID...',
                hintStyle: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: DeveloperTheme.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _applyFilters();
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: DeveloperTheme.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DeveloperTheme.borderSubtle),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _availableSources.contains(_sourceFilter) ? _sourceFilter : 'All Sources',
                dropdownColor: DeveloperTheme.bgCard,
                style: DeveloperTheme.bodySmall(color: DeveloperTheme.textPrimary),
                items: _availableSources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _sourceFilter = v;
                      _applyFilters();
                    });
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: DeveloperTheme.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: DeveloperTheme.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.format_list_numbered_rounded, size: 14, color: DeveloperTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                '${_filteredLogs.length} / ${_allLogs.length} logs',
                style: DeveloperTheme.monoText(fontSize: 12, color: DeveloperTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    final totalItems = _filteredLogs.length;
    final totalPages = (totalItems / _pageSize).ceil().clamp(1, 99999);
    final currentPage = _runtimePage.clamp(1, totalPages);
    final startIndex = totalItems == 0 ? 0 : (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize > totalItems) ? totalItems : startIndex + _pageSize;
    final paginatedLogs = totalItems == 0 ? <AppErrorLog>[] : _filteredLogs.sublist(startIndex, endIndex);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 560),
            decoration: DeveloperTheme.cardDecoration(),
            child: _filteredLogs.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: paginatedLogs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, index) => _buildLogRow(paginatedLogs[index]),
                        ),
                      ),
                      const Divider(height: 1, color: DeveloperTheme.borderSubtle),
                      _buildPaginationFooter(
                        totalItems: totalItems,
                        startIndex: totalItems == 0 ? 0 : startIndex + 1,
                        endIndex: endIndex,
                        currentPage: currentPage,
                        totalPages: totalPages,
                        itemLabel: 'logs',
                        onPageChanged: (p) => setState(() => _runtimePage = p),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 560),
            decoration: DeveloperTheme.cardDecoration(),
            child: _selectedLog == null ? _buildDetailPlaceholder() : _buildDetailPanel(_selectedLog!),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 48, color: DeveloperTheme.accentEmerald.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('No logs match your filters', style: DeveloperTheme.headingMedium(color: DeveloperTheme.textSecondary)),
          const SizedBox(height: 4),
          Text('System appears clean — no errors captured in memory.', style: DeveloperTheme.bodySmall()),
        ],
      ),
    );
  }

  Widget _buildDetailPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_rounded, size: 40, color: DeveloperTheme.accentIndigo.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('Select a log entry', style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted)),
          const SizedBox(height: 4),
          Text(
            'Click any log row to inspect details\nand stack traces.',
            textAlign: TextAlign.center,
            style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildLogRow(AppErrorLog log) {
    final isSelected = _selectedLog?.id == log.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedLog = log),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? log.severityColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? log.severityColor.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: log.severityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(log.severityIcon, size: 14, color: log.severityColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: log.severityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.severityLabel,
                          style: DeveloperTheme.monoText(fontSize: 9, color: log.severityColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(log.source, style: DeveloperTheme.monoText(fontSize: 10, color: DeveloperTheme.accentCyan)),
                      const Spacer(),
                      Text(_formatTime(log.timestamp), style: DeveloperTheme.monoText(fontSize: 10, color: DeveloperTheme.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DeveloperTheme.monoText(fontSize: 11, color: DeveloperTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(log.id, style: DeveloperTheme.monoText(fontSize: 10, color: DeveloperTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel(AppErrorLog log) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: DeveloperTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              Icon(log.severityIcon, size: 16, color: log.severityColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.id,
                  style: DeveloperTheme.monoText(fontSize: 13, color: log.severityColor, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: DeveloperTheme.textSecondary),
                tooltip: 'Copy to clipboard',
                onPressed: () => _copyLogToClipboard(log),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: DeveloperTheme.textMuted),
                onPressed: () => setState(() => _selectedLog = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailField('Timestamp', log.timestamp.toLocal().toString()),
                _buildDetailField('Severity', log.severityLabel),
                _buildDetailField('Source', log.source),
                const SizedBox(height: 10),
                _buildCodeBlock('Message', log.message),
                if (log.stackTrace != null) ...[
                  const SizedBox(height: 12),
                  _buildCodeBlock('Stack Trace', log.stackTrace!),
                ],
                if (log.context.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildCodeBlock('Context', log.context.entries.map((e) => '${e.key}: ${e.value}').join('\n')),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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

  Widget _buildCodeBlock(String label, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DeveloperTheme.bgDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: DeveloperTheme.borderSubtle),
          ),
          child: SelectableText(
            content,
            style: DeveloperTheme.monoText(fontSize: 11, color: DeveloperTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildDbErrorsSection() {
    final totalItems = _dbErrors.length;
    final totalPages = (totalItems / _pageSize).ceil().clamp(1, 99999);
    final currentPage = _dbPage.clamp(1, totalPages);
    final startIndex = totalItems == 0 ? 0 : (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize > totalItems) ? totalItems : startIndex + _pageSize;
    final paginatedDbErrors = totalItems == 0 ? <Map<String, dynamic>>[] : _dbErrors.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.storage, size: 18, color: DeveloperTheme.accentAmber),
            const SizedBox(width: 8),
            Text('Database-Level Error Activity', style: DeveloperTheme.headingMedium()),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: DeveloperTheme.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('From Audit Logs', style: DeveloperTheme.monoText(fontSize: 10, color: DeveloperTheme.accentAmber)),
            ),
            const Spacer(),
            if (_loadingDbErrors)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: DeveloperTheme.accentAmber),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18, color: DeveloperTheme.textSecondary),
                onPressed: () {
                  setState(() => _dbPage = 1);
                  _fetchDbErrors();
                },
                tooltip: 'Refresh DB Errors',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: DeveloperTheme.cardDecoration(),
          child: _dbErrors.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 20, color: DeveloperTheme.accentEmerald),
                      const SizedBox(width: 12),
                      Text(
                        'No error-level entries detected in recent audit trail.',
                        style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: paginatedDbErrors.length,
                      separatorBuilder: (_, __) => const Divider(color: DeveloperTheme.borderSubtle, height: 12),
                      itemBuilder: (ctx, i) => _buildDbErrorRow(paginatedDbErrors[i]),
                    ),
                    const Divider(height: 1, color: DeveloperTheme.borderSubtle),
                    _buildPaginationFooter(
                      totalItems: totalItems,
                      startIndex: totalItems == 0 ? 0 : startIndex + 1,
                      endIndex: endIndex,
                      currentPage: currentPage,
                      totalPages: totalPages,
                      itemLabel: 'entries',
                      onPageChanged: (p) => setState(() => _dbPage = p),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDbErrorRow(Map<String, dynamic> e) {
    final action = e['action']?.toString() ?? '';
    final isError = action == 'ERROR' || action == 'FAILED' || action == 'SYSTEM_ERROR';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isError
                  ? DeveloperTheme.accentRose.withValues(alpha: 0.15)
                  : DeveloperTheme.accentAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isError ? Icons.error_rounded : Icons.warning_rounded,
              size: 14,
              color: isError ? DeveloperTheme.accentRose : DeveloperTheme.accentAmber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isError
                            ? DeveloperTheme.accentRose.withValues(alpha: 0.15)
                            : DeveloperTheme.accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        action,
                        style: DeveloperTheme.monoText(
                          fontSize: 10,
                          color: isError ? DeveloperTheme.accentRose : DeveloperTheme.accentAmber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(e['module']?.toString() ?? 'Unknown Module', style: DeveloperTheme.monoText(fontSize: 11, color: DeveloperTheme.accentCyan)),
                    const Spacer(),
                    Text(e['user_email']?.toString() ?? '', style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  e['description']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DeveloperTheme.monoText(fontSize: 11, color: DeveloperTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatTime(DateTime.tryParse(e['created_at']?.toString() ?? '') ?? DateTime.now()),
            style: DeveloperTheme.monoText(fontSize: 10, color: DeveloperTheme.textMuted),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildPaginationFooter({
    required int totalItems,
    required int startIndex,
    required int endIndex,
    required int currentPage,
    required int totalPages,
    required String itemLabel,
    required ValueChanged<int> onPageChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: DeveloperTheme.bgDark,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 560;
          final infoText = Text(
            totalItems == 0
                ? '0 $itemLabel'
                : 'Showing $startIndex–$endIndex of $totalItems $itemLabel',
            style: DeveloperTheme.monoText(
              fontSize: 12,
              color: DeveloperTheme.textSecondary,
            ),
          );

          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 20),
                tooltip: 'First Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
                color: DeveloperTheme.accentIndigo,
                disabledColor: DeveloperTheme.textMuted.withValues(alpha: 0.3),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                color: DeveloperTheme.accentIndigo,
                disabledColor: DeveloperTheme.textMuted.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: DeveloperTheme.bgCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: DeveloperTheme.borderSubtle),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: DeveloperTheme.monoText(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: DeveloperTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                color: DeveloperTheme.accentIndigo,
                disabledColor: DeveloperTheme.textMuted.withValues(alpha: 0.3),
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 20),
                tooltip: 'Last Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage < totalPages ? () => onPageChanged(totalPages) : null,
                color: DeveloperTheme.accentIndigo,
                disabledColor: DeveloperTheme.textMuted.withValues(alpha: 0.3),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                infoText,
                const SizedBox(height: 8),
                controls,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              infoText,
              controls,
            ],
          );
        },
      ),
    );
  }
}

// ─── Helper widgets for the Simulate Log dialog ───────────────────────────────

class _PipelineStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isArrow;

  const _PipelineStep({
    required this.icon,
    required this.label,
    required this.color,
    this.isArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isArrow) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Icon(icon, size: 14, color: color),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SeverityChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.35),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : color.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
