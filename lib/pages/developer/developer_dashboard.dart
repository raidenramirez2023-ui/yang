import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/app_settings_service.dart';
import '../../services/audit_log_service.dart';
import 'developer_theme.dart';
import 'backup_restore_page.dart';
import 'system_health_page.dart';
import 'audit_logs_page.dart';
import 'security_events_page.dart';
import 'maintenance_mode_page.dart';
import 'user_monitoring_page.dart';
import 'error_log_viewer_page.dart';
import '../../utils/url_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/it_access_service.dart';

class DeveloperDashboardPage extends StatefulWidget {
  final int initialIndex;

  const DeveloperDashboardPage({super.key, this.initialIndex = 0});

  @override
  State<DeveloperDashboardPage> createState() => _DeveloperDashboardPageState();
}

class _DeveloperDashboardPageState extends State<DeveloperDashboardPage> {
  late int _selectedIndex;
  final AppSettingsService _settings = AppSettingsService();

  // Maps each tab index to its named route (mirrors main.dart developer routes)
  static const _indexToRoute = [
    '/developer/dashboard',   // 0 – System Overview
    '/developer/health',      // 1 – System Health & Status
    '/developer/audit-logs',  // 2 – Audit Logs
    '/developer/security',    // 3 – Security Events
    '/developer/users',       // 4 – User & Role Monitoring
    '/developer/maintenance',  // 5 – Maintenance Mode
    '/developer/backup',      // 6 – Backup Status
    '/developer/info',        // 7 – System Information
    '/developer/error-logs',  // 8 – Error Log Viewer
  ];

  int _latencyMs = 0;
  bool _isMaintenanceActive = false;
  Timer? _latencyTimer;
  Timer? _itAccessPollTimer;
  String _developerEmail = 'Developer';
  String _appName = 'Yang Chow Pagsanjan Restaurant Management System (YCPRMS)';
  String _appVersion = '1.0.0+20';
  List<Map<String, dynamic>> _pendingItRequests = [];
  Map<String, dynamic>? _activeItRequest;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _developerEmail = Supabase.instance.client.auth.currentUser?.email ?? 'developer@yangchow.com';
    _loadAppVersion();
    _checkSystemPulse();
    _loadItAccessRequests();
    // Periodically update latency and maintenance status
    _latencyTimer = Timer.periodic(const Duration(seconds: 45), (_) => _checkSystemPulse());
    // Poll for IT access requests every 30 seconds
    _itAccessPollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadItAccessRequests());
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final ver = info.version;
      final build = info.buildNumber;
      final name = info.appName.trim();
      if (mounted) {
        setState(() {
          if (ver.isNotEmpty) {
            _appVersion = build.isNotEmpty ? '$ver+$build' : ver;
          }
          if (name.isNotEmpty) {
            _appName = 'Yang Chow Pagsanjan Restaurant Management System ($name)';
          }
        });
      }
    } catch (e) {
      debugPrint('[DeveloperDashboard] Error loading package version: $e');
    }
  }

  @override
  void dispose() {
    _latencyTimer?.cancel();
    _itAccessPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadItAccessRequests() async {
    try {
      final pending = await ItAccessService.getPendingRequests();
      final active = await ItAccessService.getActiveRequest();
      if (mounted) {
        setState(() {
          _pendingItRequests = pending;
          _activeItRequest = active;
        });
      }
    } catch (e) {
      debugPrint('[DevDashboard] Error loading IT access requests: $e');
    }
  }

  Future<void> _acceptItRequest(Map<String, dynamic> request) async {
    final id = request['id']?.toString() ?? '';
    final duration = (request['duration_hours'] as int?) ?? 2;
    final ok = await ItAccessService.acceptRequest(id, duration);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '✅ Access granted for ${duration}h. Auto-expires at ${DateTime.now().add(Duration(hours: duration)).toLocal().toString().substring(11, 16)}.'
            : '❌ Failed to accept request.'),
        backgroundColor: ok ? const Color(0xFF16A34A) : const Color(0xFFB45309),
        behavior: SnackBarBehavior.floating,
      ));
      _loadItAccessRequests();
    }
  }

  Future<void> _declineItRequest(Map<String, dynamic> request) async {
    final id = request['id']?.toString() ?? '';
    final ok = await ItAccessService.declineRequest(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Request declined.' : '❌ Failed to decline request.'),
        backgroundColor: ok ? const Color(0xFF475569) : const Color(0xFFB45309),
        behavior: SnackBarBehavior.floating,
      ));
      _loadItAccessRequests();
    }
  }

  Future<void> _checkSystemPulse() async {
    try {
      final watch = Stopwatch()..start();
      await Supabase.instance.client.from('app_settings').select('setting_key').limit(1);
      watch.stop();

      final maintenance = _settings.isMaintenanceModeEnabled();

      if (mounted) {
        setState(() {
          _latencyMs = watch.elapsedMilliseconds;
          _isMaintenanceActive = maintenance;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _latencyMs = -1);
      }
    }
  }

  /// Silently updates the browser address bar URL using the History API.
  /// This avoids triggering Flutter's router (no page rebuild / no AuthGuard reload).
  void _updateBrowserUrl(String path) => pushUrlState(path);

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: DeveloperTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: DeveloperTheme.borderSubtle),
          ),
          title: Text('Sign Out Developer Console', style: DeveloperTheme.headingMedium()),
          content: Text(
            'Are you sure you want to end your developer session?',
            style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DeveloperTheme.accentRose,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await AuditLogService.logActivity(
          action: 'LOGOUT',
          module: 'Auth',
          description: 'Developer signed out: $_developerEmail',
          customUserEmail: _developerEmail,
          customUserRole: 'DEVELOPER',
        );
      } catch (_) {}
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/developer/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeveloperTheme.bgDark,
      body: Row(
        children: [
          // Developer Navigation Sidebar
          _buildSidebar(),

          // Main View Container
          Expanded(
            child: Column(
              children: [
                _buildTopAppBar(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      _buildOverviewTab(),
                      SystemHealthPage(onHealthUpdated: _checkSystemPulse),
                      const DeveloperAuditLogsPage(),
                      const SecurityEventsPage(),
                      const UserMonitoringPage(),
                      MaintenanceModePage(onMaintenanceChanged: _checkSystemPulse),
                      const BackupRestorePage(),
                      _buildSystemInfoTab(),
                      const ErrorLogViewerPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: DeveloperTheme.bgSurface,
        border: Border(bottom: BorderSide(color: DeveloperTheme.borderSubtle)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Status Chips
          Row(
            children: [
              // Operational Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (_isMaintenanceActive ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (_isMaintenanceActive ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isMaintenanceActive ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isMaintenanceActive ? 'MAINTENANCE MODE' : 'SYSTEM HEALTHY',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _isMaintenanceActive ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Ping Latency
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: DeveloperTheme.bgDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: DeveloperTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_rounded, size: 14, color: DeveloperTheme.accentCyan),
                    const SizedBox(width: 6),
                    Text(
                      _latencyMs >= 0 ? '$_latencyMs ms latency' : 'Offline',
                      style: DeveloperTheme.monoText(
                        fontSize: 11,
                        color: DeveloperTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // User Profile & Logout
          Row(
            children: [
              IconButton(
                onPressed: _checkSystemPulse,
                icon: const Icon(Icons.refresh_rounded, size: 18, color: DeveloperTheme.textSecondary),
                tooltip: 'Refresh Telemetry',
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: DeveloperTheme.bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DeveloperTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: DeveloperTheme.accentIndigo.withValues(alpha: 0.2),
                      child: const Icon(Icons.terminal, size: 14, color: DeveloperTheme.accentIndigo),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _developerEmail,
                      style: DeveloperTheme.monoText(fontSize: 12, color: DeveloperTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout_rounded, size: 20, color: DeveloperTheme.accentRose),
                tooltip: 'Sign Out',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: DeveloperTheme.bgSurface,
        border: Border(right: BorderSide(color: DeveloperTheme.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DeveloperTheme.accentIndigo.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: DeveloperTheme.accentIndigo.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(
                    Icons.terminal,
                    color: DeveloperTheme.accentIndigo,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yang Chow IT',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: DeveloperTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Developer Console',
                      style: DeveloperTheme.monoText(
                        fontSize: 10,
                        color: DeveloperTheme.accentCyan,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: DeveloperTheme.borderSubtle, height: 1),

          // Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              children: [
                _buildNavItem(0, 'System Overview', Icons.dashboard),
                _buildNavItem(1, 'System Health & Status', Icons.health_and_safety),
                _buildNavItem(2, 'Audit Logs', Icons.receipt_long_outlined),
                _buildNavItem(3, 'Security Events', Icons.shield_outlined),
                _buildNavItem(4, 'User & Role Monitoring', Icons.manage_accounts),
                _buildNavItem(5, 'Maintenance Mode', Icons.build_circle),
                _buildNavItem(6, 'Backup Status', Icons.backup),
                _buildNavItem(7, 'System Information', Icons.info_outline_rounded),
                _buildNavItem(8, 'Error Log Viewer', Icons.bug_report),
              ],
            ),
          ),

          // Version Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DeveloperTheme.bgDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DeveloperTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 14, color: DeveloperTheme.accentEmerald),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Role: developer\nEngine: v$_appVersion',
                      style: DeveloperTheme.monoText(fontSize: 10, color: DeveloperTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          if (_selectedIndex == index) return; // already on this tab
          setState(() => _selectedIndex = index);
          // Silently update the URL without triggering a full navigation
          final route = index < _indexToRoute.length
              ? _indexToRoute[index]
              : '/developer/dashboard';
          _updateBrowserUrl(route);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? DeveloperTheme.accentIndigo.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? DeveloperTheme.accentIndigo.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? DeveloperTheme.accentIndigo : DeveloperTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? DeveloperTheme.textPrimary : DeveloperTheme.textSecondary,
                  ),
                ),
              ),
              if (index == 5 && _isMaintenanceActive)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: DeveloperTheme.accentAmber,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Technical Operations Overview', style: DeveloperTheme.headingLarge()),
                  const SizedBox(height: 4),
                  Text(
                    'High-level architecture telemetry, active services, and security health',
                    style: DeveloperTheme.bodySmall(),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => _selectedIndex = 1),
                icon: const Icon(Icons.troubleshoot_rounded, size: 18),
                label: const Text('Diagnostics Center'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DeveloperTheme.accentIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── IT Access Request Notification Panel ──────────────────────────
          if (_activeItRequest != null) ...[  
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34D399).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF34D399), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔓 Elevated Access ACTIVE',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF34D399)),
                        ),
                        Text(
                          'Scope: ${_activeItRequest!['access_scope'] ?? 'Full Access'}  •  ${ItAccessService.getRemainingTimeString(_activeItRequest!)}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6EE7B7)),
                        ),
                        Text(
                          'Issue: ${_activeItRequest!['issue_description'] ?? ''}',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF6EE7B7).withValues(alpha: 0.8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showEndSessionDialog(_activeItRequest!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: Text('End Session', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_pendingItRequests.isNotEmpty) ...[  
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B4B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DeveloperTheme.accentIndigo.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(color: Color(0xFF818CF8), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_pendingItRequests.length} Pending IT Access Request${_pendingItRequests.length > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: DeveloperTheme.accentIndigo),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _loadItAccessRequests,
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: DeveloperTheme.textSecondary),
                        tooltip: 'Refresh',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._pendingItRequests.map((req) {
                    final scope = req['access_scope']?.toString() ?? 'Full Access';
                    final issue = req['issue_description']?.toString() ?? '';
                    final duration = (req['duration_hours'] as int?) ?? 2;
                    final adminName = req['requested_by_name']?.toString() ?? 'Admin';
                    final requestedAt = DateTime.tryParse(req['requested_at'] ?? '');
                    final timeAgo = requestedAt != null
                        ? '${DateTime.now().difference(requestedAt.toLocal()).inMinutes} min ago'
                        : '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: DeveloperTheme.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: DeveloperTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFF818CF8)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '$adminName requests IT access',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: DeveloperTheme.textPrimary),
                                ),
                              ),
                              Text(timeAgo, style: GoogleFonts.inter(fontSize: 11, color: DeveloperTheme.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('🔍 Issue: $issue', style: GoogleFonts.inter(fontSize: 12, color: DeveloperTheme.textSecondary)),
                          Text('🔓 Scope: $scope  •  ⏰ Duration: ${duration}h', style: GoogleFonts.inter(fontSize: 12, color: DeveloperTheme.textMuted)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _declineItRequest(req),
                                style: TextButton.styleFrom(foregroundColor: DeveloperTheme.accentRose, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                child: Text('Decline', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _acceptItRequest(req),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DeveloperTheme.accentEmerald,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.check_circle_rounded, size: 16),
                                label: Text('Accept (${duration}h)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Overview KPI Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.1 : 1.7,
                children: [
                  _buildQuickCard(
                    title: 'System State',
                    value: _isMaintenanceActive ? 'MAINTENANCE' : 'OPERATIONAL',
                    subtitle: _isMaintenanceActive ? 'Technical Mode Active' : 'Normal Operations',
                    color: _isMaintenanceActive ? DeveloperTheme.accentAmber : DeveloperTheme.accentEmerald,
                    icon: Icons.power,
                    onTap: () => setState(() => _selectedIndex = 5),
                  ),
                  _buildQuickCard(
                    title: 'Database Latency',
                    value: '$_latencyMs ms',
                    subtitle: 'PostgreSQL Ping',
                    color: DeveloperTheme.accentCyan,
                    icon: Icons.speed_rounded,
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                  _buildQuickCard(
                    title: 'Security Posture',
                    value: 'VERIFIED',
                    subtitle: 'RLS & Identity Protected',
                    color: DeveloperTheme.accentIndigo,
                    icon: Icons.shield,
                    onTap: () => setState(() => _selectedIndex = 3),
                  ),
                  _buildQuickCard(
                    title: 'Role Access',
                    value: 'ISOLATED',
                    subtitle: 'Admin / IT Separated',
                    color: DeveloperTheme.accentPurple,
                    icon: Icons.fingerprint,
                    onTap: () => setState(() => _selectedIndex = 4),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // Quick Action Launchpad
          Text('Quick Management Launchpad', style: DeveloperTheme.headingMedium()),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  title: 'Toggle Maintenance Mode',
                  desc: 'Activate scheduled technical maintenance or emergency pause',
                  icon: Icons.build_circle,
                  color: DeveloperTheme.accentAmber,
                  onTap: () => setState(() => _selectedIndex = 5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionTile(
                  title: 'Inspect Audit Trail',
                  desc: 'Browse user operations, logs, entity IDs, and CSV export',
                  icon: Icons.receipt_long_outlined,
                  color: DeveloperTheme.accentCyan,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionTile(
                  title: 'Verify Database Backups',
                  desc: 'Inspect tables and trigger structured JSON data exports',
                  icon: Icons.backup,
                  color: DeveloperTheme.accentIndigo,
                  onTap: () => setState(() => _selectedIndex = 6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ─── Portal Access Launchpad ──────────────────────────────────────────
          // Allows the Developer to navigate directly into any portal for testing
          // without typing URLs manually. This bypass works even during Maintenance Mode.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Portal Access Launchpad', style: DeveloperTheme.headingMedium()),
                  const SizedBox(height: 4),
                  Text(
                    'Direct access to all portals for testing and debugging',
                    style: DeveloperTheme.bodySmall(),
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final hasElevated = _activeItRequest != null;
                  final color = _isMaintenanceActive
                      ? DeveloperTheme.accentAmber
                      : (hasElevated ? DeveloperTheme.accentEmerald : const Color(0xFFEF4444));
                  final icon = _isMaintenanceActive
                      ? Icons.build_circle_rounded
                      : (hasElevated ? Icons.verified_user_rounded : Icons.lock_rounded);
                  final text = _isMaintenanceActive
                      ? 'MAINTENANCE ACTIVE — Test Access Unlocked'
                      : (hasElevated
                          ? 'ELEVATED ACCESS ACTIVE — Authorized by Admin'
                          : 'LOCKED — Maintenance or Admin Request Required');

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: color),
                        const SizedBox(width: 6),
                        Text(
                          text,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 600 ? 3 : 2);
              return GridView.count(
                crossAxisCount: crossCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.15,
                children: [
                  _buildPortalCard(
                    label: 'Staff Portal',
                    subtitle: 'POS, orders, tables',
                    icon: Icons.point_of_sale_rounded,
                    color: const Color(0xFFFF6B35),
                    route: '/staff/dashboard',
                  ),
                  _buildPortalCard(
                    label: 'Admin Portal',
                    subtitle: 'Reservations, reports',
                    icon: Icons.admin_panel_settings_rounded,
                    color: DeveloperTheme.accentIndigo,
                    route: '/admin/dashboard',
                  ),
                  _buildPortalCard(
                    label: 'Customer Portal',
                    subtitle: 'Bookings, transactions',
                    icon: Icons.person_rounded,
                    color: DeveloperTheme.accentEmerald,
                    route: '/customer/dashboard',
                  ),
                  _buildPortalCard(
                    label: 'Chef Portal',
                    subtitle: 'Kitchen, menu requests',
                    icon: Icons.restaurant_rounded,
                    color: DeveloperTheme.accentCyan,
                    route: '/chef/dashboard',
                  ),
                  _buildPortalCard(
                    label: 'Inventory Portal',
                    subtitle: 'Stock, storage room',
                    icon: Icons.inventory_2_rounded,
                    color: DeveloperTheme.accentPurple,
                    route: '/inventory/dashboard',
                  ),
                ],
              );
            },
          ),


          const SizedBox(height: 32),

          // Architecture Notice

          Container(
            padding: const EdgeInsets.all(20),
            decoration: DeveloperTheme.cardDecoration(),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: DeveloperTheme.accentCyan, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Architectural Separation: Business Operations vs IT Maintenance',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: DeveloperTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The Developer / IT module handles infrastructure diagnostics, security logs, and maintenance toggles. Business operations (reservations, menu pricing, staff schedules, and refunds) remain strictly inside the Admin and Staff portals.',
                        style: DeveloperTheme.bodySmall(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: DeveloperTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary)),
                Icon(icon, size: 18, color: color),
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
            Text(subtitle, style: DeveloperTheme.bodySmall(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: DeveloperTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: DeveloperTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(desc, style: DeveloperTheme.bodySmall()),
          ],
        ),
      ),
    );
  }



  Widget _buildSystemInfoTab() {
    String storageInfo = 'Firebase Storage Bucket (Polyglot image storage)';
    try {
      if (Firebase.apps.isNotEmpty) {
        final bucket = Firebase.app().options.storageBucket;
        if (bucket != null && bucket.isNotEmpty) {
          storageInfo = 'Firebase Storage ($bucket)';
        }
      }
    } catch (_) {}

    final clientPlatform = kIsWeb
        ? 'Web (${defaultTargetPlatform.name.toUpperCase()} Client)'
        : '${defaultTargetPlatform.name.toUpperCase()} (Native Engine)';

    final buildMode = kReleaseMode
        ? 'Production (AOT)'
        : kProfileMode
            ? 'Profile'
            : 'Development (Debug JIT)';

    final dbStatus = _latencyMs >= 0
        ? 'Supabase PostgreSQL 15.x (${_latencyMs}ms latency • Online)'
        : 'Supabase PostgreSQL 15.x (Online)';

    final authInfo = _developerEmail.isNotEmpty
        ? 'Supabase GoTrue JWT (Active Session: $_developerEmail)'
        : 'Supabase GoTrue JWT & Role Authorization Guard';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('System Architecture Information', style: DeveloperTheme.headingLarge()),
          const SizedBox(height: 4),
          Text('Runtime environment, versions, and deployment specifications', style: DeveloperTheme.bodySmall()),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: DeveloperTheme.cardDecoration(),
            child: Column(
              children: [
                _buildInfoRow('Application Name', _appName),
                _buildInfoRow('Software Release Version', '$_appVersion ($buildMode)'),
                _buildInfoRow('Framework & SDK', 'Flutter 3.x / Dart 3.x (${kIsWeb ? "Web Engine" : "Native Engine"})'),
                _buildInfoRow('Relational Database', dbStatus),
                _buildInfoRow('Object Storage', storageInfo),
                _buildInfoRow('Authentication Scheme', authInfo),
                _buildInfoRow('Design System', 'Flutter Material 3 (Yang Chow Brand Palette & Dark Slate IT Console)'),
                _buildInfoRow('Host Operating System', clientPlatform),
                _buildInfoRow('Operating System Target', 'Web, Windows, Android, iOS (Cross-Platform)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
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

  /// Portal card for the Portal Access Launchpad.
  /// Unlocked if Maintenance Mode is active OR if an Admin IT Access request is active.
  Widget _buildPortalCard({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    final hasAccess = _isMaintenanceActive || _activeItRequest != null;
    final isLocked = !hasAccess;
    final isElevated = !isLocked && !_isMaintenanceActive && _activeItRequest != null;

    final cardBorderColor = isLocked
        ? DeveloperTheme.borderSubtle
        : (isElevated ? const Color(0xFF10B981).withValues(alpha: 0.4) : color.withValues(alpha: 0.35));

    final badgeColor = isLocked
        ? const Color(0xFFEF4444)
        : (isElevated ? const Color(0xFF10B981) : color);

    final badgeText = isLocked
        ? 'LOCKED'
        : (isElevated ? 'ELEVATED' : 'TEST ACCESS');

    return InkWell(
      onTap: () {
        if (isLocked) {
          _showAccessRequiredDialog(label);
          return;
        }
        Navigator.pushNamed(context, route);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DeveloperTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorderColor),
          boxShadow: isLocked
              ? null
              : [
                  BoxShadow(
                    color: (isElevated ? const Color(0xFF10B981) : color).withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (isLocked ? DeveloperTheme.textMuted : (isElevated ? const Color(0xFF10B981) : color))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isLocked ? Icons.lock_outline_rounded : icon,
                    size: 20,
                    color: isLocked ? DeveloperTheme.textMuted : (isElevated ? const Color(0xFF10B981) : color),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLocked) ...[
                        const Icon(Icons.lock_rounded, size: 9, color: Color(0xFFEF4444)),
                        const SizedBox(width: 3),
                      ] else if (isElevated) ...[
                        const Icon(Icons.verified_user_rounded, size: 9, color: Color(0xFF10B981)),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        badgeText,
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isLocked ? DeveloperTheme.textSecondary : DeveloperTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isLocked
                  ? 'Locked (Admin Request or Maintenance Required)'
                  : (isElevated ? 'Authorized by Admin • Live Session' : subtitle),
              style: DeveloperTheme.bodySmall(
                color: isElevated ? const Color(0xFF34D399) : DeveloperTheme.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  isLocked
                      ? Icons.block_rounded
                      : (isElevated ? Icons.open_in_new_rounded : Icons.arrow_forward_rounded),
                  size: 13,
                  color: isLocked
                      ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                      : (isElevated ? const Color(0xFF34D399) : DeveloperTheme.textMuted),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isLocked ? 'Authorization Required' : route,
                    style: DeveloperTheme.monoText(
                      fontSize: 10,
                      color: isLocked
                          ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                          : (isElevated ? const Color(0xFF34D399) : DeveloperTheme.textMuted),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAccessRequiredDialog(String portalName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DeveloperTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: DeveloperTheme.accentAmber),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DeveloperTheme.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_rounded, color: DeveloperTheme.accentAmber, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Access Authorization Required',
                style: DeveloperTheme.headingMedium(),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hindi mabubuksan ang $portalName dahil kasalukuyang OPERATIONAL (Live) ang sistema.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: DeveloperTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Naka-lock ang direct portal access habang live ang operations upang maprotektahan ang live sales, orders, at customer records.',
              style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DeveloperTheme.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DeveloperTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Para ma-unlock ang portal, kailangan ng isa sa mga ito:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DeveloperTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFF60A5FA)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '1. Mag-request si Admin ng IT Support sa Admin Sidebar at i-accept mo ito rito sa dashboard.',
                          style: GoogleFonts.inter(fontSize: 12, color: DeveloperTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.build_circle_outlined, size: 16, color: DeveloperTheme.accentAmber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '2. I-activate ang Maintenance Mode kung routine technical maintenance ang gagawin.',
                          style: GoogleFonts.inter(fontSize: 12, color: DeveloperTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.inter(color: DeveloperTheme.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: DeveloperTheme.accentAmber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedIndex = 5);
            },
            icon: const Icon(Icons.build_circle_rounded, size: 16),
            label: Text(
              'Go to Maintenance Control',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEndSessionDialog(Map<String, dynamic> request) async {
    final requestId = request['id']?.toString() ?? '';
    final scope = request['access_scope'] ?? 'Full Access';
    final defaultAutoPurge = ItAccessService.shouldAutoPurge(request);
    bool shouldPurgeTestData = defaultAutoPurge;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: DeveloperTheme.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: DeveloperTheme.accentRose),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: DeveloperTheme.accentRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.stop_circle_rounded, color: DeveloperTheme.accentRose, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('End IT Support Session', style: DeveloperTheme.headingMedium()),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to conclude this elevated IT support session ($scope)?',
                    style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // Auto-purge test payments & orders Checkbox
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DeveloperTheme.accentRose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DeveloperTheme.accentRose.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: shouldPurgeTestData,
                          activeColor: DeveloperTheme.accentRose,
                          checkColor: Colors.white,
                          onChanged: (val) {
                            setDialogState(() {
                              shouldPurgeTestData = val ?? false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-purge test payments & orders',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: DeveloperTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Deletes orders, payments & test reservations created during this IT session so admin sales reports stay clean.',
                                style: DeveloperTheme.bodySmall(color: DeveloperTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel', style: GoogleFonts.inter(color: DeveloperTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DeveloperTheme.accentRose,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('End Session Now', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      try {
        int purgedCount = 0;
        if (shouldPurgeTestData) {
          final acceptedAtStr = request['accepted_at']?.toString();
          final startTime = acceptedAtStr != null ? DateTime.tryParse(acceptedAtStr) : null;
          final purgeRes = await _settings.purgeMaintenanceTestData(
            windowStartTime: startTime,
            operatorEmail: _developerEmail,
          );
          purgedCount = (purgeRes['orders'] ?? 0) + (purgeRes['reservations'] ?? 0);
        }

        await ItAccessService.completeSession(
          requestId,
          notes: shouldPurgeTestData
              ? 'Session ended. Auto-purged $purgedCount test records.'
              : 'Session ended without purging test data.',
          adminEmail: request['requested_by_email']?.toString(),
          adminName: request['requested_by_name']?.toString(),
          issueDescription: request['issue_description']?.toString(),
          accessScope: request['access_scope']?.toString(),
          durationHours: request['duration_hours'] as int?,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: DeveloperTheme.accentEmerald,
            behavior: SnackBarBehavior.floating,
            content: Text(
              shouldPurgeTestData
                  ? '✅ IT Support Session completed. Test payments & orders were auto-purged.'
                  : '✅ IT Support Session completed.',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ));
          _loadItAccessRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: DeveloperTheme.accentRose,
            content: Text('Error ending session: $e'),
          ));
        }
      }
    }
  }
}
