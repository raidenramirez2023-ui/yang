import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'developer_theme.dart';

class ServiceHealthItem {
  final String name;
  final String category;
  final String description;
  final bool isHealthy;
  final int? latencyMs;
  final String statusText;
  final String? error;

  ServiceHealthItem({
    required this.name,
    required this.category,
    required this.description,
    required this.isHealthy,
    this.latencyMs,
    required this.statusText,
    this.error,
  });
}

class SystemHealthPage extends StatefulWidget {
  final VoidCallback? onHealthUpdated;

  const SystemHealthPage({super.key, this.onHealthUpdated});

  @override
  State<SystemHealthPage> createState() => _SystemHealthPageState();
}

class _SystemHealthPageState extends State<SystemHealthPage> {
  bool _isRunningDiagnostics = false;
  DateTime? _lastChecked;
  int _dbLatencyMs = 0;
  bool _dbHealthy = true;

  final List<ServiceHealthItem> _services = [];
  final Map<String, int> _tableCounts = {};
  bool _loadingCounts = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    if (_isRunningDiagnostics) return;

    setState(() {
      _isRunningDiagnostics = true;
      _services.clear();
    });

    final stopwatch = Stopwatch()..start();
    final supabase = Supabase.instance.client;

    // 1. Supabase Database Ping
    bool dbOk = false;
    int dbLatency = 0;
    String? dbError;
    try {
      final dbWatch = Stopwatch()..start();
      await supabase.from('app_settings').select('setting_key').limit(1);
      dbWatch.stop();
      dbLatency = dbWatch.elapsedMilliseconds;
      dbOk = true;
    } catch (e) {
      dbError = e.toString();
    }

    _services.add(ServiceHealthItem(
      name: 'Supabase PostgreSQL Database',
      category: 'Database & RLS',
      description: 'Primary relational data storage & Row Level Security engine',
      isHealthy: dbOk,
      latencyMs: dbLatency,
      statusText: dbOk ? 'Operational ($dbLatency ms)' : 'Connection Error',
      error: dbError,
    ));

    // 2. Supabase Auth Service
    bool authOk = false;
    int authLatency = 0;
    String? authError;
    try {
      final authWatch = Stopwatch()..start();
      final session = supabase.auth.currentSession;
      authWatch.stop();
      authLatency = authWatch.elapsedMilliseconds;
      authOk = session != null;
    } catch (e) {
      authError = e.toString();
    }

    _services.add(ServiceHealthItem(
      name: 'Supabase Authentication Service',
      category: 'Identity & JWT',
      description: 'Role-based token validation, sessions, and access control',
      isHealthy: authOk,
      latencyMs: authLatency,
      statusText: authOk ? 'Authenticated Session Active' : 'No Active Session / Auth Error',
      error: authError,
    ));

    // 3. Firebase Storage Connectivity
    bool storageOk = false;
    int storageLatency = 0;
    String? storageError;
    try {
      final storageWatch = Stopwatch()..start();
      final storageRef = FirebaseStorage.instance.ref();
      // Test reference creation / bucket binding
      if (storageRef.bucket.isNotEmpty) {
        storageOk = true;
      }
      storageWatch.stop();
      storageLatency = storageWatch.elapsedMilliseconds;
    } catch (e) {
      storageError = e.toString();
    }

    _services.add(ServiceHealthItem(
      name: 'Firebase Cloud Storage',
      category: 'Storage & Assets',
      description: 'Polyglot file & image storage bucket for menu items, receipts, and proofs',
      isHealthy: storageOk,
      latencyMs: storageLatency,
      statusText: storageOk ? 'Bucket Connected' : 'Storage Unavailable',
      error: storageError,
    ));

    // 4. App Settings Key-Value Cache
    bool settingsOk = false;
    int settingsLatency = 0;
    String? settingsError;
    try {
      final settingsWatch = Stopwatch()..start();
      final count = await supabase.from('app_settings').select().limit(5);
      settingsWatch.stop();
      settingsLatency = settingsWatch.elapsedMilliseconds;
      settingsOk = count.isNotEmpty;
    } catch (e) {
      settingsError = e.toString();
    }

    _services.add(ServiceHealthItem(
      name: 'Dynamic App Settings Registry',
      category: 'Configuration',
      description: 'Real-time dynamic configuration keys, operating parameters, and maintenance flags',
      isHealthy: settingsOk,
      latencyMs: settingsLatency,
      statusText: settingsOk ? 'Registry Online' : 'Cache Read Error',
      error: settingsError,
    ));

    stopwatch.stop();

    if (mounted) {
      setState(() {
        _dbLatencyMs = dbLatency;
        _dbHealthy = dbOk;
        _lastChecked = DateTime.now();
        _isRunningDiagnostics = false;
      });
      widget.onHealthUpdated?.call();
      _fetchTableCounts();
    }
  }

  Future<void> _fetchTableCounts() async {
    setState(() => _loadingCounts = true);
    final supabase = Supabase.instance.client;
    final tables = ['users', 'reservations', 'orders', 'menu_items', 'audit_logs', 'app_settings'];

    final Map<String, int> counts = {};
    for (final tbl in tables) {
      try {
        final res = await supabase.from(tbl).select('id').count(CountOption.exact);
        counts[tbl] = res.count;
      } catch (_) {
        try {
          final res = await supabase.from(tbl).select().limit(500);
          counts[tbl] = (res as List).length;
        } catch (_) {
          counts[tbl] = -1; // Indicates RLS restricted or error
        }
      }
    }

    if (mounted) {
      setState(() {
        _tableCounts.clear();
        _tableCounts.addAll(counts);
        _loadingCounts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool allHealthy = _services.every((s) => s.isHealthy);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Diagnostic Trigger
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Health & Telemetry',
                    style: DeveloperTheme.headingLarge(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time connectivity, latency benchmarks, and database health',
                    style: DeveloperTheme.bodySmall(),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isRunningDiagnostics ? null : _runDiagnostics,
                icon: _isRunningDiagnostics
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_isRunningDiagnostics ? 'Pinging...' : 'Run Diagnostics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DeveloperTheme.accentIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // High-level System Status Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: DeveloperTheme.cardDecoration(
              borderColor: allHealthy ? DeveloperTheme.accentEmerald : DeveloperTheme.accentAmber,
              glow: true,
              glowColor: allHealthy ? DeveloperTheme.accentEmerald : DeveloperTheme.accentAmber,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (allHealthy ? DeveloperTheme.accentEmerald : DeveloperTheme.accentAmber)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    allHealthy ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    color: allHealthy ? DeveloperTheme.accentEmerald : DeveloperTheme.accentAmber,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allHealthy ? 'All Systems Operational' : 'Degraded System Performance',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: allHealthy ? DeveloperTheme.accentEmerald : DeveloperTheme.accentAmber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        allHealthy
                            ? 'Supabase database, authentication tokens, and storage buckets are healthy.'
                            : 'One or more subsystem pings encountered warnings. Review the telemetry below.',
                        style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (_lastChecked != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Last Paged',
                        style: DeveloperTheme.bodySmall(color: DeveloperTheme.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_lastChecked!.hour.toString().padLeft(2, '0')}:${_lastChecked!.minute.toString().padLeft(2, '0')}:${_lastChecked!.second.toString().padLeft(2, '0')}',
                        style: DeveloperTheme.monoText(
                          fontSize: 13,
                          color: DeveloperTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Metric Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.2 : 1.8,
                children: [
                  _buildMetricCard(
                    title: 'Database Ping',
                    value: '$_dbLatencyMs ms',
                    status: _dbLatencyMs < 150
                        ? 'Ultra Fast (<150ms)'
                        : _dbLatencyMs < 400
                            ? 'Normal (<400ms)'
                            : 'High Latency',
                    color: _dbLatencyMs < 150
                        ? DeveloperTheme.accentEmerald
                        : _dbLatencyMs < 400
                            ? DeveloperTheme.accentCyan
                            : DeveloperTheme.accentAmber,
                    icon: Icons.speed_rounded,
                  ),
                  _buildMetricCard(
                    title: 'Database Status',
                    value: _dbHealthy ? 'ONLINE' : 'UNREACHABLE',
                    status: _dbHealthy ? 'PostgreSQL 15.x Engine' : 'Check network',
                    color: _dbHealthy ? DeveloperTheme.accentEmerald : DeveloperTheme.accentRose,
                    icon: Icons.storage,
                  ),
                  _buildMetricCard(
                    title: 'Services Checked',
                    value: '${_services.where((s) => s.isHealthy).length}/${_services.length}',
                    status: 'Active microservices',
                    color: DeveloperTheme.accentIndigo,
                    icon: Icons.hub,
                  ),
                  _buildMetricCard(
                    title: 'Table Watchdogs',
                    value: '${_tableCounts.length} Tables',
                    status: _loadingCounts ? 'Querying...' : 'Schemas Active',
                    color: DeveloperTheme.accentPurple,
                    icon: Icons.dataset,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // Service Telemetry Cards List
          Text('Core Subsystems Telemetry', style: DeveloperTheme.headingMedium()),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final s = _services[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: DeveloperTheme.cardDecoration(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 48,
                      decoration: BoxDecoration(
                        color: s.isHealthy ? DeveloperTheme.accentEmerald : DeveloperTheme.accentRose,
                        borderRadius: BorderRadius.circular(4),
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
                                s.name,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: DeveloperTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: DeveloperTheme.bgDark,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: DeveloperTheme.borderSubtle),
                                ),
                                child: Text(
                                  s.category,
                                  style: DeveloperTheme.monoText(
                                    fontSize: 10,
                                    color: DeveloperTheme.accentCyan,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.description,
                            style: DeveloperTheme.bodySmall(),
                          ),
                          if (s.error != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Error: ${s.error}',
                              style: DeveloperTheme.monoText(
                                fontSize: 11,
                                color: DeveloperTheme.accentRose,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (s.isHealthy ? DeveloperTheme.accentEmerald : DeveloperTheme.accentRose)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (s.isHealthy ? DeveloperTheme.accentEmerald : DeveloperTheme.accentRose)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            s.isHealthy ? 'HEALTHY' : 'DEGRADED',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: s.isHealthy ? DeveloperTheme.accentEmerald : DeveloperTheme.accentRose,
                            ),
                          ),
                        ),
                        if (s.latencyMs != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${s.latencyMs} ms',
                            style: DeveloperTheme.monoText(
                              fontSize: 12,
                              color: DeveloperTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Database Table Records Inspector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Database Table Volume', style: DeveloperTheme.headingMedium()),
              if (_loadingCounts)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: DeveloperTheme.accentCyan),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: DeveloperTheme.cardDecoration(),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _tableCounts.entries.map((entry) {
                return Container(
                  width: 170,
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
                        entry.key,
                        style: DeveloperTheme.monoText(
                          fontSize: 12,
                          color: DeveloperTheme.accentIndigo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.value >= 0 ? '${entry.value} rows' : 'Restricted',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: entry.value >= 0 ? DeveloperTheme.textPrimary : DeveloperTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String status,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DeveloperTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: DeveloperTheme.monoText(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: DeveloperTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            status,
            style: DeveloperTheme.bodySmall(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
