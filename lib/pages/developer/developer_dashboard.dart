import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/app_settings_service.dart';
import 'developer_theme.dart';
import 'backup_restore_page.dart';
import 'system_health_page.dart';
import 'audit_logs_page.dart';
import 'security_events_page.dart';
import 'maintenance_mode_page.dart';
import 'user_monitoring_page.dart';
import 'error_log_viewer_page.dart';
import '../../utils/url_helper.dart';

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
  String _developerEmail = 'Developer';

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _developerEmail = Supabase.instance.client.auth.currentUser?.email ?? 'developer@yangchow.com';
    _checkSystemPulse();
    // Periodically update latency and maintenance status
    _latencyTimer = Timer.periodic(const Duration(seconds: 45), (_) => _checkSystemPulse());
  }

  @override
  void dispose() {
    _latencyTimer?.cancel();
    super.dispose();
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
                      child: const Icon(Icons.terminal_rounded, size: 14, color: DeveloperTheme.accentIndigo),
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
                    Icons.terminal_rounded,
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
                _buildNavItem(0, 'System Overview', Icons.dashboard_outlined),
                _buildNavItem(1, 'System Health & Status', Icons.health_and_safety_outlined),
                _buildNavItem(2, 'Audit Logs', Icons.receipt_long_outlined),
                _buildNavItem(3, 'Security Events', Icons.shield_outlined),
                _buildNavItem(4, 'User & Role Monitoring', Icons.manage_accounts_outlined),
                _buildNavItem(5, 'Maintenance Mode', Icons.build_circle_outlined),
                _buildNavItem(6, 'Backup Status', Icons.backup_outlined),
                _buildNavItem(7, 'System Information', Icons.info_outline_rounded),
                _buildNavItem(8, 'Error Log Viewer', Icons.bug_report_outlined),
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
                      'Role: developer\nEngine: v1.0.0+20',
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
                    icon: Icons.power_rounded,
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
                    icon: Icons.shield_rounded,
                    onTap: () => setState(() => _selectedIndex = 3),
                  ),
                  _buildQuickCard(
                    title: 'Role Access',
                    value: 'ISOLATED',
                    subtitle: 'Admin / IT Separated',
                    color: DeveloperTheme.accentPurple,
                    icon: Icons.fingerprint_rounded,
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
                  icon: Icons.build_circle_outlined,
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
                  icon: Icons.backup_outlined,
                  color: DeveloperTheme.accentIndigo,
                  onTap: () => setState(() => _selectedIndex = 6),
                ),
              ),
            ],
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
                _buildInfoRow('Application Name', 'Yang Chow Palace Restaurant Management System (YCPRMS)'),
                _buildInfoRow('Software Release Version', '1.0.0+20 (Production)'),
                _buildInfoRow('Framework & SDK', 'Flutter 3.x / Dart 3.x'),
                _buildInfoRow('Relational Database', 'Supabase PostgreSQL 15.x with Row Level Security (RLS)'),
                _buildInfoRow('Object Storage', 'Firebase Storage Bucket (Polyglot image storage)'),
                _buildInfoRow('Authentication Scheme', 'Supabase GoTrue JWT & Role Authorization Guard'),
                _buildInfoRow('Design System', 'Tailored Cyber/Dark Slate IT Architecture Theme'),
                _buildInfoRow('Operating System Target', 'Web, Windows, Android, iOS'),
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
}
